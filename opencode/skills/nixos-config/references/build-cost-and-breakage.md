# Build cost and broken packages

Read this when a dry-build would compile heavy packages locally, when a package fails to build after an input update, or when choosing between pinning packages and rolling back a nixpkgs input.

Contents: 1. Measure the build cost - 2. Find out why it is not cached - 3. Options when the build is too large - 4. Trade-off rules - 5. When a package fails to build - 6. Recording a fix - 7. Practical notes

## 1. Measure the build cost

- Before building a whole configuration, run `scripts/build_cost.py dry-run <name>`. It runs `nix build --dry-run` on the toplevel (the daemon queries the substituters, so the "will be built" list is reliable) and splits the result into wiring, real, and heavy builds. `--from-log FILE` parses existing output of `nixos-rebuild dry-build`.
- **Heavy package**: slow to compile and normally served by a binary cache. Examples: CUDA packages (`cudaPackages.*`, `tensorrt`), CUDA-enabled consumers (`onnxruntime`, `opencv`, `openvino`, `ollama`, `llama-cpp`), unwrapped browsers (`firefox-unwrapped` and variants such as `firefox-esr-unwrapped`, `firefox-devedition-unwrapped`). Browser wrappers such as `firefox` are light. The script's name pattern is a heuristic: judge real builds it does not flag, and add patterns with `--heavy`.
- **Wiring derivations** only aggregate or wire up the system: `system-path`, `etc`, `system-units`, `user-units`, `dbus-1`, `unit-*.service`, `X-Restart-Triggers-*`, `activate`, the `nixos-system-*` toplevel, generated config files. They are always built locally and are cheap; ignore them when judging cost or counting dependents.
- **Build conditions**: the resource gate in `SKILL.md` is necessary but not sufficient. The conditions are not met when the build list contains a heavy package, unless the configuration itself changes that package's source (a local patch or override), which no cache can serve. Report the list and ask the user before building.
- Any edit in the repo changes the toplevel, because `NIX_CURR_PROFILE_SOURCE = ../.` copies the repo into the system. This only adds wiring builds.

## 2. Find out why it is not cached

- Check specific paths with `scripts/cache_status.sh <path|drv|installable>`, which requests `<cache>/<hash>.narinfo` from each configured substituter.
- Do not treat `nix path-info --store <cache> <path>` failures as misses. When `~/.cache/nix/binary-cache-v8.sqlite` is not writable by the current user (for example owned by root), it reports paths as missing. Read its stderr, or use `cache_status.sh`.
- Whether a package normally comes from a cache: check the running system's copy, e.g. `cache_status.sh "$(readlink -f /run/current-system/sw/bin/<prog>)"`.
- Who pulls a heavy package in: `scripts/build_cost.py dependents <name> '^onnxruntime-[0-9]'`.
- Check the builder:
  - hydra.nixos.org for ordinary packages.
  - hydra.nixos-cuda.org for CUDA builds. Its jobsets `cuda-packages-unstable` (follows `nixos-unstable-small`) and `cuda-packages-<release>` fill cache.nixos-cuda.org. Look at whether the job is queued, aborted, or failed, and at the success rate of the evaluation.
- After a mass rebuild (a staging-next merge, a compiler bump), the CUDA cache can lag `nixos-unstable` by days. A channel release does not imply that its CUDA closure is cached.

## 3. Options when the build is too large

Gather the same evidence for every candidate and compare them with section 4:

- local builds and download size: `build_cost.py dry-run <name> --override-input <input> <ref>` (the override does not touch `flake.lock`);
- versions of the affected packages compared with the running system;
- number of pins the candidate adds, and their real dependents (`build_cost.py dependents`);
- side effects on other configurations.

| Option | Fits when | Watch for |
|---|---|---|
| Pin from `pkgs-last` | `nixpkgs-last` points at a revision whose builds are cached, ideally the one the running system was built from (outputs already in the store) | Its import must use the system's config (`cudaSupport`, `allowUnfree`), otherwise store paths differ. Unsuitable when `nixpkgs-last` is old or when many packages would have to come from it. |
| Pin from stable | stable serves the package with the same config | Versions may be older; plugins must come from the same package set as their host (e.g. `obs-studio` with `obs-studio-plugins`); downloads a second dependency set. |
| Roll back `nixpkgs` | a slightly older channel release has a clean dry-run | List candidates with `scripts/channel_revs.py`, then dry-run each with `--override-input nixpkgs github:NixOS/nixpkgs/<rev>`. |
| Roll back `nixpkgs-stable` | a slightly older stable release serves the packages | `scripts/channel_revs.py --channel <release>`. Affects every configuration built from `nixpkgs-stable` (e.g. `server`). |
| Wait for Hydra | the job is queued and the jobset is progressing | No fixed timeline; do not switch to the uncached revision meanwhile. |
| Build locally | only with explicit user consent | |

Do not offer feature-reduced variants (e.g. non-CUDA builds on a CUDA host) as a way around a cache gap.

`pkgs-last` and `pkgs-stable` are imported in `nixos/overlays.nix`; pins go into the `# Begin Temporary fixed version packages` block, e.g. `obs-studio = pkgs-last.obs-studio;`.

## 4. Trade-off rules

Apply in priority order, 1 before 2 before 3:

1. **The update must really update most packages.** Reject a candidate when most of the system would stay on pins or on an old revision, even if it needs no builds and no pins. A rollback target must still be clearly newer than the running system.
2. **Build as little as possible locally.** No heavy local builds unless unavoidable (the configuration changes that package's source).
3. **Pin as few packages as possible.** Count only pins added to resolve the current update, one per overridden attribute. In principle, more than 8 new pins means preferring a rollback of `nixpkgs` or `nixpkgs-stable`, provided rules 1 and 2 still hold.

Rollback window: applies only to the revisions of the `nixpkgs` and `nixpkgs-stable` inputs, not to pins. In principle, do not roll back to a revision older than about one week, judged by its commit date (`lastModified` in `flake.lock`): on 10-01, nothing before 09-23. This is the default window of `channel_revs.py`.

Downgrades relative to the running system are not a hard constraint unless there is concrete evidence of an incompatibility, such as a documented data or profile format change. A minor browser version step back is not by itself such evidence.

The "in principle" limits (8 pins, one week) may be exceeded when the evidence shows that doing so is the better option: propose it with the data, and apply it only after the user agrees. When candidates remain tied, present the evidence per candidate and let the user decide.

## 5. When a package fails to build

1. Collect the independent failures with `--keep-going`. `builder for ... failed` marks a package that is itself broken; `dependency failed` is a cascade.
2. Reproduce one failure alone with `nix build '<drv>^*' -L` and read the first real error, not the last symptom.
3. Classify it:

| Kind | Approach |
|---|---|
| Source download fails (403, 404, archived object) | Inspect the redirect chain and headers with `curl -sIL`. Look for an official alternative artifact, a mirror, or a substituter copy. If none exists, disabling the package needs user consent. |
| Toolchain or stdenv change (new compiler defaults, stricter warnings) | Search nixpkgs issues and PRs for the failure signature. Check whether a fix is in the locked revision with `gh api repos/NixOS/nixpkgs/compare/<fix-commit>...<locked-rev> --jq .status`: `ahead` or `identical` means included. Fixed upstream but not locked: update the input or backport. Not fixed: pin a working build from `pkgs-last` or stable. |
| Infrastructure or hook regression affecting a whole package set | Find the upstream fix. Updating or backporting it changes many derivations, so measure with section 1 before applying it. |
| Removed, renamed, or end-of-life attribute or option | Migrate according to the pinned nixpkgs source. |

4. Before applying a fix, count its real dependents with `build_cost.py dependents` and check whether the result will be cached: a backport or patch creates new derivations that must be built locally, together with all their dependents, while a pin to an older cached build usually only downloads. Ask the user when the fix causes many cache misses.
5. Verify in stages: build the single package and run a basic command such as `--version`, then dry-run the whole configuration, then build it.

## 6. Recording a fix

- Put temporary fixes in the `# Begin Temporary ...` blocks of `nixos/overlays.nix`. The comment states the failing version, what breaks, the upstream issue or PR, and when to remove it, so that later audits can decide whether it is obsolete.
- For pins that bridge a cache gap, name the gap and the removal condition, e.g. "remove once cache.nixos-cuda.org covers the current nixpkgs input".
- When re-adding an override removed earlier, restore it at its original place and change only the lines that must differ.

## 7. Practical notes

- Run long builds detached (`setsid nohup <cmd> > <log> 2>&1 &`) so they survive restarts of the calling shell, and follow progress in the log.
- Run `nix` and `nixos-rebuild` against `path:` flake refs from `~/dotfiles`.
- `flake.lock` node names can differ from input names (the root input `nixpkgs` may be the node `nixpkgs_3`); resolve them through `nodes.root.inputs`.
- Commit date of a nixpkgs revision: `gh api repos/NixOS/nixpkgs/commits/<rev> --jq .commit.committer.date`.
