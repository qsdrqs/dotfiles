#!/usr/bin/env python3
"""Validate one patched grub.cfg against one original grub.cfg.

Uses two independent checks: `grub-script-check` for syntax and an AST
lockstep comparison that only permits the expected grubenv rewrites plus the
final sentinel line.
"""
import argparse
import ctypes
import os
import shutil
import subprocess
import sys
import tree_sitter

_COMPOUND_TYPES = frozenset({
    "source_file", "if_command", "elif_clause",
    "for_command", "while_command", "until_command",
    "function_definition", "block",
})

SENTINEL_TEXT = b"set patched_loaded=1"


def find_grub_script_check():
    for name in ("grub-script-check", "grub2-script-check"):
        path = shutil.which(name)
        if path:
            return path
    return None


def load_language(grammar_lib_path):
    lib = ctypes.cdll.LoadLibrary(grammar_lib_path)
    lib.tree_sitter_grub.restype = ctypes.c_void_p
    return tree_sitter.Language(lib.tree_sitter_grub())


def make_parser(language):
    return tree_sitter.Parser(language)


def run_grub_script_check(file_path):
    checker = find_grub_script_check()
    if checker is None:
        return ["grub-script-check/grub2-script-check not found in PATH"]

    try:
        result = subprocess.run(
            [checker, file_path],
            capture_output=True, text=True, timeout=10,
        )
        if result.returncode != 0:
            msg = result.stderr.strip() if result.stderr else "exit code {}".format(
                result.returncode
            )
            return ["grub-script-check failed on {}: {}".format(file_path, msg)]
    except subprocess.TimeoutExpired:
        return ["grub-script-check timed out on {}".format(file_path)]
    return []


def is_allowed_rewrite(orig_text, patched_text, efi_env_path):
    orig = orig_text.decode("utf-8")
    patched = patched_text.decode("utf-8")

    if orig == "load_env" and patched == "load_env --file " + efi_env_path:
        return True

    if orig.startswith("save_env "):
        orig_args = orig[len("save_env "):]
        expected = "save_env --file {} {}".format(efi_env_path, orig_args)
        if patched == expected:
            return True

    if orig.startswith("["):
        for old_path in ("$prefix/grubenv", "$envfile",
                         '"$prefix/grubenv"', '"$envfile"'):
            if old_path in orig:
                expected = orig.replace(old_path, efi_env_path)
                if patched == expected:
                    return True

    return False


def _check_sentinel(extra_nodes):
    errors = []
    sentinel_found = False
    for node in extra_nodes:
        if node.type == "simple_command" and node.text.strip() == SENTINEL_TEXT:
            sentinel_found = True
        elif node.type == "comment":
            pass
        else:
            errors.append(
                "Unexpected extra node in patched file: {} ({!r})".format(
                    node.type, node.text.decode("utf-8", errors="replace")[:80],
                )
            )
    if not sentinel_found:
        errors.append(
            "Sentinel '{}' not found at end of patched file".format(
                SENTINEL_TEXT.decode()
            )
        )
    return errors


def _loc(node):
    return "line {}".format(node.start_point[0] + 1)


def lockstep_compare(orig_node, patched_node, efi_env_path):
    errors = []

    if orig_node.type != patched_node.type:
        errors.append(
            "Node type mismatch at {}: original={}, patched={}".format(
                _loc(orig_node), orig_node.type, patched_node.type,
            )
        )
        return errors

    node_type = orig_node.type

    if node_type == "simple_command":
        orig_block = orig_node.child_by_field_name("body")
        patched_block = patched_node.child_by_field_name("body")

        if orig_block is not None and patched_block is not None:
            orig_header = orig_node.text[:orig_block.start_byte - orig_node.start_byte]
            patched_header = patched_node.text[:patched_block.start_byte - patched_node.start_byte]
            if orig_header != patched_header:
                errors.append(
                    "Block command header changed at {}: {!r} -> {!r}".format(
                        _loc(orig_node),
                        orig_header.decode("utf-8", errors="replace")[:60],
                        patched_header.decode("utf-8", errors="replace")[:60],
                    )
                )
            errors.extend(lockstep_compare(orig_block, patched_block, efi_env_path))

        elif orig_block is None and patched_block is None:
            if orig_node.text != patched_node.text:
                if not is_allowed_rewrite(
                    orig_node.text, patched_node.text, efi_env_path,
                ):
                    errors.append(
                        "Unauthorized modification at {}: {!r} -> {!r}".format(
                            _loc(orig_node),
                            orig_node.text.decode("utf-8", errors="replace")[:60],
                            patched_node.text.decode("utf-8", errors="replace")[:60],
                        )
                    )
        else:
            errors.append(
                "Block presence mismatch at {}: original={}, patched={}".format(
                    _loc(orig_node),
                    "has block" if orig_block else "no block",
                    "has block" if patched_block else "no block",
                )
            )
        return errors

    if node_type in _COMPOUND_TYPES:
        orig_named = [c for c in orig_node.children if c.is_named]
        patched_named = [c for c in patched_node.children if c.is_named]

        # At root level, patched may have extra sentinel node(s)
        if node_type == "source_file":
            if len(patched_named) >= len(orig_named):
                extra = patched_named[len(orig_named):]
                patched_named = patched_named[:len(orig_named)]
                errors.extend(_check_sentinel(extra))
        if len(orig_named) != len(patched_named):
            errors.append(
                "Named child count mismatch in {} at {}: "
                "original={}, patched={}".format(
                    node_type, _loc(orig_node),
                    len(orig_named), len(patched_named),
                )
            )
            return errors

        for orig_child, patched_child in zip(orig_named, patched_named):
            errors.extend(
                lockstep_compare(orig_child, patched_child, efi_env_path)
            )
        return errors

    if orig_node.text != patched_node.text:
        errors.append(
            "Leaf node changed at {}: {} {!r} -> {!r}".format(
                _loc(orig_node), node_type,
                orig_node.text.decode("utf-8", errors="replace")[:60],
                patched_node.text.decode("utf-8", errors="replace")[:60],
            )
        )

    return errors


def validate(original_path, patched_path, efi_env_path, language):
    errors = []

    errors.extend(run_grub_script_check(original_path))
    errors.extend(run_grub_script_check(patched_path))

    if errors:
        return errors

    with open(original_path, "rb") as f:
        original_bytes = f.read()
    with open(patched_path, "rb") as f:
        patched_bytes = f.read()

    parser = make_parser(language)
    orig_tree = parser.parse(original_bytes)
    patched_tree = parser.parse(patched_bytes)

    if orig_tree.root_node.has_error:
        errors.append("tree-sitter parse error in original file")
    if patched_tree.root_node.has_error:
        errors.append("tree-sitter parse error in patched file")

    if errors:
        return errors

    errors.extend(
        lockstep_compare(
            orig_tree.root_node, patched_tree.root_node, efi_env_path,
        )
    )

    return errors


def main():
    ap = argparse.ArgumentParser(
        description="Translation validation for grub.cfg patching."
    )
    ap.add_argument("original", help="Original (unpatched) grub.cfg")
    ap.add_argument("patched", help="Patched grub.cfg to validate")
    ap.add_argument(
        "--efi-env-path",
        required=True,
        help="Expected GRUB-visible grubenv path",
    )
    ap.add_argument(
        "--grammar-lib",
        required=True,
        help="Path to compiled tree-sitter-grub shared library",
    )
    args = ap.parse_args()

    grammar_path = os.path.abspath(args.grammar_lib)
    if not os.path.exists(grammar_path):
        print(
            "error: grammar library not found: {}".format(grammar_path),
            file=sys.stderr,
        )
        sys.exit(2)
    language = load_language(grammar_path)

    errors = validate(args.original, args.patched, args.efi_env_path, language)

    if errors:
        print(
            "VALIDATION FAILED ({} errors):".format(len(errors)),
            file=sys.stderr,
        )
        for i, err in enumerate(errors, 1):
            print("  {}: {}".format(i, err), file=sys.stderr)
        sys.exit(1)
    else:
        print("Validation passed.", file=sys.stderr)
        sys.exit(0)


if __name__ == "__main__":
    main()
