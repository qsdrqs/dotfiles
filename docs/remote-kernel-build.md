# One-Off Remote Kernel Build

This runbook builds the handheld kernel on `DESKSERVER`, copies every kernel
output back to the local Nix store, and leaves the remaining NixOS build for
the local machine. It does not require persistent distributed-build
configuration.

## Why This Method

Using a remote store without a separate evaluation store can make evaluation
of this flake slow because Nix performs store operations over SSH. Keep
evaluation local and use the remote machine only as the build store:

```text
--eval-store auto --store ssh-ng://DESKSERVER
```

The `^*` suffix requests every output of the multi-output kernel derivation,
including `out`, `dev`, and `modules`. The kernel configuration is a separate
derivation, so the command also requests `kernel.configfile` explicitly.

## Prerequisites

- `DESKSERVER` is reachable through the local SSH configuration.
- Nix is installed and its daemon is running on `DESKSERVER`.
- The remote SSH user is listed in `nix.settings.trusted-users` on
  `DESKSERVER`.
- Both machines use the normal `/nix/store` logical store path.

Verify remote store access:

```bash
nix store info --store ssh-ng://DESKSERVER
```

The command should report the remote Nix version and `Trusted: 1`.

## Run In Tmux

Start a detached tmux session from the dotfiles repository:

```bash
tmux new-session -d \
  -s remote-kernel-build \
  -c /home/qsdrqs/dotfiles \
  "bash -lc '
    set -euo pipefail
    : > /tmp/remote-kernel-build.log
    exec > >(tee -a /tmp/remote-kernel-build.log) 2>&1

    nix build \
      --eval-store auto \
      --store ssh-ng://DESKSERVER \
      \"path:.#nixosConfigurations.handheld.config.boot.kernelPackages.kernel^*\" \
      \"path:.#nixosConfigurations.handheld.config.boot.kernelPackages.kernel.configfile\" \
      --no-link \
      --print-out-paths \
      -L \
      > /tmp/remote-kernel-outputs

    nix copy \
      --no-check-sigs \
      --from ssh-ng://DESKSERVER \
      \$(</tmp/remote-kernel-outputs)

    echo \"Kernel outputs copied to the local Nix store\"
  '"

tmux set-option -t remote-kernel-build remain-on-exit on
```

The build runs on `DESKSERVER`. Evaluation still happens locally, and the
final `nix copy` transfers all kernel outputs back to the local machine.

## Monitor Progress

Attach to the session:

```bash
tmux attach -t remote-kernel-build
```

Detach without stopping it by pressing `Ctrl-b`, then `d`.

Follow the saved log without attaching:

```bash
less +F /tmp/remote-kernel-build.log
```

Check whether the pane is still running:

```bash
tmux list-panes \
  -t remote-kernel-build \
  -F '#{pane_dead} #{pane_exit_status} #{pane_current_command}'
```

The first field is `0` while the command is running and `1` after it exits.

## Verify Local Outputs

After the tmux command finishes successfully, verify every output recorded by
the remote build:

```bash
while IFS= read -r path; do
  nix path-info "$path"
done < /tmp/remote-kernel-outputs
```

Each path must be printed without an error. The output list must contain the
kernel `out`, `dev`, and `modules` paths plus the separate `linux-config` path.
The normal system switch can then reuse them from the local store:

```bash
snr-switch handheld
```

Only the remaining missing derivations will be built or downloaded locally.
Kernel-adjacent assembly steps such as `modules-shrunk` and `initrd` still run
locally, but they do not recompile the kernel source.

## Signature Handling

The remote builder may produce valid store paths without signing them with a
key trusted by the local Nix daemon. In that case, a normal `nix copy` fails
with:

```text
because it lacks a signature by a trusted key
```

This runbook uses `--no-check-sigs` for the one-off copy. Use it only after
verifying the SSH host identity and only with a builder under your control.
SSH host-key verification still protects the transport; this option bypasses
the separate Nix store-path signature check.

For a shared or untrusted builder, configure Nix store signing instead of
using `--no-check-sigs`.

## Troubleshooting

### Remote evaluation is unexpectedly slow

Ensure the build command contains both options:

```text
--eval-store auto --store ssh-ng://DESKSERVER
```

Without `--eval-store auto`, flake evaluation and source-store operations may
run against the remote store over SSH.

### SSH reports `Permission denied (publickey)`

Confirm that the current shell has access to the SSH key or agent used by the
`DESKSERVER` host entry:

```bash
ssh -o BatchMode=yes DESKSERVER nix --version
```

### The log contains `patchelf: wrong ELF type`

Kernel outputs contain files that are not dynamically linked ELF binaries.
The generic Nix fixup phase may print these messages while scanning them. They
are not a build failure by themselves. Check the final tmux exit status and
verify the output paths.

### Tmux exits after compilation

Inspect the end of the log:

```bash
less +G /tmp/remote-kernel-build.log
```

If compilation completed but copying failed because of signatures, rerun only
the copy step:

```bash
nix copy \
  --no-check-sigs \
  --from ssh-ng://DESKSERVER \
  $(</tmp/remote-kernel-outputs)
```
