---
name: chrome-devtools-cli
description: Automate and inspect browser pages using the official Chrome DevTools CLI. Attach to an existing browser or launch headless, visible, or copied-profile browsers for navigation, forms, screenshots, extraction, and DevTools debugging.
---

# Chrome DevTools CLI

Use [scripts/chrome-devtools](scripts/chrome-devtools) to run the official CLI
through npx. Set `CDT` to that script's absolute path in each shell call. Consult
`"$CDT" <command> --help` for the resolved version's arguments.

## Automatic installation and updates

At the start of each browser task, run the command below to prepare npm's
`latest` release and obtain its exact version. The wrapper uses npx's unattended
download and cache reuse; no global installation is needed. Check that Node.js,
npm, npx, and GNU `timeout` are available, and report missing or incompatible
prerequisites.

```sh
CDT_VERSION= CDT_TIMEOUT=180s "$CDT" --version
```

Use the shell tool's `background: true` if package preparation may take time.
Inspect the completion output and exit status; report registry or package-fetch
failures explicitly. Retain the returned version for the task and export
`CDT_VERSION` with that value in each subsequent shell call. Shell variables do
not persist across calls. Keep the version fixed throughout the task, including
recovery commands. A new task resolves `latest` again.

Read the connection reference. Reuse a daemon only when its version and
connection arguments match. If an older daemon is idle, stop it and start the
resolved version. If another task is active, or its activity is unknown,
coordinate before restarting it; do not interrupt another task to update.

## Connect

Before the first browser operation in a task, or when the daemon has disappeared,
read [references/connection.md](references/connection.md) for mode selection and
local connection parameters. Attach when the user's browser is running. If none
is running, launch a fresh headless browser; use a visible browser when the user
needs to watch or interact. Read [references/launch.md](references/launch.md) for
new browsers and [references/profile-copy.md](references/profile-copy.md) when
an independent browser needs a copy of the user's existing profile. Reuse a
healthy daemon only when its version and mode match; `start` restarts it.

The CLI implicitly starts a default browser when no daemon exists. Establish the
configured connection before invoking browser tools. If it disappears during a
task, reconnect using the reference rather than retrying a tool directly.

## Execute without blocking

Run CLI commands with OpenCode's shell tool. Quick commands can run in the
foreground with a short timeout: this is the default for status, listing pages,
snapshots, ordinary clicks and fills, and ordinary screenshots. Do not background
every browser command.

Use `background: true` for first attachment or launch, profile copying, uncached
package preparation, long navigation or waits, tracing, and scripts with uncertain
duration. When attaching to the user's browser, immediately tell the user to
approve the debugging connection in the browser. Launched browsers do not need
this attach approval. Continue independent work while awaiting the shell
completion notification, then inspect its output and exit status.

The wrapper limits each client call to 30 seconds, sends TERM on timeout, and
sends KILL after another 5 seconds if needed. Override the limit per call with
`CDT_TIMEOUT`, for example `CDT_TIMEOUT=2m "$CDT" <command>`. The same limit
applies in the foreground and background. Keep browser actions sequential when
one depends on the previous result, especially on the same page.

## Inspect and act

1. Use `"$CDT" list_pages` to identify the target page. Preserve unrelated
   tabs and use a new tab for an independent task.
2. Use `"$CDT" take_snapshot <pageId>` to obtain current element UIDs.
3. Pass the page ID explicitly to page-scoped commands. For example:
   `"$CDT" click <pageId> <uid>`. Inspect command help for exceptions such
   as `evaluate_script`, which takes `--pageId`.
4. When Surfingkeys is installed or active, before keyboard or mouse input press
   `Alt+s` and check a fresh snapshot for
   `Surfingkeys turned OFF for <origin>`. If it reports ON, toggle again. If the
   notification is absent, establish the extension state before entering data.
   Skip this step for a fresh profile without Surfingkeys.
5. Inspect the result before the next dependent action. Refresh snapshots after
   navigation or substantial page changes.

CLI command availability differs from MCP: `wait_for` and `fill_form` are not
generated. Use `fill` for individual fields. For waiting, check the required page
condition through bounded snapshot or evaluation calls rather than assuming a
missing command exists.

## Read results

Read the task's terminal status, exit code, and output. A successful CLI exit is
not sufficient: tool errors can be returned as result text. Use
`--output-format=json` when useful, and inspect its actual result shape rather
than assuming every command returns the same envelope.

Save screenshots with `"$CDT" take_screenshot <pageId> --filePath <absolute-path>`, then
open the resulting image with the image-capable read tool. Read large text
artifacts from files rather than returning unbounded logs to the conversation.

## Cancel and recover

- When cancellation is needed, identify the client process for the specific
  shell command before terminating it. Client termination or timeout does not
  prove that the daemon's browser operation was cancelled.
- Treat the browser outcome as unknown until page state establishes it. Inspect
  the result before retrying a click, submission, upload, or other mutation.
- If calls remain stuck, read the connection reference and check daemon status
  with a bounded shell call. Check whether other tasks use the daemon before
  stopping it; do not interrupt their work without approval.
- Stop and restart the daemon only when recovery or a mode change is needed.
  Stopping an attached daemon disconnects from the user's browser; stopping a
  launch-mode daemon closes its browser. Preserve any needed artifacts first.
  Do not close or restart the user's browser as a recovery shortcut.
- After reconnecting, list pages and obtain fresh snapshots before acting. Old
  page IDs and element UIDs may no longer be valid.

Official reference: https://github.com/ChromeDevTools/chrome-devtools-mcp/blob/main/docs/cli.md
