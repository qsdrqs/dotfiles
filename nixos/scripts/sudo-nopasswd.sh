# Temporary passwordless sudo toggle.
# Installed as `sudo-nopasswd` via packages.nix; the matching NOPASSWD
# sudoers rule for group "sudo-nopasswd" lives in minimal-configuration.nix.
#
# Usage: sudo-nopasswd {on|off|status} [user]
#   on     create the group if missing, add the user (idempotent)
#   off    remove the user, delete the group if it becomes empty (idempotent)
#   status show current state
# The user defaults to the invoking user (SUDO_USER) when run via sudo.
set -euo pipefail

GROUP=sudo-nopasswd
TARGET_USER="${SUDO_USER:-$(id -un)}"

usage() {
    echo "Usage: sudo-nopasswd {on|off|status} [user]"
    exit 1
}

[[ $# -ge 1 ]] || usage
ACTION=$1
[[ $# -ge 2 ]] && TARGET_USER=$2

case "$ACTION" in
    on)
        groupadd -f "$GROUP"
        usermod -aG "$GROUP" "$TARGET_USER"
        echo "enabled: $TARGET_USER now has passwordless sudo (group $GROUP)"
        getent group "$GROUP"
        ;;
    off)
        gpasswd -d "$TARGET_USER" "$GROUP" >/dev/null 2>&1 || true
        if getent group "$GROUP" >/dev/null 2>&1; then
            REMAINING=$(getent group "$GROUP" | cut -d: -f4 | tr ',' '\n' | sed '/^$/d')
            if [[ -z "$REMAINING" ]]; then
                groupdel "$GROUP" >/dev/null 2>&1 || true
                echo "disabled: removed $TARGET_USER from $GROUP; group deleted"
            else
                echo "disabled: removed $TARGET_USER from $GROUP; group kept (remaining members: $REMAINING)"
            fi
        else
            echo "disabled: $TARGET_USER not in $GROUP; group $GROUP does not exist"
        fi
        ;;
    status)
        if getent group "$GROUP" >/dev/null 2>&1; then
            echo "group $GROUP exists: $(getent group "$GROUP")"
        else
            echo "group $GROUP does not exist"
        fi
        if id -nG "$TARGET_USER" 2>/dev/null | grep -qw "$GROUP"; then
            echo "state: $TARGET_USER IS in $GROUP (passwordless sudo ENABLED)"
        else
            echo "state: $TARGET_USER is NOT in $GROUP"
        fi
        ;;
    *)
        usage
        ;;
esac
