---
name: computer-use
description: Operate desktop applications visually using screenshots, mouse, and keyboard through wlroots-bridge. Use for tasks that require interacting with the current desktop GUI; check backend availability and Wayland capabilities before operating.
---

# Computer Use

Use `wlroots-bridge` for input, `grim` for PNG captures when installed, niri IPC
for window targeting on niri, and `wl-copy`/`wl-paste` for text clipboard access.
The helper requires Python 3 with only its standard library.
Set `HELPER` to `scripts/desktop.py` resolved relative to this skill's base
directory; do not assume a username, repository location, compositor, or screen ID.

## Start with one checked observation

Minimize model round trips: combine discovery, activation, and observation in
one helper invocation, then batch predictable input. Keep device and focus
checks inside the helper rather than requesting a model decision for each one.

On niri, use the application/title from the task directly:

```bash
python3 "$HELPER" activate-window --app-id "$APP_ID" --title "$TITLE_MATCH"
```

Either filter can be used alone; both are case-insensitive substrings and are
combined when supplied together. This call checks `wlroots-bridge` availability
first, runs `doctor`, resolves the target and its output, checks required
capabilities/tools, activates the unique match, waits for focus, and captures.
Missing requirements stop the operation; report them without installing tools
or changing permissions. `doctor` is available for explicit diagnostics.

- Reuse the task's selected window. Otherwise match the task's application or
  title. A unique match is automatic; an ambiguous match returns candidates
  with titles and outputs. Ask the user to choose, then use `--window niri:ID`.
  Do not choose the task target from current desktop focus.
- `windows --app-id ... --title ...` lists candidates when discovery is needed.
  Niri IDs use the `niri:` prefix; raw IDs from the bridge are a different namespace.
- With no window target, the helper discovers screens: select the sole output
  automatically, or use the task's `--display` on a multi-output setup. Ask if
  the intended output cannot be determined. Never persist a screen ID as a
  cross-device default. Bridge `is_primary` and `is_active` are position-based
  heuristics; do not use them to select focus or filter enabled screens.
- Treat the target output as the task's working area. Mouse and keyboard still
  share the desktop seat; interacting on another output can change focus.
- On other compositors, use the bridge's window discovery/activation and the
  screen-based workflow. Niri target filters require a running niri IPC socket.

## Screenshot and action loop

In the examples, set `HELPER` to the resolved `scripts/desktop.py` path and
`DISPLAY_ID` to a discovered ID when selecting an output explicitly. Variables
are shell-local; pass their actual values again if a later call uses a new shell.

```bash
python3 "$HELPER" screenshot --display "$DISPLAY_ID"
```

This prints JSON containing an absolute `image` path and a `metadata` path.
Open the image with the image-reading tool before choosing an action. Never
print the upstream base64 payload into the conversation. Each capture gets a
unique directory under `/tmp/opencode` if available, otherwise `/tmp`.
`--output-dir` selects an existing parent directory on any capture or action.

Click using coordinates in that exact saved image:

```bash
python3 "$HELPER" click --metadata "$METADATA" --x 420 --y 260
```

Standalone input actions automatically wait and capture the selected screen.
For a predictable sequence, use `batch` to avoid a model/tool round trip for
each action. Batch steps also capture by default, with per-step opt-out.
Read the final or otherwise relevant returned images before deciding what to
do next; reading every intermediate image is unnecessary for a planned batch.
A path in JSON does not itself show the image to the model.

`--wait-ms` controls the post-action delay (default `300`). It is a settle delay,
not a guarantee that an application has finished loading. If the screenshot is
transitional, take another screenshot without replaying the action.

Action output distinguishes execution from observation:

```json
{
  "action": "click",
  "actionSucceeded": true,
  "actionStatus": "succeeded",
  "screenshotRequested": true,
  "screenshotSucceeded": true,
  "image": "/tmp/opencode/computer-use-.../screenshot.png",
  "metadata": "/tmp/opencode/computer-use-.../screenshot.json"
}
```

- If input succeeded but capture failed, `actionSucceeded` stays `true` and
  `screenshotError` explains the failure. Recover observation, not the input.
- A backend error or timeout during input reports `actionSucceeded: null` and
  `actionStatus: "unknown"`: some input may have occurred. The helper attempts
  a screenshot if requested but never retries the action. Inspect before deciding
  what to do.
- Preflight failures report `actionStatus: "not-started"`. Actual actions check
  required protocols, screen selection, referenced geometry, and the output
  directory (when capturing) before sending input. `mouse-up` still attempts release when these
  observation checks fail, then reports the screenshot outcome separately.
- `--dry-run` builds the command only: no backend call, input, wait, or capture.
  Unresolved selectors remain placeholders. Use it when command inspection is
  needed, rather than as a routine extra model turn before every action.

Observation output selection is: explicit `--display`, selected niri window's
current output, metadata's output, then the sole output. Targeted captures save
`windowId` in their metadata, so subsequent actions can inherit that target.
Explicit window selectors override the metadata's target. Coordinate actions
require `--metadata`; an output change invalidates old target coordinates.
`--display` can select another post-action output, such as a drag destination.

### Batch operations

Prefer one batch for known actions such as click a visible field, select all,
type, and submit. Stop a batch at a decision that needs new visual information,
such as identifying a search result that has not appeared yet. A fixed-position
button already located in the current view can be clicked within the batch.

Send a batch through stdin in the same shell call that defines it. Each step
has an `action` from the command table, `args` containing that command's CLI
argument strings, and optional boolean `screenshot` (default `true`):

```bash
python3 "$HELPER" batch --file - --metadata "$METADATA" <<'JSON'
[
  {"action": "click", "args": ["--x", "420", "--y", "260"], "screenshot": false},
  {"action": "key", "args": ["--keys", "ctrl+a"], "screenshot": false},
  {"action": "paste", "args": ["--text", "Example query"], "screenshot": false},
  {"action": "key", "args": ["--keys", "Return", "--wait-ms", "700"], "screenshot": true}
]
JSON
```

`--file FILE` also accepts an existing JSON file. `paste --text` combines
clipboard writing and the paste shortcut; a separate clipboard-write call is
unnecessary unless the workflow needs an observation between those operations.
An `activate-window` step can precede known keyboard navigation in the same
batch. End the batch before choosing controls that require a fresh screenshot.

- Omit `screenshot` to save an image after each step. Setting it to `false`
  skips capture and file creation for that step, but retains the action result
  and post-action wait. There is no forced final screenshot; normally request
  one at the end so the result can be inspected.
- Target selectors, `--display`, `--metadata`, `--output-dir`, `--wait-ms`,
  `--timeout`, `--capture-backend`, and `--capture-region` on the batch provide
  defaults. A step's `args` may override them. A step's explicit target replaces
  the batch target selectors. The batch pins its unique match to the window ID
  for later steps, even if typing changes the title. Relative
  paths resolve from the shell working directory; absolute paths are clearer.
- Metadata is not automatically replaced by each intermediate capture. Supply
  the reference image whose coordinates the planned actions use. If UI changes
  make later coordinates uncertain, end the batch and inspect first.
- Steps run sequentially in one helper invocation. File structure and CLI
  arguments are parsed before execution; each step retains its normal device
  and geometry checks. Use `batch --dry-run` to preview all action commands.
- The response contains ordered `steps`, each with its execution status and
  image/metadata paths when requested. `screenshotRequested: false` distinguishes
  a skipped capture from a failure. All returned captures remain available;
  choose the relevant ones to read rather than inserting a model turn per step.
  Normal batch output omits repeated backend commands and full geometry; mapping
  details remain in each metadata file. Dry-run output includes command previews.
- Input failure, unknown outcome, or a requested screenshot failure stops the
  batch. `stoppedAt` is the one-based failing step; later steps are not executed.
  Inspect the returned steps and do not blindly replay the batch. If a stopped
  batch left a `mouse-down` active, issue `mouse-up` to release it.

### Coordinates

The helper calculates each global logical coordinate from the screenshot:

```text
global_x = originX + round(image_x * displayWidth / width)
global_y = originY + round(image_y * displayHeight / height)
```

Coordinates must refer to the saved image's declared dimensions, not a resized
preview or an unrelated crop. The helper bounds rounded results to the selected
captured region. It does not use the reported screen `scale` as a conversion
factor. Full-screen and zoom metadata both work for pointer actions; zoom
metadata retains the full screen geometry separately for layout checks.

For a conversion without an input action or screenshot, use:

```bash
python3 "$HELPER" point --metadata "$METADATA" --x 420 --y 260
```

### Mouse and keyboard commands

Use the helper for input operations and their configured observation steps.
Run `python3 "$HELPER" <command> --help` for the complete flags.

| Helper command | Operation / important flags |
| --- | --- |
| `move` | Move to image `--x`, `--y` using `--metadata` |
| `click` | Same coordinates; `--button left/right/middle`, `--count 2` for double-click, repeatable `--modifier ctrl` / `--modifier shift` |
| `scroll` | At the image point; integer `--dx`, `--dy` in wheel notches, positive right/down |
| `drag` | Left-button drag from `--from-x`, `--from-y` to `--to-x`, `--to-y`; optional `--to-metadata` for a destination capture on another screen |
| `mouse-down` | Hold the left button at the current pointer position |
| `mouse-up` | Release the held left button |
| `type` | `--text` or UTF-8 `--text-file`; `--delay-ms` between characters |
| `clipboard-read` | Return clipboard text as JSON, preserving trailing newlines; no screenshot |
| `clipboard-write` | Write `--text` or UTF-8 `--text-file` to the system clipboard, then observe |
| `paste` | Paste existing clipboard text, or write `--text` / `--text-file` and paste; `--keys` defaults to `ctrl+v` |
| `key` | Single key or chord in `--keys`, optional `--repeat` |
| `hold-key` | Repeatable `--key` tokens, required `--duration-ms`; releases at the end |
| `activate-window` | Resolve `--app-id` / `--title` or use `--window`; activate, wait for niri focus, then capture |

Examples (all coordinate values refer to the supplied metadata):

```bash
python3 "$HELPER" scroll --metadata "$METADATA" --x 420 --y 260 --dy 3
python3 "$HELPER" drag --metadata "$METADATA" --from-x 420 --from-y 260 --to-x 680 --to-y 400
python3 "$HELPER" click --metadata "$METADATA" --x 420 --y 260 --modifier ctrl
```

For a staged hold, move first, use `mouse-down`, then `move`, then `mouse-up`.
Always release a hold you started, including after an observation failure.
Prefer the single `drag` command for a simple drag. The backend only offers
persistent hold/release for the left button; drag duration and interpolation
are fixed upstream, and modifier-drag/right-button drag are not exposed.

Use the selected niri target for keyboard input. The helper checks its focus
before typing, chords, holds, and paste. A focus mismatch stops before input;
activate the target and inspect the new view before continuing. Focus checking
and activation polling happen inside the helper:

```bash
python3 "$HELPER" paste --window "$WINDOW_ID" --text-file "$TEXT_FILE"
python3 "$HELPER" type --window "$WINDOW_ID" --text 'Example text' --delay-ms 35
python3 "$HELPER" key --window "$WINDOW_ID" --keys ctrl+a
python3 "$HELPER" hold-key --window "$WINDOW_ID" --key shift --key Right --duration-ms 500
```

`--display` chooses observation only; it does not redirect typing or focus a
window. Untargeted input uses live desktop focus. `type` sends key events;
`paste` is preferable for long, multilingual, or multiline text. Clipboard writes
replace the system text clipboard explicitly. Paste shortcuts depend on the
application; terminals often need `--keys ctrl+shift+v`. For values
beginning with a hyphen, use `--text='-example'`. Long typing/hold/repeat requests
receive a duration-aware timeout; `--timeout` explicitly overrides it in seconds.

### PNG and region observation

Captures prefer `grim`, writing PNG files directly without touching the
clipboard. Keep its output dimensions and use the metadata for coordinates;
the helper reads the PNG dimensions rather than guessing them from screen scale.
For small text or a focused observation, capture a fresh region:

```bash
python3 "$HELPER" zoom --display "$DISPLAY_ID" --x 200 --y 150 --w 800 --h 400
```

Unlike pointer coordinates, zoom arguments are **screen-local logical pixels**.
Actions and batches accept `--capture-region X Y W H` in the same units; use
this when the region is already known to combine input and its local observation
in one call. Each region comes from a fresh capture, not an enlarged overview.
Read its image and use its own metadata for subsequent coordinates.

`--capture-backend auto` selects installed `grim`, otherwise the existing bridge
JPEG path. `grim` and `wlroots-bridge` can also be selected explicitly. A capture
failure is reported without switching backends. Bridge JPEG has fixed quality
and downscaling limits; conversion to PNG would not restore lost detail. See
[backend.md](references/backend.md) for the format assessment and command audit.

`doctor`, `screens`, `windows`, `frontmost-app`, and `clipboard-read` are read-only helper commands
that return JSON without a screenshot. Refresh discovery after monitor/layout
changes. Report task completion based on visible results, not exit status.

## Backend limitations

- The unpatched bridge loses keyboard modifiers on niri/Smithay: `ctrl+a` and
  `ctrl+v` can type plain `a` and `v`. Chords, modified clicks, and `paste`
  require the modifier-state fix described in [backend.md](references/backend.md).
  A successful backend exit does not establish that the application performed
  the shortcut.
- Portability means discovering capabilities on each device, not assuming that
  every Wayland compositor implements these protocols. Working `doctor` output
  still needs a screenshot and a task-scoped interaction check on a new setup.
- The bridge's JPEG capture can misreport scale on rotated outputs and does
  not reliably handle output transforms. Grim handles capture transforms, while
  pointer input still uses the bridge. Inspect orientation
  and geometry before using coordinates; if they disagree, stop and report the
  mismatch rather than guessing a rotation correction.
- The initially tested pointer implementation clamps negative global
  coordinates and assumes an output layout rooted at zero. If discovered
  screens have negative origins, report this limitation before pointer actions;
  the helper's mathematical conversion does not fix the backend's mapping.
- `session-start` is a no-op on this backend, not exclusive input ownership.
  Keyboard and mouse actions share the user's live desktop.
- Window IDs must come from recent discovery or selector resolution. The helper
  associates niri windows with outputs; use screenshots to locate controls,
  rather than treating that association as window-local coordinates. Global
  cursor queries and app-under-point queries are unsupported upstream.

Backend: https://github.com/qsdrqs/wlroots-bridge
