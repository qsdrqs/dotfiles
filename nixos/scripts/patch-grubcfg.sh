#!/bin/sh
set -eu

[ "$#" -eq 1 ] || [ "$#" -eq 2 ] || { echo "usage: $0 <grub.cfg> [efi_mount_point]" >&2; exit 2; }

grubcfg=$1
efi_mount_point=${2:-/boot/efi}

[ -f "$grubcfg" ] || { echo "error: grub.cfg not found: $grubcfg" >&2; exit 1; }
case "$efi_mount_point" in /*) ;; *) echo "error: efi mount point must be absolute: $efi_mount_point" >&2; exit 1;; esac

for cmd in findmnt blkid awk mktemp cp; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "error: missing required command: $cmd" >&2; exit 1; }
done

efi_mount_point=${efi_mount_point%/}
envfile_host=$efi_mount_point/grubenv
envfile_dir=$(dirname "$envfile_host")
mnt=$(findmnt -no TARGET -T "$envfile_dir") || { echo "error: failed to resolve mountpoint for: $envfile_dir" >&2; exit 1; }
dev=$(findmnt -no SOURCE -T "$envfile_dir") || { echo "error: failed to resolve device for: $envfile_dir" >&2; exit 1; }
uuid=$(blkid -o value -s UUID "$dev") || { echo "error: failed to resolve UUID for device: $dev" >&2; exit 1; }

case "$envfile_host" in
  "$mnt"/*) rel=${envfile_host#"$mnt"} ;;
  *) echo "error: envfile path is not under mountpoint $mnt: $envfile_host" >&2; exit 1 ;;
esac

envfile_grub="(\$esp)$rel"
search_line="search --no-floppy --fs-uuid --set=esp $uuid"
envfile_line="set envfile=\"$envfile_grub\""

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

backup="${grubcfg}.bak"
cp -p -- "$grubcfg" "$backup" || { echo "error: failed to create backup: $backup" >&2; exit 1; }

awk -v search_line="$search_line" -v envfile_line="$envfile_line" '
function indent(line){match(line,/^[ \t]*/); return substr(line,RSTART,RLENGTH)}
BEGIN{seen_search=0; seen_envfile=0; inserted=0; if_found=0; load_found=0; save_found=0}
{
  if (!inserted) {
    if ($0 ~ /^[ \t]*#/) { print; next }
    if ($0 ~ /^[ \t]*$/) { print; next }
    print search_line
    print envfile_line
    inserted=1
    seen_search=1
    seen_envfile=1
  }
  if ($0 ~ /^[ \t]*#/) { print; next }
  if ($0 ~ /^[ \t]*search[ \t].*--set=esp([ \t]|$)/) { seen_search=1; print indent($0) search_line; next }
  if ($0 ~ /^[ \t]*set[ \t]+envfile=/) { seen_envfile=1; print indent($0) envfile_line; next }
  if ($0 ~ /^[ \t]*(if|elif)[ \t]+\[[^]]*-s[ \t]+"?\$prefix\/grubenv"?[^]]*\][ \t]*;[ \t]*then/ || $0 ~ /^[ \t]*(if|elif)[ \t]+\[[^]]*-s[ \t]+"?\$envfile"?[^]]*\][ \t]*;[ \t]*then/) {
    ind=indent($0)
    kw="if"
    if ($0 ~ /^[ \t]*elif[ \t]+/) { kw="elif" }
    print ind kw " [ -s \"$envfile\" ]; then"
    if_found++
    next
  }
  if ($0 ~ /^[ \t]*load_env([ \t]|$)/) { load_found++; print indent($0) "load_env --file \"$envfile\""; next }
  if ($0 ~ /^[ \t]*save_env[ \t]+/) {
    save_found++
    ind=indent($0)
    sub(/^[ \t]*save_env[ \t]+/, "", $0)
    sub(/^--file[ \t]+[^ \t]+[ \t]+/, "", $0)
    print ind "save_env --file \"$envfile\" " $0
    next
  }
  print
}
END{
  if (!inserted) {
    print search_line
    print envfile_line
    inserted=1
    seen_search=1
    seen_envfile=1
  }
  if (if_found==0) { print "error: did not find grubenv check line" >"/dev/stderr"; exit 1 }
  if (load_found==0) { print "error: did not find load_env" >"/dev/stderr"; exit 1 }
  if (save_found==0) { print "error: did not find save_env" >"/dev/stderr"; exit 1 }
  if (!seen_search) { print "error: missing esp search line" >"/dev/stderr"; exit 1 }
  if (!seen_envfile) { print "error: missing envfile line" >"/dev/stderr"; exit 1 }
}
' "$grubcfg" > "$tmp"

cp -p "$tmp" "$grubcfg"
