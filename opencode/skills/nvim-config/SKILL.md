---
name: nvim-config
description: "Neovim configuration changes and investigations for this dotfiles repo. Use for any Neovim-related task: editing config, plugin specs, keymaps, LSP/formatters, UI, performance, debugging, or plugin behavior questions."
---

# Nvim Config

## Overview

Follow a code-first workflow for all Neovim tasks in this repo. Treat Neovim Lua as Lua + Neovim API extensions, and assume the plugin ecosystem changes quickly. Read local configuration and plugin source code first, then use web search to confirm latest APIs and patterns before changing config.

## Core Principles

- Read local code before proposing changes; prefer behavior that is already encoded in the repo.
- Treat Neovim Lua as an extended runtime; use Neovim-provided APIs when standard Lua lacks functionality.
- If behavior is unclear, inspect plugin source under `~/.local/share/nvim/nix`, inspect neovim runtime under `/run/current-system/sw/share/nvim/runtime`, or add debug prints to Neovim.
- Use web search to confirm current plugin docs and Neovim API changes; do not rely on stale knowledge.
- Keep changes minimal and aligned with existing structure.

## Workflow

Use the detailed workflow in `references/workflow.md` for entry points, code-reading order, and validation steps.

## Resources

- `references/workflow.md`: Repo-specific workflow (read code -> web search -> modify config).
- `scripts/`: Reserved for future headless-debug helpers.
