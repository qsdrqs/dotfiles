# Launch with a copy of an existing profile

Use this mode when an independent browser needs existing login state. Read
[connection.md](connection.md) for shared parameters and [launch.md](launch.md)
for browser discovery and lifecycle. Match the browser executable to the source
profile's browser brand and a compatible version.

## Copy the user-data root

Set `COPY` to this skill's `scripts/copy-profile.py` absolute path. The local
Chromium source is `$HOME/.config/chromium`; Google Chrome commonly uses
`$HOME/.config/google-chrome`. Copy the user-data root containing `Local State`,
not just its `Default` or `Profile 1` subdirectory.

```sh
python3 "$COPY" --source "$HOME/.config/chromium"
```

Run the copy in a background shell call. The helper follows the `computer-use`
profile-copy method: `cp -a --reflink=auto`, then removal of `Singleton*`,
`DevToolsActivePort`, and each profile's `Sessions` directory from the copy.
It creates a unique private directory under the user cache, never overwrites a
previous copy, and leaves the source's locks and session files untouched.
Reflinks share file extents until modified; this is not a hard-link copy.

Retain the returned `directory` and `userDataDir`. Set `COPIED_PROFILE` to the
returned `userDataDir`. For sources with several profiles, select the intended
profile with an additional `--chromeArg=--profile-directory=ProfileName`.

A running browser can change SQLite files during copying. If the clone reports
database corruption or missing recent state, ask the user to close the source
browser before making a new copy.

## Preserve keyring access

Copying encrypted cookies is only part of reusing login state. The browser needs
the same password backend and the user's keyring. For this Linux setup, use
`--password-store=gnome-libsecret`, as in `computer-use`, and inherit the user's
`DBUS_SESSION_BUS_ADDRESS`. A locked KeePassXC database can prompt the user to
unlock it. Do not print cookie or key material or switch to a basic password
store to bypass decryption failures.

This CLI launches on the current session bus. The separate niri desktop used by
`computer-use` needs a secrets bridge because it has a private bus; this workflow
does not start that desktop or its bridge. If launching on a private bus, use
the `computer-use` workflow for its bridge rather than assuming keyring access.

## Start the copy

After checking the existing daemon's activity, stop it if needed. Set `BROWSER`
to the matching executable, `CDT` to the wrapper, and export the task's resolved
`CDT_VERSION`. Then start the copied profile:

```sh
CDT_TIMEOUT=20s "$CDT" start \
  --executablePath="$BROWSER" \
  --userDataDir="$COPIED_PROFILE" \
  --headless=true \
  --ignoreDefaultChromeArg=--password-store=basic \
  --ignoreDefaultChromeArg=--use-mock-keychain \
  --chromeArg=--password-store=gnome-libsecret \
  --chromeArg=--no-first-run \
  --chromeArg=--no-default-browser-check \
  --chromeArg=--disable-sync \
  --chromeArg=--mute-audio \
  --workspace=/tmp/opencode \
  --logFile=/tmp/opencode/chrome-devtools.log
```

Use `--headless=false` for a visible browser. Do not pass `--isolated` with
`--userDataDir`, and do not pass `--autoConnect`. Run the initial browser command
in the background to trigger launch. Check the intended site's actual signed-in
state before relying on it; copying alone does not prove authentication works.
The copy includes extensions, so apply the Surfingkeys check when present.

## Finish

Stop the copy's daemon, verify its browser has exited, then remove only the
specific `directory` returned by the helper. The copy contains authentication
data: do not commit, upload, or retain it as a reusable artifact. Browser changes
stay in the copy; remote actions such as submitting forms still take effect.
