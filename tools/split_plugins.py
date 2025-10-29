#!/usr/bin/env python3

"""
Split dotfiles plugin category modules so every plugin spec lives in its own file.

Usage:
  python tools/split_plugins.py nvim/lua/dotfiles/plugins/navigation nvim/lua/dotfiles/plugins/git

By default the script refuses to overwrite existing per-plugin files. Pass --overwrite to refresh them.
"""

from __future__ import annotations

import argparse
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, List, Sequence


CONTEXT_LOCALS: Sequence[str] = (
    "load_plugin",
    "load_plugins",
    "lsp_merge_project_config",
    "kind_icons_list",
    "kind_icons",
    "highlight_group_list",
    "icons",
    "highlights",
    "vscode_next_hunk",
    "vscode_prev_hunk",
)


@dataclass(slots=True)
class Slice:
    start: int
    end: int

    def text(self, source: str) -> str:
        return source[self.start : self.end]


def locate_specs_block(source: str) -> int:
    match = re.search(r"\blocal\s+specs\s*=\s*{", source)
    if not match:
        raise ValueError("Could not find 'local specs = {' declaration.")
    open_brace = source.find("{", match.start())
    if open_brace == -1:
        raise ValueError("Malformed specs declaration.")
    return open_brace


def match_long_bracket(source: str, pos: int) -> tuple[int, int] | None:
    if pos >= len(source) or source[pos] != "[":
        return None
    idx = pos + 1
    depth = 0
    while idx < len(source) and source[idx] == "=":
        depth += 1
        idx += 1
    if idx < len(source) and source[idx] == "[":
        return depth, idx + 1
    return None


def match_long_closer(source: str, pos: int, depth: int) -> int | None:
    if source[pos] != "]":
        return None
    idx = pos + 1
    count = 0
    while idx < len(source) and source[idx] == "=":
        count += 1
        idx += 1
    if count == depth and idx < len(source) and source[idx] == "]":
        return idx + 1
    return None


def backtrack_chunk_start(source: str, pos: int) -> int:
    start = pos
    # include the current line
    line_break = source.rfind("\n", 0, start)
    start = 0 if line_break == -1 else line_break + 1

    probe = start
    while probe > 0:
        prev_break = source.rfind("\n", 0, probe - 1)
        line_start = 0 if prev_break == -1 else prev_break + 1
        line = source[line_start:probe].strip()
        if line == "" or line.startswith("--"):
            probe = line_start
            start = line_start
            continue
        break
    return start


def advance_past_trailing_whitespace(source: str, pos: int) -> int:
    length = len(source)
    idx = pos
    while idx < length and source[idx] in " \t":
        idx += 1
    if idx < length and source[idx] == ",":
        idx += 1
        while idx < length and source[idx] in " \t":
            idx += 1
    if idx < length and source[idx] == "\n":
        idx += 1
    return idx


def extract_spec_slices(source: str) -> List[Slice]:
    open_brace = locate_specs_block(source)
    idx = open_brace + 1
    depth = 1

    state = "normal"
    string_delim: str | None = None
    long_bracket_depth: int | None = None
    long_comment_depth: int | None = None
    entry_start: int | None = None
    slices: List[Slice] = []

    while idx < len(source):
        ch = source[idx]

        if state == "line_comment":
            if ch == "\n":
                state = "normal"
            idx += 1
            continue

        if long_comment_depth is not None:
            if ch == "]":
                closing = match_long_closer(source, idx, long_comment_depth)
                if closing is not None:
                    idx = closing
                    long_comment_depth = None
                    continue
            idx += 1
            continue

        if long_bracket_depth is not None:
            if ch == "]":
                closing = match_long_closer(source, idx, long_bracket_depth)
                if closing is not None:
                    idx = closing
                    long_bracket_depth = None
                    continue
            idx += 1
            continue

        if state == "string":
            if ch == "\\":
                idx += 2
                continue
            if ch == string_delim:
                state = "normal"
            idx += 1
            continue

        # normal state
        if ch == "-" and source.startswith("--", idx):
            lb = match_long_bracket(source, idx + 2)
            if lb:
                long_comment_depth = lb[0]
                idx = lb[1]
            else:
                state = "line_comment"
                idx += 2
            continue

        if ch in ('"', "'"):
            state = "string"
            string_delim = ch
            idx += 1
            continue

        if ch == "[":
            lb = match_long_bracket(source, idx)
            if lb:
                long_bracket_depth = lb[0]
                idx = lb[1]
                continue

        if ch == "{":
            depth += 1
            if depth == 2:
                entry_start = backtrack_chunk_start(source, idx)
            idx += 1
            continue

        if ch == "}":
            if depth == 2 and entry_start is not None:
                end_idx = advance_past_trailing_whitespace(source, idx + 1)
                slices.append(Slice(entry_start, end_idx))
                entry_start = None
            depth -= 1
            idx += 1
            if depth == 0:
                break
            continue

        idx += 1

    return slices


def sanitize_plugin_name(plugin_id: str) -> str:
    repo = plugin_id.split("/")[-1]
    repo = re.sub(r"\.git$", "", repo, flags=re.IGNORECASE)
    lowered = repo.lower()
    for suffix in (".nvim", ".vim", ".lua"):
        if lowered.endswith(suffix):
            repo = repo[: -len(suffix)]
            lowered = repo.lower()
            break
    repo = repo.replace("-", "_").replace(".", "_").replace(" ", "_")
    repo = re.sub(r"(.)([A-Z][a-z]+)", r"\1_\2", repo)
    repo = re.sub(r"([a-z0-9])([A-Z])", r"\1_\2", repo)
    repo = re.sub(r"_+", "_", repo).strip("_")
    repo = repo.lower()
    if not repo:
        repo = "plugin"
    return repo


def determine_plugin_id(chunk: str) -> str:
    match = re.search(r'["\']([^"\']+)["\']', chunk)
    if match:
        return match.group(1)
    named = re.search(r"name%s*=%s*['\"]([^'\"]+)['\"]" % (r"\s*", r"\s*"), chunk)
    if named:
        return named.group(1)
    raise ValueError("Unable to determine plugin identifier from chunk.")


def create_module_text(plugin_id: str, chunk: str) -> str:
    lines: List[str] = [f"-- Plugin: {plugin_id}", "return function(ctx)"]
    for local_name in CONTEXT_LOCALS:
        lines.append(f"  local {local_name} = ctx.{local_name}")
    lines.append("")
    lines.append("  return {")
    chunk_lines = chunk.rstrip("\n").splitlines()
    lines.extend(chunk_lines)
    if chunk_lines and chunk_lines[-1].strip() != "":
        lines.append("")
    lines.append("  }")
    lines.append("end")
    lines.append("")
    return "\n".join(lines)


def rewrite_category_init(category_dir: Path, module_names: Sequence[str]) -> None:
    module_lines = [f'  require("dotfiles.plugins.{category_dir.name}.{name}"),' for name in module_names]
    content = [
        "local M = {}",
        "",
        "local modules = {",
        *module_lines,
        "}",
        "",
        "function M.setup(ctx)",
        "  local specs = {}",
        "  for _, mod in ipairs(modules) do",
        "    local entries = mod(ctx)",
        "    if entries ~= nil then",
        "      for _, spec in ipairs(entries) do",
        "        table.insert(specs, spec)",
        "      end",
        "    end",
        "  end",
        "  return specs",
        "end",
        "",
        "return M",
        "",
    ]
    (category_dir / "init.lua").write_text("\n".join(content))


def process_category(category_dir: Path, overwrite: bool) -> None:
    init_path = category_dir / "init.lua"
    if not init_path.exists():
        raise FileNotFoundError(f"Missing init.lua in {category_dir}")

    source = init_path.read_text()
    slices = extract_spec_slices(source)
    if not slices:
        raise RuntimeError(f"No plugin specs found in {init_path}")

    module_names: List[str] = []
    taken = set()

    for slc in slices:
        chunk = slc.text(source)
        plugin_id = determine_plugin_id(chunk)
        base = sanitize_plugin_name(plugin_id)
        name = base
        counter = 2
        while name in taken or ((category_dir / f"{name}.lua").exists() and not overwrite):
            name = f"{base}_{counter}"
            counter += 1
        taken.add(name)
        module_names.append(name)

        (category_dir / f"{name}.lua").write_text(create_module_text(plugin_id, chunk))

    rewrite_category_init(category_dir, module_names)


def main() -> None:
    parser = argparse.ArgumentParser(description="Split dotfiles plugin category modules into per-plugin files.")
    parser.add_argument("categories", nargs="+", help="Category directories to split.")
    parser.add_argument("--overwrite", action="store_true", help="Overwrite existing plugin modules.")
    args = parser.parse_args()

    for category in args.categories:
        process_category(Path(category), overwrite=args.overwrite)


if __name__ == "__main__":
    main()
