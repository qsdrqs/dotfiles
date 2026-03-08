# AGENTS.md - Dotfiles Repository

## Scope

Applies to the repo root and all subdirectories.

### NixOS

**AI agents**: Load the `nixos-config` skill before making any NixOS/Home Manager changes. It contains build commands, flake composition map, option verification workflow, and repo-specific conventions.

```bash
# Build a NixOS configuration (dry-run)
nix build path:.#nixosConfigurations.<name>.config.system.build.toplevel --dry-run
# Available names: minimal, basic, develop, server, rpi, desktop, laptop, wsl-desktop, wsl-laptop, gui-minimal, gui-basic

# Build and switch (on a live NixOS system)
# CRITICAL: always use path: prefix - repo has gitignored files required for build
nixos-rebuild switch --sudo --ask-sudo-password --flake path:.#<name>
# Or use the shell alias: snr-switch <name>

# Build Home Manager standalone (non-NixOS)
nix build path:.#homeConfigurations.<name>.activationPackage
# Available names: minimal, basic, rpi, wsl, standalone, termux

# Evaluate a single NixOS module for syntax errors
nix eval path:.#nixosConfigurations.<name>.config.system.build.toplevel --no-build

# Update all flake inputs
./update_nix.sh
# Update a single sub-flake
cd nvim && nix flake update
```

### Neovim

**AI agents**: Load the `nvim-config` skill before making any Neovim configuration changes. It covers plugin specs, keymaps, LSP/formatters, UI, performance, and debugging workflows.

```bash
# Sync plugins headless (validates plugin specs parse correctly)
NVIM_APPNAME=dotfiles-dev nvim --headless "+Lazy! sync" +qa

# Dump plugin list (validates the full init pipeline)
nvim --headless --cmd "let g:plugins_loaded=1" -c 'lua DumpPluginsList(); vim.cmd("q")'
```

### Lua Formatting

```bash
# Check format (requires stylua)
stylua --check nvim/ yazi/ .nvimrc.lua
# Auto-format
stylua nvim/ yazi/ .nvimrc.lua
```

### Nix Formatting / Linting

```bash
# Format (requires nixfmt or nixpkgs-fmt)
nixfmt nixos/*.nix
# Lint (requires statix)
statix check nixos/
```

## Code Style

### Lua (Neovim and Yazi)

- **Formatter**: StyLua per `.stylua.toml` - 2-space indent, 120 column width.
- **Diagnostics**: `.luarc.json` disables `missing-fields`.
- **Module pattern**: Every module returns a table `M`. Public functions are `M.func_name()`.
- **Naming**: `snake_case` for functions, variables, and file names. No CamelCase except globals exported for external compatibility (`LazyLoadPlugins`, `VscodeNeovimHandler`, `DumpPluginsList`).
- **Annotations**: Use `--@param`, `--@return` LDoc-style annotations on public functions.
- **Idempotency**: Top-level `require()` must be side-effect-free. Guard repeated initialization with a flag (`local initialized = false`).
- **Error handling**: Never silently swallow errors. Use `pcall` where failure is expected and log/surface the error message.

### Nix

- **Style**: 2-space indent. Use `let ... in` for local bindings. Attribute sets use `{ key = value; }` with spaces inside braces.
- **Module signature**: NixOS modules start with `{ config, pkgs, lib, inputs, ... }:`.
- **Naming**: `kebab-case` for file names (`desktop-configuration.nix`). `camelCase` for Nix variables and function names (`minimalConfig`, `genZshPlugins`).
- **Imports**: Reference sibling modules via relative path (`./module.nix`), parent repo files via `../${name}`.
- **Derivations**: Reuse `commonInstallPhase` and `trivialDerivation` patterns from `nixos/nvim-plugins.nix`.

### Shell (Bash)

- **Shebang**: `#!/usr/bin/env bash`. Always `set -e`.
- **Indent**: 4 spaces.
- **Quoting**: Always quote `$VAR` expansions. Use `${PWD}` in scripts.

### Python

- **Indent**: 4 spaces (per `.editorconfig`).
- **Encoding**: UTF-8, no BOM.
- **Docstrings**: Module-level docstring explaining usage and behavior (see `codex_notifier.py`).

### General

- **EditorConfig**: `.editorconfig` enforces `trim_trailing_whitespace = true` globally.
- **Comments**: ASCII-only English. No em-dashes or non-ASCII punctuation.
- **File encoding**: UTF-8 everywhere.

## Repository Architecture

### First-Class Components (modify with care)

| Component | Entry Point | Config Location |
|-----------|------------|-----------------|
| NixOS | `flake.nix` | `nixos/` |
| Neovim | `.nvimrc.lua` | `nvim/lua/dotfiles/` |
| Yazi | `yazi/init.lua` | `yazi/` |
| Tmux | `.tmux.conf` | `.tmux.conf.local` |

### NixOS (`nixos/`)

- **Layered configs**: `minimal` < `basic` < `develop` < `desktop`/`laptop`. Each layer adds modules to its parent.
- **Home Manager**: Integrated via `home-manager.nixosModules.home-manager`. User is `qsdrqs`.
- **Dotfile linking**: `nixos/dotfiles.nix` uses `home.file`, `symbfileTarget`, and `symbfileTargetNoRecursive` to symlink repo files into `$HOME` and `~/.config/`.
- **Plugin injection**: `nixos/nvim-plugins.nix` builds Neovim plugins as Nix derivations; `nixos/dotfiles.nix` injects Zsh/Tmux/Yazi plugins via Nix.
- **Host customization**: `nixos/custom/` (gitignored) holds per-machine overrides. Template: `nixos/home-custom.template.nix`.
- **Private data**: `nixos/private/` (gitignored) holds secrets. Never commit secrets.
- **Update script**: `install.sh` is a script that can be used to update `flake.lock` files after modifying `flake.nix` or sub-flakes. Run it accordingly after making changes to Nix files.

### Neovim (`nvim/lua/dotfiles/`)

- **Module hierarchy**: `core/` (infrastructure) -> `plugins/` (specs) -> `commands/` (globals) -> `env/` (adapters).
- **Plugin system**: `plugins/spec.lua` aggregates category modules (lsp, ui, git, etc.). Each category module exposes `setup(context)` returning a list of lazy.nvim specs.
- **Adding a plugin**: Create a file under the appropriate `plugins/<category>/` subdirectory returning a lazy.nvim spec table, then `require` it in `plugins/<category>/init.lua`.
- **Shared context**: `core/helpers.lua` (load utilities), `core/icons.lua` (icon sets), `core/highlights.lua` (semantic highlight groups), `core/state.lua` (global variable defaults).
- **Exported globals**: `LazyLoadPlugins`, `VscodeNeovimHandler`, `DumpPluginsList` - these are referenced by `nixos/isohome.nix` and must remain stable.

### Yazi (`yazi/`)

- **Config files**: `yazi.toml`, `keymap.toml`, `theme.toml`, `init.lua`.
- **Custom plugins** (in-repo): Each in `plugins/<name>.yazi/main.lua`. Uses `--- @sync entry` annotation for sync plugins.
- **Nix-injected plugins**: `toggle-pane.yazi`, `mime-ext.yazi`, `searchjump.yazi`, `starship.yazi` - linked by Nix into `~/.config/yazi/plugins/`.

### Tmux (`.tmux.conf`, `.tmux.conf.local`)

- **Plugins**: `tmux-resurrect` and `tmux-continuum` injected by Nix to `~/.tmux/plugins/`.
- **Reload**: `tmux source-file ~/.tmux.conf`.

### Other Directories

- `alacritty/`, `kitty/` - terminal emulator configs
- `hypr/`, `i3/`, `niri/` - window manager configs
- `polybar/`, `waybar/`, `rofi/`, `swaync/` - status bar / launcher configs
- `zsh/`, `starship/`, `direnv/` - shell environment
- `ranger/` - legacy file manager (Yazi preferred)
- `.vim/`, `after/` - Vim compatibility layer (shared with Neovim via symlink)
- `tools/` - utility scripts

## Key Conventions

1. **Discuss before modifying**: Directory structure, entry scripts, Nix/Home Manager behavior, or cross-platform differences require discussion first.
2. **Idempotent scripts**: All install/link/switch scripts must be safely re-runnable.
3. **Surface errors**: Scripts must not silently fail or degrade. Print concise error messages.
4. **Follow existing patterns**: New files and directories must follow the naming and layering of their siblings. Avoid cross-layer coupling.
5. **Document changes**: Update this file or relevant READMEs when making structural changes.
6. **Editing over rewriting**: When modifying docs, edit the targeted content only. Never delete-and-rewrite an entire file unless strictly necessary.
7. **Web search for uncertainty**: When discussing approaches, search the web for unfamiliar Nix options, APIs, or library behaviors to verify feasibility.

## Current Tasks

- (none)
