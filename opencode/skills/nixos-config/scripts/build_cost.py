#!/usr/bin/env python3
"""Measure what a NixOS configuration would build locally.

Usage:
  build_cost.py dry-run <target> [--dotfiles DIR] [--override-input NAME REF]...
                [--heavy REGEX] [--log FILE]
  build_cost.py dry-run --from-log FILE [--heavy REGEX]
  build_cost.py dependents <target> <name-regex>... [--dotfiles DIR]
                [--override-input NAME REF]...

<target> is a nixosConfigurations name (e.g. desktop), or a full installable
containing '#'. The flake is referenced as path:<DIR> so git-ignored files are
included. DIR defaults to $DOTFILES, then ~/dotfiles.

dry-run runs `nix build --dry-run` (the daemon checks the configured
substituters) and splits the derivations that would be built into:
  - wiring: system/config glue (system-path, etc, unit files, ...), always
    built locally and cheap;
  - real: everything else;
  - heavy: real builds whose name matches the heavy pattern (CUDA stack and
    CUDA consumers, unwrapped browsers, toolchains, kernels, ...).
--from-log parses existing dry-run output, e.g. from `nixos-rebuild dry-build`.

dependents counts the derivations in the target's build closure that
transitively depend on the derivations whose name matches <name-regex>, i.e.
what would be rebuilt if those derivations changed. Wiring derivations are
listed separately and are not counted as real dependents.
"""

import argparse
import os
import re
import subprocess
import sys

WIRING = re.compile(
    r"^(system-path|etc|system-units|user-units|dbus-1|unit-.*|X-Restart-Triggers-.*"
    r"|activate|activation-script|dry-activate|set-environment|nixos-system-.*|etc-.*"
    r"|user-environment|home-manager-.*|hm_.*"
    r"|ensure-all-wrappers-paths-exist|hwdb\.bin|udev-rules|security-wrapper-.*"
    r"|.*-(wrapper|env|files|config|init|extracted|bwrap)|.*-fhsenv-.*"
    r"|.*\.(conf|service|socket|timer|target|path|mount|json|sh|desktop|rules|toml"
    r"|ini|lua|py|pl|js|yaml|yml))$"
)

HEAVY = (
    r"cuda|cudnn|nccl|tensorrt|magma|onnxruntime|opencv|openvino|ollama|llama-cpp"
    r"|torch|firefox.*-unwrapped|thunderbird.*-unwrapped|chromium|electron"
    r"|qtwebengine|webkitgtk|libreoffice|^llvm-\d|^clang-\d|^rustc-\d|^gcc-\d|^linux-\d"
)

STORE_DRV = re.compile(r"^\s*(/nix/store/[a-z0-9]{32}-(.+)\.drv)\s*$")


def drv_name(path):
    return os.path.basename(path)[33:].removesuffix(".drv")


def installable(args):
    if "#" in args.target:
        return args.target
    root = os.path.abspath(os.path.expanduser(args.dotfiles))
    return f"path:{root}#nixosConfigurations.{args.target}.config.system.build.toplevel"


def override_flags(args):
    flags = ["--no-write-lock-file"] if args.override_input else []
    for name, ref in args.override_input:
        flags += ["--override-input", name, ref]
    return flags


def run(cmd):
    return subprocess.run(cmd, capture_output=True, text=True)


def parse_dry_run(text):
    builds, fetches, fetch_size, section = [], [], None, None
    for line in text.splitlines():
        if "will be built" in line:
            section = builds
        elif "will be fetched" in line:
            section = fetches
            m = re.search(r"\(([^)]*)\)", line)
            fetch_size = m.group(1) if m else None
        elif line.startswith("  /nix/store/") and section is not None:
            section.append(line.strip())
        else:
            section = None
    return builds, fetches, fetch_size


def cmd_dry_run(args):
    if args.from_log:
        with open(args.from_log) as f:
            text = f.read()
        source, code = args.from_log, 0
    else:
        if not args.target:
            sys.exit("error: <target> or --from-log is required")
        source = installable(args)
        proc = run(["nix", "build", "--dry-run", "--no-link", *override_flags(args), source])
        text, code = proc.stdout + proc.stderr, proc.returncode
        if args.log:
            with open(args.log, "w") as f:
                f.write(text)
    builds, fetches, fetch_size = parse_dry_run(text)
    errors = [l for l in text.splitlines() if l.startswith("error")]
    if code != 0 and not builds and not fetches:
        tail = "\n".join(text.splitlines()[-20:])
        sys.exit(f"error: dry-run failed (exit {code}):\n{tail}")

    heavy_re = re.compile(HEAVY + (f"|{args.heavy}" if args.heavy else ""))
    names = sorted(drv_name(p) for p in builds)
    wiring = [n for n in names if WIRING.match(n)]
    real = [n for n in names if not WIRING.match(n)]
    heavy = [n for n in real if heavy_re.search(n)]
    overrides = ", ".join(f"{n}={r}" for n, r in args.override_input) or "none"
    error_lines = "\n".join(f"  {e}" for e in errors[:5])
    print(f"""source: {source}
overrides: {overrides}
to build: {len(names)} (real {len(real)}, wiring {len(wiring)})
to fetch: {len(fetches)} paths ({fetch_size or 'nothing'})
heavy ({len(heavy)}): {', '.join(heavy) or 'none'}
real builds: {', '.join(real) or 'none'}
wiring builds: {', '.join(wiring) or 'none'}""")
    if errors:
        print(f"errors:\n{error_lines}")
    return 1 if code != 0 else 0


def cmd_dependents(args):
    proc = run(["nix", "eval", "--raw", *override_flags(args), installable(args) + ".drvPath"])
    if proc.returncode != 0:
        sys.exit(f"error: evaluation failed:\n{proc.stderr.strip()}")
    top = proc.stdout.strip()
    closure = {p for p in run(["nix-store", "-qR", top]).stdout.split() if p.endswith(".drv")}
    patterns = [re.compile(r) for r in args.regex]
    matched = sorted(p for p in closure if any(r.search(drv_name(p)) for r in patterns))
    if not matched:
        sys.exit(f"error: no derivation in the closure of {top} matches {args.regex}")

    union = set()
    per_match = []
    for drv in matched:
        proc = run(["nix-store", "-q", "--referrers-closure", drv])
        if proc.returncode != 0:
            sys.exit(f"error: nix-store --referrers-closure {drv} failed:\n{proc.stderr.strip()}")
        deps = {p for p in proc.stdout.split() if p in closure} - set(matched)
        union |= deps
        real_count = sum(1 for p in deps if not WIRING.match(drv_name(p)))
        per_match.append(f"  {drv_name(drv)}: {real_count} real dependents")
    names = sorted({drv_name(p) for p in union})
    real = [n for n in names if not WIRING.match(n)]
    wiring = [n for n in names if WIRING.match(n)]
    per_match_s = "\n".join(per_match)
    real_s = "\n".join(f"  {n}" for n in real) or "  none"
    print(f"""closure: {top}
matched derivations ({len(matched)}):
{per_match_s}
real dependents ({len(real)}):
{real_s}
wiring dependents ({len(wiring)}): {', '.join(wiring) or 'none'}""")
    return 0


def main():
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    sub = parser.add_subparsers(dest="command", required=True)
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument(
        "--dotfiles", default=os.environ.get("DOTFILES", "~/dotfiles"), help="flake directory"
    )
    common.add_argument(
        "--override-input", nargs=2, action="append", default=[], metavar=("NAME", "REF")
    )

    dry = sub.add_parser("dry-run", parents=[common], help="summarize local builds")
    dry.add_argument("target", nargs="?")
    dry.add_argument("--heavy", help="extra regex marking heavy derivation names")
    dry.add_argument("--log", help="write the raw dry-run output to FILE")
    dry.add_argument("--from-log", help="parse an existing dry-run log instead of running nix")
    dry.set_defaults(func=cmd_dry_run)

    dep = sub.add_parser("dependents", parents=[common], help="count closure dependents")
    dep.add_argument("target")
    dep.add_argument("regex", nargs="+", help="regex matched against derivation names")
    dep.set_defaults(func=cmd_dependents)

    args = parser.parse_args()
    sys.exit(args.func(args))


if __name__ == "__main__":
    main()
