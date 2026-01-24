---
name: nixos-config
description: Modify the user's flake-based NixOS and Home Manager configuration in ~/dotfiles while preserving the existing structure and conventions. Use when asked to enable/disable NixOS services/options, add/remove packages, adjust overlays, update flake inputs/lockfiles, create/tweak host profiles (desktop/laptop/server/rpi/WSL), or debug Nix evaluation/build errors. Always verify option/module/API correctness against the pinned nixpkgs source (via $NIX_PATH and the repo's flake.lock) because Nix/NixOS APIs change quickly and docs may lag.
---

# NixOS Config

## Overview

Modify `~/dotfiles` NixOS + Home Manager configuration safely: make minimal, structured edits, validate builds, and cross-check options/APIs by reading the pinned nixpkgs source code instead of relying on stale docs.

## Workflow (use every time)

1. Read repo rules and locate the right layer
   - Read `~/dotfiles/AGENTS.md` (and any closer `AGENTS.md` under the subdir you touch).
   - Identify whether the change belongs to:
     - **System (NixOS)**: `~/dotfiles/flake.nix` + `~/dotfiles/nixos/*.nix`
     - **User (Home Manager)**: `~/dotfiles/nixos/home.nix` and related `*-home.nix`
     - **Dotfile linking / plugin injection**: `~/dotfiles/nixos/dotfiles.nix`
     - **Overlays / package overrides**: `~/dotfiles/nixos/overlays.nix`, `~/dotfiles/nixos/packages.nix`
     - **Host-specific overrides**: `~/dotfiles/nixos/custom/*.nix`
     - **Secrets/private material**: `~/dotfiles/nixos/private/` (do not leak)

2. Pick the correct flake output target
   - Prefer building/evaluating against the exact target you’re modifying.
   - Common targets in this repo:
     - NixOS: `~/dotfiles#nixosConfigurations.<name>` where `<name>` includes `minimal`, `basic`, `develop`, `gui-minimal`, `gui-basic`, `desktop`, `laptop`, `server`, `rpi`, `wsl-desktop`, `wsl-laptop`.
     - Home Manager: `~/dotfiles#homeConfigurations.<name>` where `<name>` includes `minimal`, `basic`, `standalone`, `wsl`, `termux`, `rpi`.

3. Verify the option/API exists (do not guess)
   - If you’re about to set an option (e.g. `services.foo.enable`), confirm it exists in the pinned nixpkgs.
   - Prefer **source-first verification**:
     - Extract nixpkgs source path from `$NIX_PATH` (commonly `nixpkgs=/nix/store/...-source`).
     - Search module definitions and read the module file:
       - `rg -n "options\\.services\\.foo\\." "$NIXPKGS_SRC/nixos/modules"`
       - `rg -n "services\\.foo\\." "$NIXPKGS_SRC/nixos/modules"`
   - Prefer **evaluation** when it’s faster/clearer:
     - Check that an option exists (and inspect its type/default):
       - `nix eval ~/dotfiles#nixosConfigurations.<name>.options.services.foo.enable`
     - If evaluation fails, retry with `--show-trace` and fix the root cause before editing more files.

4. Implement a minimal, structural-preserving change
   - Edit the *lowest* layer that semantically owns the change; avoid “random” edits in higher-level files.
   - Keep the existing module composition and file boundaries.
   - Follow existing patterns (`lib.mkDefault`, `lib.mkIf`, `lib.mkForce`) already used in nearby code.
   - If the change is host-specific, prefer `~/dotfiles/nixos/custom/<host>.nix` over global modules.

5. Validate (build first; switch only when asked)
   - NixOS build (fast, no activation):
     - `nix build ~/dotfiles#nixosConfigurations.<name>.config.system.build.toplevel`
   - Home Manager build:
     - `nix build ~/dotfiles#homeConfigurations.<name>.activationPackage`
   - If switching is requested, use the flake target explicitly:
     - `sudo nixos-rebuild switch --flake ~/dotfiles#<name>`
     - `home-manager switch --flake ~/dotfiles#<name>`
   - When something breaks, keep traces visible (`--show-trace`) and fix the first failure, not the last symptom.

6. Provide rollback guidance when you change active state
   - Mention the standard NixOS rollback mechanisms (generations / `nixos-rebuild --rollback`) appropriate to the user’s request.

## Dotfiles + NixOS layout (this repo)

### Entry points

- `~/dotfiles/flake.nix`: defines `nixosConfigurations.*`, `homeConfigurations.*`, overlays wiring, and per-profile module stacks.
- `~/dotfiles/flake.lock`: pins nixpkgs and other inputs (use as the “what version am I targeting?” source of truth).
- `~/dotfiles/update_nix.sh`: updates sub-flake inputs and runs `nix flake update` (use when the user explicitly asks to update pins).

### Flake composition map (high level)

- `minimal`: `compat.nix` + (`custom.nix` if present, else `empty.nix`) + `minimal-configuration.nix` + `overlays.nix` + Home Manager (`home.nix`)
- `basic`: `minimal` + `basic-configuration.nix` + vscode-server + NUR + nix-index + Home Manager (`nvim-plugins.nix`)
- `develop`: `basic` + `develop-configuration.nix`
- `gui-minimal`: `minimal` + `gui-minimal-configuration.nix` + Home Manager (`gui-home.nix`)
- `gui-basic`: `gui-minimal` + `gui-basic-configuration.nix`
- `desktop`: `develop` + `gui-basic` + `desktop-configuration.nix` + `nixos/custom/desktop.nix` (adds extra `specialArgs`, e.g. `pkgs-howdy`)
- `laptop`: `develop` + `gui-basic` + `laptop-configuration.nix`
- `server`: `basic` + `server-configuration.nix` + `nixos/custom/server.nix` (built with `nixpkgs-stable`)
- `rpi`: `basic` (aarch64) + `rpi-configuration.nix` + `nixos/custom/rpi.nix` (built with `nixos-raspberrypi`)
- `wsl-*`: `wsl-configuration.nix` + WSL home modules + `nixos/custom/wsl-*.nix` if present (flake references these files; create them when you actually need WSL targets)

### NixOS modules directory

`~/dotfiles/nixos/` contains the NixOS + Home Manager module files, plus scripts/patches/private data.

- Base/system profiles:
  - `minimal-configuration.nix`, `basic-configuration.nix`, `develop-configuration.nix`
  - `gui-minimal-configuration.nix`, `gui-basic-configuration.nix`
  - `desktop-configuration.nix`, `laptop-configuration.nix`, `server-configuration.nix`, `rpi-configuration.nix`
  - `wsl-configuration.nix` (and `wsl-home.nix`)
- Home Manager entry points:
  - `home.nix` (imports `dotfiles.nix`)
  - `gui-home.nix`, `standalone-home.nix`, `termux-home.nix`, `wsl-home.nix`
- Repo-to-$HOME linking and “dotfiles as derivations”:
  - `dotfiles.nix` links `.nvimrc.lua`, `.vim/`, `.tmux.conf*`, `.zshrc`, etc into `$HOME`, and injects zsh/tmux/yazi plugins.
- Packaging/overrides:
  - `overlays.nix`, `packages.nix`, `nvim-plugins.nix`
- Host-specific overrides:
  - `custom/desktop.nix`, `custom/server.nix`, `custom/rpi.nix`
  - Optional local override hook: `~/dotfiles/nixos/custom.nix` (included by `flake.nix` if present; otherwise `empty.nix` is used).
- Assets:
  - `patches/*.patch`, `scripts/*.py|sh`, `private/` (treat as sensitive).

## Pinned nixpkgs source (for “API is changing” reality)

Use the pinned source code to verify that an option/module/function exists and how it should be used.

- Prefer `$NIX_PATH` as a direct pointer to nixpkgs source (commonly `nixpkgs=/nix/store/...-source`).
- Use `scripts/nixpkgs_src.sh` to print the resolved nixpkgs source path.
- Use `~/dotfiles/flake.lock` to understand which nixpkgs revision your flake is actually pinned to (especially if `$NIX_PATH` differs).
- When docs disagree with code, trust the pinned code.

## Conventions (keep changes structured)

- Avoid refactors unless explicitly requested; patch the smallest correct file.
- Prefer adding new toggles/settings in the profile/module that already owns that domain.
- Keep “global defaults” in shared modules; keep “machine-specific” details in `~/dotfiles/nixos/custom/*.nix`.
- Keep errors visible: do not “silently ignore” evaluation/build failures.

## Optional local helpers

Use the scripts in `scripts/` for consistent, source-first lookups.

- Resolve nixpkgs source: `scripts/nixpkgs_src.sh`
- Find an option by source search: `scripts/find_nixos_option.sh services.openssh.enable --dotfiles ~/dotfiles`
