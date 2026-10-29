# Launch an independent browser

Read [connection.md](connection.md) for mode selection and shared parameters.
Set `CDT` and export the task's resolved `CDT_VERSION` in each shell call.

## Fresh profile

Discover an installed Chrome/Chromium executable with `command -v chromium`,
`command -v google-chrome-stable`, or `command -v google-chrome`. Set `BROWSER`
to the appropriate absolute path. Do not install a browser or disable its
sandbox to work around a launch failure.

After checking that the daemon is idle and stopping it if needed, start a fresh
headless browser:

```sh
CDT_TIMEOUT=20s "$CDT" start \
  --executablePath="$BROWSER" \
  --headless=true \
  --isolated \
  --categoryExtensions=false \
  --workspace=/tmp/opencode \
  --logFile=/tmp/opencode/chrome-devtools.log
```

For a visible browser, use the same command with `--headless=false`. A visible
launch needs a working graphical session (`DISPLAY` or `WAYLAND_DISPLAY` on
Linux). It opens a separate window with its own profile, not the user's existing
tabs. If no display is available, report that requirement rather than silently
switching to attach mode.

Omit `--autoConnect`, `--browserUrl`, `--wsEndpoint`, and the user's profile path
in both launch modes. `--isolated` creates a temporary profile that is removed
when the launched browser closes. It cannot be combined with `--userDataDir`.

## Start, verify, and finish

Launch is lazy: `start` creates the daemon, and the first browser command opens
Chrome. Run the initial `start` plus `list_pages` through a background shell call.
There is no remote-debugging approval prompt for a browser launched by the CLI.
Read the first command's result to confirm launch, rather than treating a running
daemon as proof that Chrome started.

Use short foreground calls for ordinary operations once launched. The fresh
profile has no inherited cookies or extensions; check the actual session before
performing actions that require authentication.

Finish independent browsing with `"$CDT" stop` after saving required artifacts.
This closes only the CLI-launched browser. Reconnect in attach mode only if the
next task calls for the user's existing browser.
