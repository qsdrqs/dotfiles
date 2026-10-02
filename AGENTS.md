# AGENTS.md - Dotfiles Repository

## Scope

Applies to the repo root and all subdirectories.

### NixOS

**AI agents**: Load the `nixos-config` skill before making any NixOS/Home Manager changes. It contains build commands, flake composition map, option verification workflow, and repo-specific conventions.

```bash
# Build a NixOS configuration (dry-run)
nix build path:.#nixosConfigurations.<name>.config.system.build.toplevel --dry-run
# Available names: minimal, basic, develop, server, rpi, rpi-cross, handheld, desktop, laptop, wsl-desktop, wsl-laptop, gui-minimal, gui-basic

# Build and switch (on a live NixOS system)
# CRITICAL: always use path: prefix - repo has gitignored files required for build
nixos-rebuild switch --sudo --ask-sudo-password --flake path:.#<name>
# Or use the shell alias: snr-switch <name>

# For the full "rebuild the current machine and fix what breaks" workflow, see
# the rebuild-and-fix task under "## Tasks".

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
- **Custom packages**: Prefer defining custom package functions in `nixos/packages.nix`. Check this shared package collection before creating a standalone package file.
- **Package references**: Normally instantiate the collection with `builtins.mapAttrs (name: value: pkgs.callPackage value { }) (import ./packages.nix)` and reference `packages.<name>` directly in the consuming module. Add an overlay only when integration specifically requires `pkgs.<name>`; convenience for a `nix run` command alone is not a reason to depart from direct references.
- **Plugin derivations**: Reuse `commonInstallPhase` and `trivialDerivation` patterns from `nixos/nvim-plugins.nix` when packaging plugins.

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

### OpenCode Skills (`opencode/`)

- `opencode/skills/` holds skills authored and maintained in this repo. Do not copy, vendor, or commit an upstream third-party skill's files into it.
- Track a third-party skill by its upstream reference, keeping upstream as the source of truth so updates flow from upstream.

## Key Conventions

1. **Discuss before modifying**: Directory structure, entry scripts, Nix/Home Manager behavior, or cross-platform differences require discussion first.
2. **Idempotent scripts**: All install/link/switch scripts must be safely re-runnable.
3. **Surface errors**: Scripts must not silently fail or degrade. Print concise error messages.
4. **Follow existing patterns**: New files and directories must follow the naming and layering of their siblings. Avoid cross-layer coupling.
5. **Keep existing documentation accurate**: When a structural change makes specific content in this file or an existing relevant README inaccurate, update only that content. Implementing a feature does not by itself require documentation changes. Create standalone documentation only when the user explicitly requests it; a request for code comments is not a request for a separate document. Example: correct an existing README command when its entry point changes, but do not create `docs/new-tool.md` merely because a new tool was added.
6. **Editing over rewriting**: When modifying docs, edit the targeted content only. Never delete-and-rewrite an entire file unless strictly necessary.
7. **Web search for uncertainty**: When discussing approaches, search the web for unfamiliar Nix options, APIs, or library behaviors to verify feasibility.

## Tasks

### rebuild-and-fix

Drive the current machine to a state where `snr-switch <machine>` completes end to end, repairing every build error it surfaces. Load the `nixos-config` skill as well; it owns option verification, the flake composition map, and the eval-before-build rules this task builds on.

#### Step 0: audit previous temporary fixes

Before the first `snr-switch`, review the temporary workarounds left behind by earlier builds and drop the ones upstream has already resolved. A stale pin is a latent failure, so this runs first.

Candidates, primarily in `nixos/overlays.nix`:

- Overrides inside the `# Begin/End Temporary self updated packages` and `# Begin/End Temporary fixed version packages` markers.
- Any other override or patch whose comment ties it to a build failure, or says to remove it once an upstream PR/commit lands.

Do not touch an override whose purpose is a local preference, feature port, or hardware workaround. Only remove a workaround when all of the following hold:

1. It is marked temporary, or its comment identifies an upstream PR/commit it is waiting on.
2. It exists to make the build succeed - it is not doing unrelated work such as enabling a feature.
3. Upstream has actually fixed the problem - verified, not assumed. For an upstream nixpkgs PR, check its merge state; for a pinned package version, check whether the currently pinned version still fails. Never decide this from memory.

Verify against the pinned nixpkgs source (`$NIX_PATH`), the repo's `flake.lock`, and the upstream PR or release page. Remove only the override plus its comment. Then let the build decide: if the same error reappears, the workaround was still needed - restore it and continue. When a pinned package has no temporary marker but the comment documents the failure it works around, check it the same way.

Report every removal with its name and the evidence that made it obsolete.

#### Step 1: determine the machine

`<machine>` is a `nixosConfigurations.<name>` output, not a file name. Derive it from evidence, never from assumption:

- Read `hostname`.
- Read the hostname each configuration declares, e.g. `nix eval --raw path:.#nixosConfigurations.<name>.config.networking.hostName`, and match it against `hostname`.
- Read the `nixos/custom/*.nix` module each configuration imports. The file name often differs from the output name (`server` imports `vulchi.nix`, `handheld` imports `rogxbox.nix`), and these modules add host-specific `specialArgs`.
- `nixos-rebuild list-generations` shows which targets were built before, which is a useful hint but not proof.

Pick the single configuration matching this host. Remote and cross-compiled targets (`server`, `handheld`, `rpi`, `rpi-cross`, `wsl-desktop`, `wsl-laptop`) describe other machines and cannot be switched here - never pass them to `snr-switch`. If no configuration matches, or more than one plausibly does, ask the user with the candidates and their hostnames instead of guessing.

#### Step 2: build and fix loop

Run `snr-switch <machine>` from `~/dotfiles`. It performs the full build and then the switch, so one invocation exercises everything. The build's own output is the evidence; do not pre-emptively evaluate a subset and call it done.

Before each build, check how much will be built locally with the build-cost check in the `nixos-config` skill (`references/build-cost-and-breakage.md`, `scripts/build_cost.py dry-run <machine>`). Passing the resource gate is necessary but not sufficient. If the build conditions defined there are not met, report the list and ask the user through Step 4 before building; do not start the build.

On failure:

1. Re-run the failing stage with `--show-trace` and read the first real error, not the last symptom or a downstream cascade.
2. Classify it and apply the matching fix from Step 3. Smallest change that fully solves the problem, following the existing patterns in the file it belongs to.
3. Re-run `snr-switch <machine>`. The task is done only when the switch and activation complete, not when evaluation or one package succeeds.

Repeat until it succeeds or the failure needs a decision from the user. Each iteration is a full rebuild, so budget for it: prefer one well-understood fix over several speculative ones, and re-read the failing package's expression before editing. Never weaken a build (removing a check, dropping a feature, forcing a broken substitute) just to get past an error. The resource gate in the `nixos-config` skill still applies to the underlying `nix build` work.

#### Step 3: fix playbook

**Deprecated or removed upstream API** - migrate to the current usage.

- Confirm the deprecation against the pinned nixpkgs source, not from memory: read the module or option definition, and search the nixpkgs commit or PR that removed it.
- Update the owning module in this repo to the current spelling, types, and structure. Option renames, type changes, and moved attributes all count.
- Update the repo's own documentation only where the change makes an existing line inaccurate. Do not add a changelog or migration note unless asked.

**The pinned upstream version is broken** - pin to a known-good version.

- Confirm the break is upstream rather than a misconfiguration in this repo: reproduce it and check the upstream issue tracker or release notes for the failure signature.
- Implement the pin in `nixos/overlays.nix` using the `super` pattern, and place it inside the `# Begin Temporary fixed version packages` markers.
- Comment it with the concrete reason and a reference: the failing version, what breaks, and the upstream issue or PR. A pin without that comment cannot be audited later and will be missed by Step 0.
- Verify the working version before pinning it. Never guess a version number or hash.

Changes to a package may also belong in `nixos/packages.nix`, in a host-specific `nixos/custom/<name>.nix`, or as a new patch in `nixos/patches/` - put the fix where the existing layout puts that kind of change.

Before applying any package fix, including a temporary one, count its real dependents in the target closure as described in the `nixos-config` skill (`scripts/build_cost.py dependents`): each of them becomes a cache miss that must be built locally. If the fix would cause many cache misses, confirm the solution with the user through Step 4 before applying it. When the fix is a pin or an input rollback, compare the candidates with the trade-off rules in `references/build-cost-and-breakage.md`.

#### Step 4: escalate to the user

Stop and ask when neither playbook entry fits, when the fix would trade away functionality or stability, or when the repair is non-trivial - a redesign, a cross-module refactor, a new input, a version downgrade across many packages, a fix that causes many cache misses (see Step 3), a build whose local build list does not meet the build conditions (see Step 2), or anything that changes what the machine does rather than making it build.

Use the `question` tool and give the user what they need to decide:

- The failing command and the actual error text.
- The root cause, and the evidence that established it.
- What was already tried and why it did not work.
- The options, each with its concrete cost, plus a recommendation and why.

Then stop. Do not apply a speculative workaround, and do not present an unverified guess as a diagnosis.

#### Reporting

When the build succeeds, summarize: the target machine, what was removed in Step 0 and why, every fix applied with its file, and anything left for the user to do. Leave all changes uncommitted and report the diff - committing requires explicit authorization.

