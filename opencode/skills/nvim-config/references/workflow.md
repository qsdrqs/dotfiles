# Neovim Config Workflow (Read -> Search -> Modify)

## 1) Map entry points in this repo

- `.nvimrc.lua`: primary entry point; orchestrates setup and lazy-loading.
- `nvim/lua/dotfiles/init.lua`: bootstrap and shared helpers (state, runtime, highlights, autocmds).
- `nvim/lua/dotfiles/core/`: core runtime, autocmds, state, highlights, helpers.
- `nvim/lua/dotfiles/plugins/`: plugin grouping and specs; `spec.lua` aggregates.
- `nvim/lua/dotfiles/commands/`: user commands and globals.
- `nvim/lua/dotfiles/env/`: environment-specific adapters (e.g., VSCode).
- `nvim/lua/dotfiles/none-ls/`, `nvim/lua/dotfiles/luasnip/`: formatter/linter and snippets.
- `nvim/flake.nix`, `nvim/flake_out.nix`: Nix-based packaging for Neovim when relevant.

## 2) Read local code first

- Start from `.nvimrc.lua`, follow the `require(...)` chain into the exact module that owns the behavior.
- Use `rg` to locate functions, config tables, and plugin specs before changing anything.
- Keep top-level `require` side effects minimal; preserve the existing orchestrator style.

## 3) Inspect plugin source when unclear

- For plugin behavior questions, read source under `~/.local/share/nvim/nix`.
- Prefer source inspection over assumptions; verify default options, commands, and keymaps.

## 4) Use web search to confirm latest APIs

- Search for current Neovim API changes and plugin documentation before implementing new patterns.
- Cross-check changes against local config and plugin source to avoid regressions.

## 5) Implement minimal, aligned changes

- Modify only the relevant module; avoid cross-layer coupling.
- Keep naming, structure, and load order consistent with existing code.

## 6) Validate changes (when applicable)

- Sync plugins headlessly if needed:
  - `NVIM_APPNAME=dotfiles-dev nvim --headless "+Lazy! sync" +qa`
- Export plugin list if requested:
  - `nvim --headless --cmd "let g:plugins_loaded=1" -c 'lua DumpPluginsList(); q'`
- Verify that Neovim starts cleanly and target behavior changes as intended.
