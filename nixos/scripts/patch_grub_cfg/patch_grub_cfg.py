#!/usr/bin/env python3
"""Patch grub.cfg AST nodes to redirect grubenv access to EFI.

Rewrites `load_env`, `save_env`, and grubenv guard checks without touching
strings, comments, or unrelated commands. Appends `set patched_loaded=1`
after a successful patch.
"""
import argparse
import ctypes
import os
import sys
import tree_sitter

SENTINEL = "set patched_loaded=1"

def load_language(grammar_lib_path):
    lib = ctypes.cdll.LoadLibrary(grammar_lib_path)
    lib.tree_sitter_grub.restype = ctypes.c_void_p
    return tree_sitter.Language(lib.tree_sitter_grub())


def make_parser(language):
    return tree_sitter.Parser(language)


class Edit:
    __slots__ = ("start", "end", "replacement", "kind")

    def __init__(self, start, end, replacement, kind):
        self.start = start
        self.end = end
        self.replacement = replacement
        self.kind = kind

    def __repr__(self):
        return "Edit({}, {}, {!r}, {!r})".format(
            self.start, self.end, self.replacement, self.kind
        )


def _named_children(node):
    return [c for c in node.children if c.is_named]


def _has_file_flag(children):
    return any(c.text in (b"--file", b"-f") for c in children)


def _find_guard_target(children):
    for i, child in enumerate(children):
        if child.text != b"-s":
            continue
        if i + 1 >= len(children):
            continue
        nxt = children[i + 1]

        if (
            nxt.type == "variable_expansion"
            and nxt.text == b"$prefix"
            and i + 2 < len(children)
            and children[i + 2].text == b"/grubenv"
        ):
            return (nxt.start_byte, children[i + 2].end_byte)

        if nxt.type == "variable_expansion" and nxt.text == b"$envfile":
            return (nxt.start_byte, nxt.end_byte)

        if nxt.type == "double_quoted_string" and (
            nxt.text == b'"$prefix/grubenv"' or nxt.text == b'"$envfile"'
        ):
            return (nxt.start_byte, nxt.end_byte)

    return None


def collect_edits(root, efi_env_path):
    edits = []

    def walk(node):
        if node.type == "simple_command":
            name_node = node.child_by_field_name("name")
            if name_node is None:
                for child in node.children:
                    walk(child)
                return

            cmd_name = name_node.text

            if cmd_name == b"load_env":
                children = _named_children(node)
                args = [c for c in children if c.id != name_node.id]
                if not _has_file_flag(args):
                    insert_text = " --file {}".format(efi_env_path)
                    edits.append(Edit(
                        name_node.end_byte, name_node.end_byte,
                        insert_text, "load_env",
                    ))
                return

            if cmd_name == b"save_env":
                children = _named_children(node)
                args = [c for c in children if c.id != name_node.id]
                if not _has_file_flag(args):
                    insert_text = " --file {}".format(efi_env_path)
                    edits.append(Edit(
                        name_node.end_byte, name_node.end_byte,
                        insert_text, "save_env",
                    ))
                return

            if cmd_name == b"[":
                children = _named_children(node)
                target = _find_guard_target(children)
                if target is not None:
                    start, end = target
                    edits.append(Edit(start, end, efi_env_path, "guard"))
                return

        for child in node.children:
            walk(child)

    walk(root)
    edits.sort(key=lambda e: e.start)
    return edits


def apply_edits(source, edits):
    for i in range(len(edits) - 1):
        if edits[i].end > edits[i + 1].start:
            raise ValueError(
                "Overlapping edits: {} and {}".format(edits[i], edits[i + 1])
            )

    result = bytearray()
    pos = 0
    for edit in edits:
        result.extend(source[pos:edit.start])
        result.extend(edit.replacement.encode("utf-8"))
        pos = edit.end
    result.extend(source[pos:])
    return bytes(result)


def append_sentinel(source):
    if source and source[-1:] != b"\n":
        source += b"\n"
    source += SENTINEL.encode("utf-8") + b"\n"
    return source


def summarize_edits(edits):
    counts = {}
    for e in edits:
        counts[e.kind] = counts.get(e.kind, 0) + 1
    parts = []
    for kind in ("guard", "load_env", "save_env"):
        if kind in counts:
            parts.append("{}: {}".format(kind, counts[kind]))
    return ", ".join(parts) if parts else "no edits"


def patch(source_bytes, efi_env_path, language):
    parser = make_parser(language)
    tree = parser.parse(source_bytes)
    root = tree.root_node

    if root.has_error:
        def find_error(node):
            if node.type == "ERROR" or node.is_missing:
                return node
            for child in node.children:
                err = find_error(child)
                if err is not None:
                    return err
            return None

        err_node = find_error(root)
        err_loc = ""
        if err_node:
            err_loc = " at line {}".format(err_node.start_point[0] + 1)
        raise RuntimeError("Parse error in input grub.cfg{}".format(err_loc))

    edits = collect_edits(root, efi_env_path)

    if not edits:
        if SENTINEL.encode("utf-8") in source_bytes:
            return source_bytes, edits
        raise RuntimeError(
            "No rewrite targets found in grub.cfg. "
            "Expected load_env, save_env, or grubenv guard conditions."
        )

    patched = apply_edits(source_bytes, edits)
    patched = append_sentinel(patched)
    return patched, edits


def main():
    parser = argparse.ArgumentParser(
        description="AST-based grub.cfg patcher for EFI grubenv redirection."
    )
    parser.add_argument("input", help="Input grub.cfg file path")
    parser.add_argument("output", help="Output patched grub.cfg file path")
    parser.add_argument(
        "--efi-env-path",
        required=True,
        help="GRUB-visible path to grubenv on EFI partition",
    )
    parser.add_argument(
        "--grammar-lib",
        required=True,
        help="Path to compiled tree-sitter-grub shared library",
    )
    args = parser.parse_args()

    grammar_path = os.path.abspath(args.grammar_lib)
    if not os.path.exists(grammar_path):
        print(
            "error: grammar library not found: {}".format(grammar_path),
            file=sys.stderr,
        )
        sys.exit(2)
    language = load_language(grammar_path)

    try:
        with open(args.input, "rb") as f:
            source = f.read()
    except OSError as e:
        print("error: cannot read input: {}".format(e), file=sys.stderr)
        sys.exit(1)

    try:
        patched, edits = patch(source, args.efi_env_path, language)
    except RuntimeError as e:
        print("error: {}".format(e), file=sys.stderr)
        sys.exit(1)

    try:
        with open(args.output, "wb") as f:
            f.write(patched)
    except OSError as e:
        print("error: cannot write output: {}".format(e), file=sys.stderr)
        sys.exit(1)

    print("Patched: {}".format(summarize_edits(edits)), file=sys.stderr)
    sys.exit(0)


if __name__ == "__main__":
    main()
