# Backend format assessment and operation audit

Reviewed against upstream `main` and the locally packaged source at
`f112f9a805bba48c4b312c132b0b490b4dc92516` on 2026-09-05.

## Screenshot format

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

Keep upstream JPEG for overviews. Decode its bytes once without re-encoding.
Use upstream zoom when text is too small: it crops the uncompressed capture
before applying the same image limits and JPEG encoding. A crop below the
limits avoids overview downsampling. Converting the overview to PNG would not
restore lost detail. PNG or higher quality would require upstream changes;
there is no such option to enable in this wrapper.

## Operation coverage

Sources:

- [Pointer](https://github.com/patrickjaja/wlroots-bridge/blob/f112f9a805bba48c4b312c132b0b490b4dc92516/src/input/pointer.rs)
- [Keyboard](https://github.com/patrickjaja/wlroots-bridge/blob/f112f9a805bba48c4b312c132b0b490b4dc92516/src/input/keyboard.rs)
- [Dispatch](https://github.com/patrickjaja/wlroots-bridge/blob/f112f9a805bba48c4b312c132b0b490b4dc92516/src/main.rs)

| Upstream command | Helper | Observation |
| --- | --- | --- |
| `doctor` | `doctor` | JSON query |
| `screens` | `screens` | JSON query |
| `windows` | `windows` | JSON query |
| `frontmost-app` | `frontmost-app` | JSON query |
| `screenshot` | `screenshot` | Image and mapping metadata |
| `zoom` | `zoom` | Region image and mapping metadata |
| `pointer-move` | `move` | Automatic screenshot |
| `pointer-click` | `click` | Automatic screenshot; all buttons/count/modifiers |
| `pointer-scroll` | `scroll` | Automatic screenshot; both axes |
| `pointer-drag` | `drag` | Automatic screenshot; both endpoints, optionally different captures |
| `left-mouse-down` | `mouse-down` | Automatic screenshot; hold remains active |
| `left-mouse-up` | `mouse-up` | Automatic screenshot attempted even during observation recovery |
| `key-sequence` | `key` | Automatic screenshot; repeat supported |
| `type` | `type` | Automatic screenshot; text/file, character delay |
| `hold-key` | `hold-key` | Automatic screenshot; multiple tokens, duration |
| `activate-window` | `activate-window` | Automatic screenshot |
| `cursor-position` | Not exposed | Upstream always reports unsupported |
| `app-under-point` | Not exposed | Upstream reports unsupported without global window geometry |
| `session-start`, `session-end` | Not exposed | No-op; provide no input exclusivity |

The wrapper also provides a pure `point` conversion command. Backend scroll
arguments are rounded to integer wheel ticks, each emitted as 15 axis units;
the wrapper accepts integer notches rather than implying pixel-smooth scroll.
Upstream drag is left-button-only with fixed interpolation. It does not expose
right-button drag, modifier-drag, separate persistent key-down/key-up, or
persistent right/middle-button holds.

The mouse-down holder inherits its parent's stdout/stderr descriptors. The
wrapper captures backend output with temporary regular files, not pipes that
would wait for the holder to exit. Mouse-up bypasses failed observation
preflight to allow release after a disconnected display or failed screenshot.
