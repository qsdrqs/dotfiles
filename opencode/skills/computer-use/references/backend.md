# Backend format assessment and operation audit

Interface and image-format details are based on upstream revision
`f112f9a805bba48c4b312c132b0b490b4dc92516`. The
[maintained source](https://github.com/qsdrqs/wlroots-bridge) includes the
modifier-state fix at `556113c0d59ca692e29b19cd28771f4763d6fb67`.

## Capture routing

The helper prefers `grim` for full-output and region captures. It writes PNG
directly to a file, with no clipboard operation. Full captures select an output;
regions use global layout coordinates computed from the selected output's
origin. PNG IHDR dimensions and logical region bounds define coordinate mapping.
Do not combine grim's output and geometry flags: some versions replace the
requested region with the entire output when both are present.

`--capture-region` applies this observation path to an action or batch step.
`--capture-backend` can select either capture tool explicitly. Automatic mode
uses bridge JPEG only when grim is absent, not after a failed grim capture.

Sources: [grim manual](https://github.com/emersion/grim/blob/master/grim.1.scd),
[capture and output selection](https://github.com/emersion/grim/blob/master/main.c).

## Bridge JPEG format

Sources:

- [CLI](https://github.com/patrickjaja/wlroots-bridge/blob/f112f9a805bba48c4b312c132b0b490b4dc92516/src/cli.rs)
- [Capture](https://github.com/patrickjaja/wlroots-bridge/blob/f112f9a805bba48c4b312c132b0b490b4dc92516/src/capture.rs)

There is no PNG, quality, or resolution CLI option. Both screenshot and zoom
use `encode_resized_jpeg_base64`, with JPEG quality 75, long edge <= 1568 and
an approximately 1,150,000-pixel budget (dimensions are rounded). Resizing uses
area averaging and does not upscale. The cursor is excluded from captures.
Live full-screen and zoom JPEG headers both had 1 x 1 sampling factors for all
three components (4:4:4), so those outputs did not introduce chroma subsampling.
Both decoded successfully and their encoded dimensions matched the metadata.

Quality 75 is a lossy size/clarity tradeoff, not a guarantee of exact small-text
preservation. The stronger known loss for large desktops is downsampling: the
source formula maps a 3840 x 2160 image to 1430 x 804, retaining approximately
37.24% of the source linear resolution. It is suitable as an overview, not as
a full-resolution text reference. This is a geometry calculation, not an OCR
accuracy benchmark or a quantified JPEG-only loss measurement.

When using bridge captures, decode JPEG bytes once without re-encoding.
Use its zoom when text is too small: it crops the uncompressed capture
before applying the same image limits and JPEG encoding. A crop below the
limits avoids overview downsampling. Converting the overview to PNG would not
restore lost detail. Native PNG in the helper comes from grim, independently
of these upstream JPEG limits.

## Window targeting and clipboard

The unpatched upstream revision sends modifier keycodes without the virtual
keyboard protocol's `modifiers` request. On niri/Smithay, `ctrl+a` and `ctrl+v`
therefore reach applications as plain `a` and `v`; this also affects modifier
holds and modified clicks. Clipboard transfer and capture are independent of
this defect, but shortcut-based paste requires a corrected input backend.
[Upstream PR #1](https://github.com/patrickjaja/wlroots-bridge/pull/1), included
in the maintained source, adds explicit modifier-state updates to the keyboard
and modified-click paths.

Niri IPC provides window IDs, application IDs, titles, workspace membership and
focus. Joining windows to workspaces supplies the output. The helper prefixes
niri IDs with `niri:` and keeps bridge IDs separate. Application/title selectors
resolve a unique target before activation; ambiguous matches return candidates.
Focus-window is followed by focused-window polling, and targeted keyboard
actions verify focus before input. An output association is not window geometry
or an isolated input seat.

Niri's screenshot-window action also writes to the clipboard, so observations
use output/region capture instead. Text writes use `wl-copy --type
text/plain;charset=utf-8` with UTF-8 stdin; reads use `wl-paste --no-newline
--type text`. Neither operation trims the supplied text. A paste action can
combine writing and the application's paste shortcut in one invocation.
Clipboard owners fork, so their output is collected with regular files as for
the bridge's persistent mouse holder.

Sources: [niri IPC](https://niri-wm.github.io/niri/IPC.html),
[niri screenshot implementation](https://github.com/niri-wm/niri/blob/v26.04/src/niri.rs),
[wl-clipboard manual](https://github.com/bugaevc/wl-clipboard/blob/master/data/wl-clipboard.1).

## Operation coverage

Sources:

- [Pointer](https://github.com/patrickjaja/wlroots-bridge/blob/f112f9a805bba48c4b312c132b0b490b4dc92516/src/input/pointer.rs)
- [Keyboard](https://github.com/patrickjaja/wlroots-bridge/blob/f112f9a805bba48c4b312c132b0b490b4dc92516/src/input/keyboard.rs)
- [Dispatch](https://github.com/patrickjaja/wlroots-bridge/blob/f112f9a805bba48c4b312c132b0b490b4dc92516/src/main.rs)

| Upstream command | Helper | Observation |
| --- | --- | --- |
| `doctor` | `doctor` | JSON query |
| `screens` | `screens` | JSON query |
| `windows` | `windows` | Niri query when available; bridge query elsewhere |
| `frontmost-app` | `frontmost-app` | Niri focus query when available; bridge query elsewhere |
| `screenshot` | `screenshot` | Prefers grim PNG; image and mapping metadata |
| `zoom` | `zoom` | Prefers grim PNG; region image and mapping metadata |
| `pointer-move` | `move` | Automatic screenshot |
| `pointer-click` | `click` | Automatic screenshot; all buttons/count/modifiers |
| `pointer-scroll` | `scroll` | Automatic screenshot; both axes |
| `pointer-drag` | `drag` | Automatic screenshot; both endpoints, optionally different captures |
| `left-mouse-down` | `mouse-down` | Automatic screenshot; hold remains active |
| `left-mouse-up` | `mouse-up` | Automatic screenshot attempted even during observation recovery |
| `key-sequence` | `key` | Automatic screenshot; repeat supported |
| `type` | `type` | Automatic screenshot; text/file, character delay |
| `hold-key` | `hold-key` | Automatic screenshot; multiple tokens, duration |
| `activate-window` | `activate-window` | Niri activation/focus confirmation for niri IDs; bridge activation for raw IDs |
| `cursor-position` | Not exposed | Upstream always reports unsupported |
| `app-under-point` | Not exposed | Upstream reports unsupported without global window geometry |
| `session-start`, `session-end` | Not exposed | No-op; provide no input exclusivity |

The wrapper also provides a pure `point` conversion command and a sequential
`batch` command, plus text clipboard read/write and paste. Batch steps use the
same input operations; they capture by
default, with a per-step `screenshot: false` option. Results retain every
requested image path. Execution stops at the first action or requested-capture
failure without replaying earlier steps. Stdin batches combine definition and
execution in one shell call. A batch selector is pinned to its resolved window
ID, while per-step focus and output checks remain live. Normal batch responses
return compact status and capture paths; full mapping data stays in image
metadata rather than being repeated in model context.

Backend scroll
arguments are rounded to integer wheel ticks, each emitted as 15 axis units;
the wrapper accepts integer notches rather than implying pixel-smooth scroll.
Upstream drag is left-button-only with fixed interpolation. It does not expose
right-button drag, modifier-drag, separate persistent key-down/key-up, or
persistent right/middle-button holds.

The mouse-down holder inherits its parent's stdout/stderr descriptors. The
wrapper captures backend output with temporary regular files, not pipes that
would wait for the holder to exit. Mouse-up bypasses failed observation
preflight to allow release after a disconnected display or failed screenshot.
