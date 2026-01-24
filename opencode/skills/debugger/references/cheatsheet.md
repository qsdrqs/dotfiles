# Debugger Cheat Sheet (Quick Commands & Knobs)

Use this as a fast lookup *after* you have a reproducer.

## Capture basics

- Capture exit code: `cmd; echo $?`
- Capture output to file: `cmd >output.txt 2>&1; echo $? >exit_code.txt`
- Keep artifacts tidy: `workdir="$(scripts/mk_workdir.sh)"`
- One-liner capture helper: `scripts/capture_cmd.sh -- cmd arg1 arg2`

## Systemd / system logs (Linux)

- Service status: `systemctl status <svc> -l --no-pager`
- Service logs (current boot): `journalctl -u <svc> -b --no-pager -n 200`
- All errors (current boot): `journalctl -b --no-pager -p err..alert`
- Kernel messages: `dmesg -T | tail -n 200`

## Crashes / segfaults / panics

- Get stack traces (language-specific):
  - Rust: `RUST_BACKTRACE=1` (or `full`)
  - Python: `PYTHONFAULTHANDLER=1` or `python -X faulthandler …`
  - Go: `GOTRACEBACK=all`
  - Node: `NODE_OPTIONS="--trace-warnings --unhandled-rejections=strict"`
- Core dumps (if enabled): check `coredumpctl` (systemd-coredump) and analyze with `gdb`/`lldb`

## Tracing

- Syscall trace (Linux): `strace -f -o trace.txt <cmd>`
- Dynamic linker issues: `LD_DEBUG=libs <cmd>` (very noisy; use on small repros)

## Performance regressions

- Baseline: `time <cmd>` (repeat 3–5 times)
- CPU profiling (Linux): `perf top` or `perf record … && perf report` (may require permissions)

## Flaky tests

- Run loop to catch flakes (small repro only): `for i in {1..50}; do <cmd> || break; done`
- Capture seed / randomness knobs (framework-specific) and rerun with fixed seed
