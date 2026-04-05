---
name: nix
description: Nix flake-based development environment management. Use when the project has flake.nix in the root directory, or when the user indicates that Nix should be used to manage dependencies and dev shells. Triggers include (1) flake.nix or shell.nix detected in project root, (2) user mentions using nix develop, nix shell, or nix-based dependency management, (3) missing shared libraries (e.g., libstdc++.so) that should be resolved via Nix LD path. This skill is for project-level Nix usage, NOT for NixOS system configuration (use nixos-config skill for that).
---

# Nix Dev Environment

Guide for working in Nix flake-based development environments.

## Flake-first policy

Always use flake-based commands. Never use legacy Nix commands.

| Use (flake) | Do NOT use (legacy) |
|---|---|
| `nix develop` | `nix-shell` |
| `nix build` | `nix-build` |
| `nix run` | `nix-env -i` |
| `nix shell nixpkgs#pkg` | `nix-shell -p pkg` |
| `nix flake update` | `nix-channel --update` |

## Workflow

### 1. Detect and read the flake

Before running build/test commands, check for `flake.nix` in the project root. Read it to understand:
- Available `devShells` (default and named)
- Available `packages`
- Build inputs and their pins in `flake.lock`

### 2. Enter dev shell

Run project commands inside the Nix dev shell:

```bash
# Enter default dev shell
nix develop

# Enter a named dev shell
nix develop .#shellName

# Run a single command inside the dev shell without entering it
nix develop --command bash -c "cargo build"
```

When executing build/test/lint commands for the project, always run them inside `nix develop` to ensure correct toolchain and dependencies.

### 3. Missing shared libraries

When encountering errors like:
- `error while loading shared libraries: libstdc++.so.6: cannot open`
- `libGL.so.1: cannot open shared object file`
- Any `*.so: cannot open shared object file`

**Step 1**: Export the Nix LD library path:

```bash
export LD_LIBRARY_PATH=$NIX_LD_LIBRARY_PATH:$LD_LIBRARY_PATH
```

**Step 2**: If step 1 does not resolve the error, add the missing libraries to `buildInputs` in the flake's `devShell` and export via `shellHook`:

```nix
buildInputs = with pkgs; [
  somePackageProvidingLib
];
shellHook = ''
  export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath buildInputs}:$LD_LIBRARY_PATH"
'';
```

Identify the correct Nix package for the missing `.so` by searching nixpkgs (e.g., `libstdc++.so.6` comes from `stdenv.cc.cc.lib`, `libz.so` from `zlib`).

### 4. Build and run

```bash
# Build the default package
nix build

# Build a specific package
nix build .#packageName

# Run without installing
nix run .#packageName
```

## Key rules

- **Flake lockfile**: Do not modify `flake.lock` manually. Use `nix flake update` or `nix flake lock --update-input <input>`.
- **Impure builds**: If a build requires impure access (e.g., network), use `--impure` flag explicitly and note it.
- **Evaluation errors**: Use `--show-trace` to debug. Fix the first error in the trace, not the last.
- **Trusted substituters**: If binary cache prompts appear, inform the user rather than auto-accepting.
