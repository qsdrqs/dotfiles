# Temporary passwordless sudo toggle with an automatic expiry.
# Installed as `sudo-nopasswd` via packages.nix; the matching NOPASSWD
# sudoers rule for group "sudo-nopasswd" lives in minimal-configuration.nix.
#
# Usage: sudo-nopasswd {on [duration]|off|status} [user]
#   on [duration] create the group if missing, add the user, and arm the
#                 automatic expiry (default 2h; duration like 30m, 2h, 1d)
#   off           remove the user, delete the group if it becomes empty
#                 (idempotent)
#   status        show current state and the remaining time
#   expire        internal: disable passwordless sudo once the expiry passed
#
# The expiry timestamp is stored in /var/lib/sudo-nopasswd/expires and the
# "sudo-nopasswd-expire" timer (minimal-configuration.nix) runs "expire" every
# minute. The state lives outside systemd because imperatively created group
# memberships survive reboots, where a transient timer would be lost.
# The user defaults to the invoking user (SUDO_USER) when run via sudo.
set -euo pipefail

GROUP=sudo-nopasswd
STATE_DIR=/var/lib/sudo-nopasswd
EXPIRES_FILE="${STATE_DIR}/expires"
DEFAULT_DURATION=2h

TARGET_USER="${SUDO_USER:-$(id -un)}"

usage() {
    echo "Usage: sudo-nopasswd {on [duration]|off|status} [user]"
    echo "  duration is an integer plus a unit: 30m, 2h, 1d (default ${DEFAULT_DURATION})"
    exit 1
}

# Convert a duration such as "2h" to seconds. GNU date parses a bare "2h" as
# 02:00 of the current day, so do not hand the value to `date -d`.
duration_seconds() {
    local value=$1
    if [[ ! ${value} =~ ^([0-9]+)([smhd])$ ]]; then
        echo "error: invalid duration '${value}' (expected e.g. 30m, 2h, 1d)" >&2
        exit 1
    fi
    local n=${BASH_REMATCH[1]} unit=${BASH_REMATCH[2]}
    case "${unit}" in
        s) echo $((n)) ;;
        m) echo $((n * 60)) ;;
        h) echo $((n * 3600)) ;;
        d) echo $((n * 86400)) ;;
    esac
}

group_exists() {
    getent group "${GROUP}" >/dev/null 2>&1
}

# Expiry drops the whole group: every member must lose passwordless sudo, not
# just the user recorded at "on" time.
disable_all() {
    if group_exists; then
        groupdel "${GROUP}" >/dev/null 2>&1 || true
        echo "expired: removed group ${GROUP} (passwordless sudo disabled)"
    else
        echo "expired: group ${GROUP} does not exist; nothing to disable"
    fi
    rm -f "${EXPIRES_FILE}"
}

[[ $# -ge 1 ]] || usage
ACTION=$1
shift

case "${ACTION}" in
    on)
        DURATION=${1:-${DEFAULT_DURATION}}
        [[ $# -ge 2 ]] && TARGET_USER=$2
        LIFETIME=$(duration_seconds "${DURATION}")
        groupadd -f "${GROUP}"
        usermod -aG "${GROUP}" "${TARGET_USER}"
        mkdir -p "${STATE_DIR}"
        EXPIRES_AT=$(($(date +%s) + LIFETIME))
        printf '%s\n' "${EXPIRES_AT}" >"${EXPIRES_FILE}"
        echo "enabled: ${TARGET_USER} now has passwordless sudo (group ${GROUP})"
        echo "expires: $(date -d "@${EXPIRES_AT}" '+%F %T') (in ${DURATION})"
        getent group "${GROUP}"
        ;;
    off)
        [[ $# -ge 1 ]] && TARGET_USER=$1
        gpasswd -d "${TARGET_USER}" "${GROUP}" >/dev/null 2>&1 || true
        if group_exists; then
            REMAINING=$(getent group "${GROUP}" | cut -d: -f4 | tr ',' '\n' | sed '/^$/d')
            if [[ -z ${REMAINING} ]]; then
                groupdel "${GROUP}" >/dev/null 2>&1 || true
                rm -f "${EXPIRES_FILE}"
                echo "disabled: removed ${TARGET_USER} from ${GROUP}; group deleted"
            else
                echo "disabled: removed ${TARGET_USER} from ${GROUP}; group kept (remaining members: ${REMAINING})"
            fi
        else
            rm -f "${EXPIRES_FILE}"
            echo "disabled: ${TARGET_USER} not in ${GROUP}; group ${GROUP} does not exist"
        fi
        ;;
    status)
        [[ $# -ge 1 ]] && TARGET_USER=$1
        if group_exists; then
            echo "group ${GROUP} exists: $(getent group "${GROUP}")"
        else
            echo "group ${GROUP} does not exist"
        fi
        if id -nG "${TARGET_USER}" 2>/dev/null | grep -qw "${GROUP}"; then
            echo "state: ${TARGET_USER} IS in ${GROUP} (passwordless sudo ENABLED)"
        else
            echo "state: ${TARGET_USER} is NOT in ${GROUP}"
        fi
        if [[ -f ${EXPIRES_FILE} ]] && read -r EXPIRES_AT <"${EXPIRES_FILE}" && [[ ${EXPIRES_AT} =~ ^[0-9]+$ ]]; then
            NOW=$(date +%s)
            if ((NOW >= EXPIRES_AT)); then
                echo "expiry: $(date -d "@${EXPIRES_AT}" '+%F %T') passed (pending timer run)"
            else
                LEFT=$((EXPIRES_AT - NOW))
                echo "expiry: $(date -d "@${EXPIRES_AT}" '+%F %T') ($((LEFT / 3600))h$(printf '%02d' $(((LEFT % 3600) / 60)))m remaining)"
            fi
        else
            echo "expiry: none recorded"
        fi
        ;;
    expire)
        [[ -f ${EXPIRES_FILE} ]] || exit 0
        read -r EXPIRES_AT <"${EXPIRES_FILE}"
        [[ ${EXPIRES_AT} =~ ^[0-9]+$ ]] || exit 0
        (( $(date +%s) >= EXPIRES_AT )) || exit 0
        disable_all
        ;;
    *)
        usage
        ;;
esac
