#!/usr/bin/env python3
"""Patch grub.cfg pipeline: discover EFI UUID, patch, validate, install wrapper."""
import argparse
import os
import shutil
import subprocess
import sys
import tempfile

_script_dir = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, _script_dir)

import re

import patch_grub_cfg
import validate_grub_patch

_WRAPPER_TEMPLATE_PATH = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "grub-wrapper.cfg",
)

# FAT32 UUID: XXXX-XXXX; GPT/ext/btrfs: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
_UUID_RE = re.compile(
    r"^[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}$"
    r"|^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"
)


def discover_efi_uuid(efi_mount):
    try:
        dev = subprocess.check_output(
            ["findmnt", "-no", "SOURCE", "-T", efi_mount],
            text=True,
        ).strip()
    except (subprocess.CalledProcessError, FileNotFoundError) as e:
        raise RuntimeError(
            "Failed to resolve device for {}: {}".format(efi_mount, e)
        )

    if not dev:
        raise RuntimeError(
            "findmnt returned empty device for {}".format(efi_mount)
        )

    uuid = ""
    errors = []
    for cmd in (
        ["blkid", "-o", "value", "-s", "UUID", dev],
        ["lsblk", "-no", "UUID", dev],
    ):
        try:
            uuid = subprocess.check_output(cmd, text=True).strip()
        except (subprocess.CalledProcessError, FileNotFoundError) as e:
            errors.append("{}: {}".format(cmd[0], e))
            continue
        if uuid:
            break

    if not uuid:
        raise RuntimeError(
            "Failed to resolve UUID for device {} via blkid/lsblk{}".format(
                dev,
                ": {}".format("; ".join(errors)) if errors else "",
            )
        )

    if not _UUID_RE.match(uuid):
        raise RuntimeError(
            "Invalid filesystem UUID for device {}: {!r}".format(dev, uuid)
        )

    return uuid


def generate_wrapper(uuid):
    with open(_WRAPPER_TEMPLATE_PATH) as f:
        template = f.read()
    return template.replace("@UUID@", uuid)


def run(efi_mount, grub_dir, grammar_lib):
    efi_env_path = "($efi_part)/grubenv"

    grub_cfg = os.path.join(grub_dir, "grub.cfg")
    efi_grubenv = os.path.join(efi_mount, "grubenv")
    grub_grubenv = os.path.join(grub_dir, "grubenv")

    if not os.path.exists(grub_cfg):
        raise RuntimeError("grub.cfg not found: {}".format(grub_cfg))

    uuid = discover_efi_uuid(efi_mount)
    print("EFI partition UUID: {}".format(uuid), file=sys.stderr)

    if not os.path.exists(efi_grubenv):
        if os.path.exists(grub_grubenv):
            shutil.copy2(grub_grubenv, efi_grubenv)
            print("Copied grubenv to {}".format(efi_grubenv), file=sys.stderr)
        else:
            print(
                "Warning: no grubenv found to copy to EFI partition",
                file=sys.stderr,
            )

    language = patch_grub_cfg.load_language(grammar_lib)

    tmpdir = tempfile.mkdtemp(prefix="grub-patch-")
    os.chmod(tmpdir, 0o700)
    try:
        tmp_original = os.path.join(tmpdir, "original-grub.cfg")
        tmp_patched = os.path.join(tmpdir, "patched-grub.cfg")

        shutil.copy2(grub_cfg, tmp_original)

        with open(tmp_original, "rb") as f:
            original_bytes = f.read()

        patched_bytes, edits = patch_grub_cfg.patch(
            original_bytes, efi_env_path, language,
        )

        with open(tmp_patched, "wb") as f:
            f.write(patched_bytes)

        print(
            "Patched: {}".format(patch_grub_cfg.summarize_edits(edits)),
            file=sys.stderr,
        )

        errors = validate_grub_patch.validate(
            tmp_original, tmp_patched, efi_env_path, language,
        )

        if errors:
            raise RuntimeError(
                "Validation failed ({} errors):\n  {}".format(
                    len(errors), "\n  ".join(errors),
                )
            )

        print("Validation passed.", file=sys.stderr)

        wrapper_content = generate_wrapper(uuid)
        tmp_wrapper = os.path.join(tmpdir, "grub.cfg")
        with open(tmp_wrapper, "w") as f:
            f.write(wrapper_content)

        def atomic_copy(src, dst):
            tmp = dst + ".tmp"
            shutil.copy2(src, tmp)
            os.rename(tmp, dst)

        atomic_copy(tmp_original, os.path.join(grub_dir, "original-grub.cfg"))
        atomic_copy(tmp_patched, os.path.join(grub_dir, "patched-grub.cfg"))
        atomic_copy(tmp_wrapper, grub_cfg)

        print("Installed to {}".format(grub_dir), file=sys.stderr)
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)


def main():
    ap = argparse.ArgumentParser(
        description="Full grub.cfg patching pipeline.",
    )
    ap.add_argument(
        "--efi-mount",
        required=True,
        help="EFI system partition mount point (e.g., /boot/efi)",
    )
    ap.add_argument(
        "--grub-dir",
        required=True,
        help="GRUB directory (e.g., /boot/grub)",
    )
    ap.add_argument(
        "--grammar-lib",
        required=True,
        help="Path to compiled tree-sitter-grub .so",
    )
    args = ap.parse_args()

    if not os.path.exists(args.grammar_lib):
        print(
            "error: grammar library not found: {}".format(args.grammar_lib),
            file=sys.stderr,
        )
        sys.exit(2)

    try:
        run(args.efi_mount, args.grub_dir, args.grammar_lib)
    except Exception as e:
        print("ERROR: {}".format(e), file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
