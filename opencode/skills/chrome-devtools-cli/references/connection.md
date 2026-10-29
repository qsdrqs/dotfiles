# Browser mode and local connection

Read this file before establishing or recovering a browser connection.

## Select a mode

- Attach to the user's running Chromium when working with their existing tabs
  and sign-ins. The attach parameters below target that instance.
- If no browser is running, use a fresh headless browser. For an explicitly
  requested independent browser, or a browser the user needs to see or interact
  with, follow [launch.md](launch.md).
- To reuse an existing profile in an independent browser, follow
  [profile-copy.md](profile-copy.md). This copies the profile; it does not open
  the original profile in a second browser.

Check the current user's Chrome/Chromium browser processes and their profile
arguments, excluding renderer and utility processes with `--type`. A missing
`DevToolsActivePort`, refused connection, or debugging permission failure does
not establish that no browser is running. Investigate those errors instead of
silently switching modes. For a task that requires existing authentication,
select attach or a copied profile rather than substituting a fresh profile.

## Shared parameters

- Initial file workspace: `/tmp/opencode`
- Daemon log: `/tmp/opencode/chrome-devtools.log`

Check daemon status and active work before changing modes. The default CLI daemon
is shared: starting another mode replaces it. Preserve the selected mode and
startup arguments for recovery.

## Attach parameters

- Browser profile: `$HOME/.config/chromium`
- Connection: `--autoConnect --userDataDir="$HOME/.config/chromium"`

Pass these parameters when starting the daemon. For an upload or output outside
the initial workspace, add only the directories needed for the task. Account for
other active tasks before restarting it to change workspace access.

## Attach startup

Use the shell tool, normally in the foreground with a short timeout for status.
Set `CDT` to the skill's `scripts/chrome-devtools` absolute path and export
`CDT_VERSION` with the exact version already resolved for this task in each shell
call. Check the daemon once at task entry, not before every action:

```sh
CDT_TIMEOUT=10s "$CDT" status
```

If it is running, inspect the reported version and arguments and reuse it when
both match this task. A running daemon does not establish that Chrome is
reachable; the first read-only browser call checks that. An unresponsive or
differently configured daemon needs investigation before restart.

If no daemon is running:

```sh
CDT_TIMEOUT=20s "$CDT" start \
  --autoConnect \
  --userDataDir="$HOME/.config/chromium" \
  --workspace=/tmp/opencode \
  --logFile=/tmp/opencode/chrome-devtools.log
```

Browser attachment is lazy: `start` can finish before Chrome has been contacted.
Run the first `list_pages` call in the background with a bounded timeout, and
immediately tell the user to approve the debugging connection in the browser.
If `start` and the first `list_pages` share a shell call, background that call.
Once attached, use short foreground calls for routine browser operations.

Do not issue browser commands without first establishing this connection:
implicit daemon startup does not reuse these arguments after the daemon has
stopped.

Chromium must be running with remote debugging enabled. If attachment fails,
report the error and inspect the daemon log; do not silently launch another mode.

## Recovery

After checking the impact on other tasks, try a bounded stop:

```sh
CDT_TIMEOUT=20s "$CDT" stop
```

An outer timeout may interrupt the CLI's own stop escalation. Recheck the daemon
before starting another one. If it remains alive, verify its PID, command, and
ownership before sending a targeted termination signal. Never use broad process
name matching, and never target the Chromium process.

Restart with the selected mode's startup arguments, list pages, and refresh
snapshots. In launch modes, stopping the daemon closes the browser it launched;
in attach mode, the user's browser stays open.
