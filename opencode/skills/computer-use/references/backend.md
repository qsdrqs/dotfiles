# Backend format assessment and operation audit

Interface and image-format details are based on upstream revision
`f112f9a805bba48c4b312c132b0b490b4dc92516`. The
[maintained source](https://github.com/qsdrqs/wlroots-bridge) includes the
modifier-state fix at `556113c0d59ca692e29b19cd28771f4763d6fb67`.

## Pointer coordinate mapping

Absolute pointer motion uses the union of the logical output rectangles:
subtract its minimum x/y from global coordinates and use its width/height as
the protocol extents. This supports outputs left of or above the global origin,
as well as layouts whose minimum coordinates are positive. Using only the
right/bottom edges and clamping global coordinates to zero misplaces the pointer.

Corrected bridges advertise `pointer_logical_bounds: true` in `doctor`.
The helper requires this capability when either desktop bounding-box origin is
nonzero; older bridges remain usable with zero-origin layouts. Input coordinates
remain global logical coordinates, including negative values.

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

## Agent desktop isolation

### Process model and lifecycle

The agent desktop is a second niri 26.04 instance built with the upstream
PR #3800 headless/virtual-output patch and started with
`NIRI_BACKEND=headless`. It has one output, `HEADLESS-1`, 1920x1080 at 60 Hz
(the backend default), and no physical display.

`systemd-run --user --collect --unit=computer-use-agent` creates the transient
`computer-use-agent.service` with `TimeoutStopSec=10`, HOME as the working
directory, and stdout/stderr appended to
`$XDG_RUNTIME_DIR/computer-use-agent/session.log`. Its command is
`dbus-run-session --config-file=<runtime>/bus.conf -- niri -c <runtime>/niri.kdl`,
so the private bus daemon and the compositor share the unit. Applications are
spawned through the agent compositor's `niri msg action spawn`; they inherit its
Wayland, D-Bus and xwayland-satellite `DISPLAY` endpoints and stay in the unit's
cgroup, so `stop` (`systemctl --user stop`: SIGTERM, SIGKILL after 10 s, then
`reset-failed`) ends all of them before the runtime and cache directories are
deleted. A left-button holder left by `mouse-down` runs outside the unit; `stop`
terminates it first so it releases the button while the compositor still runs.
If the unit is still active afterwards, `stop` fails and keeps the files.
`spawn`, `chrome` and `vnc` refuse to run when the secrets bridge does not own
its name. Recorded end-to-end times: `start` 0.65 s, `stop` 0.4 s.

`start` on an active unit returns its status with `alreadyRunning: true`.
Otherwise it stops remnants, recreates the runtime directory with mode 0700,
records the caller's bus address in `main-bus`, writes `bus.conf` and
`niri.kdl`, copies the Chrome profile, and launches the unit. It then waits up
to 30 s for `agent.env` to contain `WAYLAND_DISPLAY`, `NIRI_SOCKET` and
`DBUS_SESSION_BUS_ADDRESS` (failing with the log tail if the unit exits), runs
the input-device check below, and waits up to 15 s for `org.freedesktop.secrets`
to be owned on the private bus. A failed input-device check stops the unit; a
readiness or bridge timeout reports the failure and leaves the unit running for
inspection.

The generated config sets `hotkey-overlay { skip-at-startup }`,
`prefer-no-csd`, `screenshot-path null` and an empty `binds {}`, so no key
combination the helper sends is intercepted by the compositor. Two
`spawn-at-startup` children run: one writes `env -0` to `agent.env.tmp` and
renames it to `agent.env`, which is both the readiness signal and the endpoint
record; the other starts the secrets bridge through a shell redirection to
`secrets-bridge.log`, because niri gives spawned children a null stdio. The
runtime directory holds `bus`, `bus.conf`, `niri.kdl`, `agent.env`,
`main-bus`, `session.log` and `secrets-bridge.log`, plus `vnc`, `wayvncctl`
and `wayvnc.log` once VNC is started.

### Environment

The unit receives the caller's environment through per-unit `--setenv`
arguments, minus the variables that would connect agent processes to the main
session or describe its login session: Wayland and X11 sockets and
authentication, the D-Bus session address, PID and window ID, niri, Sway, i3
and Hyprland IPC sockets, XDG session, seat, VT and activation variables,
`DESKTOP_STARTUP_ID`, `SESSION_MANAGER`, systemd notification, invocation,
journal and socket-activation variables, `WINDOWID`, `GPG_TTY`, `SSH_TTY`,
`SSH_CONNECTION`, `SSH_CLIENT` (a caller logged in over SSH would otherwise
make every agent shell behave as an SSH login), `TMUX`, `TMUX_PANE`, `STY` and
everything prefixed `KITTY_`. Values containing
a newline are omitted and their names reported as `droppedEnvironment`. Added:
`XDG_SEAT=seat-agent`, `NIRI_BACKEND=headless`, `XDG_SESSION_TYPE=wayland`
and `XDG_CURRENT_DESKTOP=niri`.

A user service also inherits the systemd user manager's environment, into
which the main compositor exports its own `WAYLAND_DISPLAY`, `NIRI_SOCKET`
and `DISPLAY`. The unit therefore gets `UnsetEnvironment=` for every blocked
name that is not set explicitly; systemd applies it after `--setenv`, so the
explicit values such as `XDG_SEAT` must never appear in it. The manager
environment itself is not modified. HOME, PATH, `SSH_AUTH_SOCK`,
`XDG_RUNTIME_DIR` and everything else pass through, so applications see the
user's real configuration, agents and credentials. Shared HOME, runtime
directory and UID make this operational isolation, not a sandbox.

### Input isolation

The headless backend still initializes libinput and assigns the udev seat
named by `XDG_SEAT`, default `seat0`. A user in the `input` group would thus
have the agent compositor reading the physical keyboard and mouse, with the
user's keystrokes landing in the agent desktop. `XDG_SEAT=seat-agent` names a
seat with no devices, leaving `zwlr_virtual_pointer_v1` and
`zwp_virtual_keyboard_v1` clients (wlroots-bridge and wayvnc) as the only
input sources.

`start` locates the niri process in the unit's cgroup and lists its open file
descriptors under `/dev/input/`. If the process cannot be found, the
descriptors cannot be read, or any device is open, it stops the unit and
fails. `status` reports the same list as `inputDevices`; it was empty in
testing. This is a check at startup, not a continuous guard.

A virtual output inside the user's niri would not be a substitute: niri has a
single seat, so an extra output would still share keyboard focus, cursor and
popup grab with the user; Wayland surfaces belong to a client connection and
cannot be moved between compositors; and Chromium/Electron bind only the first
`wl_seat` they see, so even a multi-seat compositor could not drive the user's
running Chrome from a second seat. The separate compositor gives agent clients
their own focus, cursor, clipboard and layout; it does not isolate what
applications do outside the compositor (see the limitations below).

### Private session bus

`bus.conf` declares a session bus listening on
`unix:path=$XDG_RUNTIME_DIR/computer-use-agent/bus` with `keep_umask`,
EXTERNAL authentication and a default policy that allows send, own and
eavesdrop. It has no service directory, so nothing is activated. The portal
(file chooser, screencast), notification daemon, status-notifier tray, dconf
and the single-instance handoff of many applications are all reached through
well-known names on the session bus; on the private bus those names are
unowned, so agent dialogs, notifications and launches cannot surface on the
user's desktop. Consequently applications fall back to built-in dialogs
(Chrome 154 uses its GTK file chooser), notifications are dropped, there is no
tray, and GSettings/dconf writes are not persisted. `org.freedesktop.secrets`
is the only bridged name.

### Secrets bridge

`agent_desktop.py secrets-bridge` is started by niri at startup and uses only
the Python standard library. It opens unix sockets to the private bus and to
the main bus (address read from `main-bus`), authenticates with SASL EXTERNAL
using the hex-encoded uid, sends Hello, and calls RequestName for
`org.freedesktop.secrets` on the private bus with DBUS_NAME_FLAG_DO_NOT_QUEUE
(4), requiring the primary-owner result (1).

Every method call delivered to it on the private bus is re-sent on the main
bus with DESTINATION rewritten to `org.freedesktop.secrets`; the private
sender and serial are remembered under the main-bus serial unless
NO_REPLY_EXPECTED is set. METHOD_RETURN and ERROR messages from the main bus
are matched by REPLY_SERIAL and re-sent on the private bus with DESTINATION
and REPLY_SERIAL rewritten. Bodies are copied verbatim with their original
endianness; only header fields change, and SENDER is always dropped because
the daemon sets it. The match rule
`type='signal',sender='org.freedesktop.secrets'` on the main bus feeds
signals that are re-broadcast on the private bus without DESTINATION, so
`Prompt.Completed`, `ItemChanged`, collection signals and `PropertiesChanged`
reach agent clients, whose proxies resolve the well-known name to the bridge's
unique name. Signals from `org.freedesktop.DBus` are not forwarded, and unix
fd passing is not negotiated; the Secret Service API does not use fds.

The keyring daemon sees exactly one client, the bridge. With KeePassXC as the
provider, every secret read shows a KeePassXC notification on the user's
desktop and a locked database shows its unlock prompt there. Verified:
`secret-tool lookup` run inside the agent desktop returned the 24-byte Chrome
"Safe Storage" key through the bridge; `secrets-bridge.log` records the owned
name and both unique names.

### Chrome profile copy

At `start`, `$XDG_CONFIG_HOME/google-chrome` (default
`~/.config/google-chrome`) is copied with `cp -a --reflink=auto` into a
staging directory and renamed to
`${XDG_CACHE_HOME:-~/.cache}/computer-use-agent/google-chrome`. On btrfs a
2.3 GiB profile copied in about 0.3 s, and only blocks modified later consume
space. The copy drops `Singleton*` (the running instance's lock, socket and
cookie symlinks), `DevToolsActivePort` and every `*/Sessions` directory, so
the user's open tabs are not restored; `exit_type` in Preferences is left
untouched. No "Restore pages?" bubble appeared in testing. A missing source
profile is reported as `chromeProfile: null`, and `chrome` then fails.

`chrome` runs `google-chrome-stable --user-data-dir=<copy>
--password-store=gnome-libsecret --no-first-run --no-default-browser-check
--disable-sync`, plus `--mute-audio` unless `--audio` is given, followed by
any arguments after `--`. The copy has its own singleton socket, so later
`chrome -- URL` calls reach the agent's Chrome rather than the user's.
Cookies and passwords decrypt because the "Chrome Safe Storage" key comes
from the user's keyring through the bridge; a GitHub session was verified
logged in. `stop` deletes the copy, so nothing done in the agent Chrome
reaches the user's profile, although its external effects (sent messages,
downloads) remain.

`Ctrl+Shift+Q` does not quit Chrome: `chrome/browser/ui/accelerator_table.cc`
at tag 154.0.8037.92 has no VKEY_Q or IDC_EXIT entry (the shortcut was removed
in Chrome 70). Keyboard input itself was verified to reach Chrome (Ctrl+L,
typing and Return), and `Alt+F` followed by `x` quits.

### VNC

`vnc` spawns `wayvnc --config=/dev/null --unix-socket
--socket=<runtime>/wayvncctl <runtime>/vnc` inside the agent desktop with
output in `wayvnc.log`. `--config=/dev/null` keeps wayvnc from loading the
user's `~/.config/wayvnc/config`, whose authentication and TLS settings would
make wlvncc fail to connect; access is limited by the `0700` runtime
directory instead of VNC authentication. It
captures the agent compositor over wlr-screencopy and injects input through
the same virtual keyboard and pointer protocols into the same single seat as
the helper. No TCP port is opened. Readiness is detected by connecting to the
socket and reading the `RFB ` banner (`RFB 003.008` observed); the command
prints `viewer: wlvncc <socket>`, and wlvncc accepts a unix socket path as its
address. Versions: wayvnc 0.10.2, wlvncc 0-unstable-2026-04-29.
Sunshine/Moonlight were rejected because Sunshine injects input through
`/dev/uinput`, which lands on seat0, the user's compositor.

### Helper targeting

`desktop.py --target agent` (the default) reads `agent.env`, requires
`WAYLAND_DISPLAY` and `NIRI_SOCKET`, probes the niri IPC socket, removes
`WAYLAND_SOCKET` from the environment and sets `WAYLAND_DISPLAY` and
`NIRI_SOCKET`, so wlroots-bridge, grim, `niri msg`, wl-copy and wl-paste all
address the agent desktop. It also sets `CLAUDE_PROFILE`, which wlroots-bridge
uses to name its left-button holder pidfile, so a held button in one desktop
is never released by `mouse-up` in the other. `--target main` keeps the
caller's session variables; when the caller has neither `WAYLAND_DISPLAY` nor
`WAYLAND_SOCKET` (for example over SSH), it imports `WAYLAND_DISPLAY`,
`NIRI_SOCKET` and `DISPLAY` from `systemctl --user show-environment`, where
the compositor exports its session. There is no fallback between the two
targets; a missing or unreachable agent desktop is an error.
`point` and `--dry-run` do not touch the target, and `doctor` reports
`target`.

### Shared resources and limitations

Chromium and Electron applications (Slack, Element, Codex, ...) use a
singleton lock in their config directory, and VS Code uses an IPC socket in
`XDG_RUNTIME_DIR`. An application already running in the user's session takes
over a launch from the agent desktop and opens the window on the user's
desktop; conversely an instance started in the agent desktop captures later
launches from the user's desktop until it exits. Firefox holds a profile lock
and refuses to start while the user's instance runs. `xdg-open` and URL
handlers inside the agent desktop resolve through the shared `mimeapps.list`
to the user's default browser and hand the URL to the user's running Chrome,
not the copy. Terminals run the user's shell startup files, including
anything there that attaches to the user's tmux server. Downloads and other
file writes go to the user's real directories, audio goes to the shared
PipeWire session, and GTK applications started in both desktops run as
separate instances on the same configuration. `stop` kills every process in
the unit without asking, so unsaved work in agent applications is lost.
Neither file writes nor keyring access are contained by compositor isolation.
