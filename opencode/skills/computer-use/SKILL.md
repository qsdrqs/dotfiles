---
name: computer-use
description: Operate desktop applications visually using screenshots, mouse, and keyboard through wlroots-bridge. Use for tasks that require interacting with the current desktop GUI; check backend availability and Wayland capabilities before operating.
---

# Computer Use

Use the installed `wlroots-bridge` CLI and the shell/image-reading tools.
The helper requires Python 3 with only its standard library.
Resolve `scripts/desktop.py` relative to this skill's base directory; do not
assume a particular username, repository location, compositor, or screen ID.

## Check the current device first

1. Run `command -v wlroots-bridge`. If unavailable, report the missing package
   and stop. Do not install it automatically.
2. Run `wlroots-bridge doctor`. Confirm connection to the current Wayland
   session. Check `globals.screencopy` for screenshots, `virtual_pointer` for
   mouse actions, and `virtual_keyboard` for keyboard input. A successful exit
   alone does not establish that every capability is present. If a required
   capability is absent, report the result and stop that operation.
3. Run `wlroots-bridge screens` to discover current IDs and logical geometry.
   With one screen, use it. With multiple screens, select the user's target;
   ask if the intended screen cannot be determined. Never persist a connector
   ID as a cross-device default. Upstream `is_primary` and `is_active` are
   position-based heuristics, not reliable indicators of focus or whether a
   screen is enabled. Do not filter out screens by `is_active`.

## Screenshot and action loop

In the examples, set `HELPER` to the resolved `scripts/desktop.py` path and
`DISPLAY_ID` to an ID discovered above. Variables are shell-local; pass their
actual values again if a later tool call uses a new shell.

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
python3 "$HELPER" click --metadata "$METADATA" --x 420 --y 260 --dry-run
python3 "$HELPER" click --metadata "$METADATA" --x 420 --y 260
```

Every actual input action, including keyboard, move, scroll, drag, mouse
down/up, and window activation, automatically waits and captures the selected
screen. **Read the returned `image` after every action before choosing the next
action.** A path in JSON does not itself show the image to the model.

`--wait-ms` controls the post-action delay (default `300`). It is a settle delay,
not a guarantee that an application has finished loading. If the screenshot is
transitional, take another screenshot without replaying the action.

Action output distinguishes execution from observation:

```json
{
  "action": "click",
  "actionSucceeded": true,
  "actionStatus": "succeeded",
  "screenshotSucceeded": true,
  "image": "/tmp/opencode/computer-use-.../screenshot.jpg",
  "metadata": "/tmp/opencode/computer-use-.../screenshot.json"
}
```

- If input succeeded but capture failed, `actionSucceeded` stays `true` and
  `screenshotError` explains the failure. Recover observation, not the input.
- A backend error or timeout during input reports `actionSucceeded: null` and
  `actionStatus: "unknown"`: some input may have occurred. The helper attempts
  a screenshot but never retries the action. Inspect before deciding what to do.
- Preflight failures report `actionStatus: "not-started"`. Actual actions check
  required protocols, screen selection, referenced geometry, and the output
  directory before sending input. `mouse-up` still attempts release when these
  observation checks fail, then reports the screenshot outcome separately.
- `--dry-run` builds the command only: no backend call, input, wait, or capture.
  It does not establish current device readiness.

For keyboard and mouse down/up, select the observation display with `--display`
or infer it from `--metadata`. On a single-screen setup neither is required.
For coordinate actions, `--metadata` is required. The default observation
display is that capture's screen; an explicit `--display` can select a different
post-action screen, for example the destination of a cross-screen drag.

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

Use the helper for input operations so their observation step is not skipped.
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
| `key` | Single key or chord in `--keys`, optional `--repeat` |
| `hold-key` | Repeatable `--key` tokens, required `--duration-ms`; releases at the end |
| `activate-window` | Activate the current `--window` ID, then capture |

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

Keyboard input uses the current desktop focus, not the selected screenshot
display. Establish the intended focus before typing:

```bash
python3 "$HELPER" type --display "$DISPLAY_ID" --text 'Example text' --delay-ms 35
python3 "$HELPER" key --display "$DISPLAY_ID" --keys escape
python3 "$HELPER" key --display "$DISPLAY_ID" --keys ctrl+a
python3 "$HELPER" hold-key --display "$DISPLAY_ID" --key shift --key Right --duration-ms 500
```

`--display` chooses observation only; it does not redirect typing or focus a
window. Text is sent as key events, not pasted through a clipboard. For values
beginning with a hyphen, use `--text='-example'`. Long typing/hold/repeat requests
receive a duration-aware timeout; `--timeout` explicitly overrides it in seconds.

### Small text and zoom

Upstream exposes JPEG only, at quality `75`, with a `1568`-pixel long-edge cap
and a `1,150,000`-pixel budget. Treat a full-screen image as an overview. Small
text on high-resolution displays can lose detail mainly during downscaling;
do not infer unreadable text from context. Capture a region instead:

```bash
python3 "$HELPER" zoom --display "$DISPLAY_ID" --x 200 --y 150 --w 800 --h 400
```

Unlike pointer coordinates, zoom arguments are **screen-local logical pixels**.
The backend crops the fresh raw capture before resizing/JPEG encoding, rather
than enlarging an already compressed overview. Read the returned image and use
its own metadata for subsequent coordinates. Keep JPEG without another lossy
encode or a misleading JPEG-to-PNG conversion. See
[backend.md](references/backend.md) for the format assessment and command audit.

`doctor`, `screens`, `windows`, and `frontmost-app` are read-only helper commands
that return JSON without a screenshot. Refresh discovery after monitor/layout
changes. Report task completion based on visible results, not exit status.

## Backend limitations

- Portability means discovering capabilities on each device, not assuming that
  every Wayland compositor implements these protocols. Working `doctor` output
  still needs a screenshot and a task-scoped interaction check on a new setup.
- The initially tested upstream implementation can misreport scale on rotated
  outputs and does not reliably handle output transforms. Inspect orientation
  and geometry before using coordinates; if they disagree, stop and report the
  mismatch rather than guessing a rotation correction.
- The initially tested pointer implementation clamps negative global
  coordinates and assumes an output layout rooted at zero. If discovered
  screens have negative origins, report this limitation before pointer actions;
  the helper's mathematical conversion does not fix the backend's mapping.
- `session-start` is a no-op on this backend, not exclusive input ownership.
  Keyboard and mouse actions share the user's live desktop.
- Window IDs must come from a recent `windows` call. Window geometry is not
  supplied by these protocols, so use screenshots to locate controls. Global
  cursor queries and app-under-point queries are unsupported upstream.

Backend: https://github.com/patrickjaja/wlroots-bridge
