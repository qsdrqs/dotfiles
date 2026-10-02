#!/usr/bin/env python3
"""List recent NixOS channel releases as rollback candidates.

Usage:
  channel_revs.py [--channel unstable|unstable-small|26.05|...] [--days N]

Reads the release list from releases.nixos.org (S3 listing of
nixos/<channel>/), newest first, and prints for each release its full nixpkgs
revision and commit date. The commit date is the same timestamp flake.lock
records as lastModified. Listing stops at the first release whose commit date
is older than today minus N days (default 8); that release is printed as the
window boundary.

Commit dates come from the GitHub API through the authenticated `gh` CLI.

Each listed revision can be evaluated as a candidate with, for example:
  build_cost.py dry-run desktop --override-input nixpkgs github:NixOS/nixpkgs/<rev>
"""

import argparse
import datetime
import json
import re
import subprocess
import sys
import urllib.parse
import urllib.request

BUCKET = "https://nix-releases.s3.amazonaws.com/"
RELEASE = re.compile(r"/nixos-(\d+\.\d+)(?:pre|\.)(\d+)\.([0-9a-f]{7,})/$")


def list_releases(channel):
    prefix = f"nixos/{channel}/nixos-"
    releases, token = [], None
    while True:
        query = {"list-type": "2", "prefix": prefix, "delimiter": "/"}
        if token:
            query["continuation-token"] = token
        with urllib.request.urlopen(BUCKET + "?" + urllib.parse.urlencode(query), timeout=60) as r:
            text = r.read().decode()
        for p in re.findall(r"<Prefix>([^<]+)</Prefix>", text):
            m = RELEASE.search(p)
            if m:
                releases.append((int(m.group(2)), p.rstrip("/").rsplit("/", 1)[1], m.group(3)))
        m = re.search(r"<NextContinuationToken>([^<]+)</NextContinuationToken>", text)
        if not m:
            return sorted(releases, reverse=True)
        token = m.group(1)


def commit_info(short_rev):
    proc = subprocess.run(
        ["gh", "api", f"repos/NixOS/nixpkgs/commits/{short_rev}",
         "--jq", "{sha: .sha, date: .commit.committer.date}"],
        capture_output=True, text=True,
    )
    if proc.returncode != 0:
        sys.exit(f"error: gh api failed for {short_rev}: {proc.stderr.strip()}")
    info = json.loads(proc.stdout)
    date = datetime.datetime.fromisoformat(info["date"].replace("Z", "+00:00"))
    return info["sha"], date


def main():
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--channel", default="unstable", help="releases.nixos.org channel dir")
    parser.add_argument("--days", type=int, default=8, help="window size in days")
    args = parser.parse_args()

    releases = list_releases(args.channel)
    if not releases:
        sys.exit(f"error: no releases found under nixos/{args.channel}/")
    cutoff = datetime.date.today() - datetime.timedelta(days=args.days)
    rows = []
    for _, name, short_rev in releases:
        sha, date = commit_info(short_rev)
        inside = date.date() >= cutoff
        mark = "" if inside else "  <- older than window"
        rows.append(f"{date:%Y-%m-%d %H:%M}Z  {sha}  {name}{mark}")
        if not inside:
            break
    table = "\n".join(rows)
    print(f"""channel: {args.channel}, window: commit date >= {cutoff} (today - {args.days} days)
{table}""")


if __name__ == "__main__":
    main()
