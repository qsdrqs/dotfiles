#!/bin/sh
set -e

# Start nix-daemon in background (required for multi-user nix in container)
nix-daemon &

# Wait for daemon socket
for i in $(seq 1 60); do
    [ -S /nix/var/nix/daemon-socket/socket ] && break
    sleep 0.5
done

if [ -S /nix/var/nix/daemon-socket/socket ]; then
    echo "nix-daemon ready"
else
    echo "WARNING: nix-daemon socket not found after 30s, continuing anyway"
fi

# Start sshd in foreground
exec $(readlink -f $(which sshd)) -D -e
