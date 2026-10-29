#!/usr/bin/env python3
"""Copy a Chrome user-data directory for an independent browser.

Usage: copy-profile.py --source USER_DATA_DIR [--parent CACHE_DIR]
Print the private copy directory and userDataDir as JSON. The caller stops the
browser before removing the copy directory when the task is finished.
"""

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


def copy_profile(source, parent):
    source = source.expanduser().resolve(strict=True)
    if not source.is_dir() or not (source / "Local State").is_file():
        raise ValueError("Source must be a Chrome user-data directory containing Local State")
    parent = parent.expanduser().resolve()
    if parent == source or source in parent.parents:
        raise ValueError("Copy parent must be outside the source profile")
    parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    directory = Path(tempfile.mkdtemp(prefix="profile-copy-", dir=parent))
    target = directory / "user-data"
    try:
        subprocess.run(
            ["cp", "-a", "--reflink=auto", str(source), str(target)],
            check=True,
            timeout=600,
        )
        target.chmod(0o700)
        for pattern in ("Singleton*", "DevToolsActivePort", "*/Sessions"):
            for path in target.glob(pattern):
                if path.is_dir() and not path.is_symlink():
                    shutil.rmtree(path)
                else:
                    path.unlink()
    except BaseException:
        shutil.rmtree(directory)
        raise
    return {"directory": str(directory), "userDataDir": str(target)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument(
        "--parent",
        type=Path,
        default=Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache") / "chrome-devtools-cli",
    )
    args = parser.parse_args()
    try:
        result = copy_profile(args.source, args.parent)
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"Profile copy failed: {error}", file=sys.stderr)
        return 1
    print(json.dumps(result))
    return 0


if __name__ == "__main__":
    sys.exit(main())
