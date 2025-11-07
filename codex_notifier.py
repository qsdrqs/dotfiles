#!/usr/bin/env python3

import json
import subprocess
import sys
import shutil
import platform
import os


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: notify.py <NOTIFICATION_JSON>")
        return 1

    try:
        notification = json.loads(sys.argv[1])
    except json.JSONDecodeError:
        return 1

    match notification_type := notification.get("type"):
        case "agent-turn-complete":
            assistant_message = notification.get("last-assistant-message")
            if assistant_message:
                title = f"Codex: {assistant_message}"
            else:
                title = "Codex: Turn Complete!"
            input_messages = notification.get("input-messages", [])
            message = " ".join(input_messages)
            title += message
        case _:
            print(f"not sending a push notification for: {notification_type}")
            return 0

    thread_id = notification.get("thread-id", "")

    def is_wsl() -> bool:
        if platform.system() != "Linux":
            return False
        if os.environ.get("WSL_DISTRO_NAME"):
            return True
        try:
            with open("/proc/version", "r", encoding="utf-8", errors="ignore") as f:
                ver = f.read().lower()
            return "microsoft" in ver or "wsl" in ver
        except Exception:
            return False

    def send_linux(title: str, message: str) -> None:
        notify_send = shutil.which("notify-send")
        if notify_send:
            subprocess.run(
                [notify_send, "-a", "Codex", title, message or ""], check=False
            )
        else:
            print("notify-send not found; skipping notification", file=sys.stderr)

    def send_windows(title: str, message: str) -> None:
        # Prefer Windows PowerShell balloon tip via System.Windows.Forms.
        # This avoids external deps (SnoreToast/BurntToast).
        ps = shutil.which("powershell.exe") or shutil.which("pwsh.exe") or shutil.which("powershell")
        if not ps:
            print("PowerShell not found; cannot send Windows notification", file=sys.stderr)
            return

        ps_script = (
            "[void][Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms');"
            "[void][Reflection.Assembly]::LoadWithPartialName('System.Drawing');"
            "$ni = New-Object System.Windows.Forms.NotifyIcon;"
            "$ni.Icon = [System.Drawing.SystemIcons]::Information;"
            "$ni.Visible = $true;"
            "$ni.BalloonTipTitle = $args[0];"
            "$ni.BalloonTipText = $args[1];"
            "$ni.ShowBalloonTip(5000);"
            "Start-Sleep -Seconds 6;"
            "$ni.Dispose();"
        )

        # Run detached so we don't block Python while the tip is visible.
        try:
            subprocess.Popen(
                [ps, "-NoProfile", "-WindowStyle", "Hidden", "-Command", ps_script, title, message or ""],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
        except Exception as e:
            print(f"failed to invoke PowerShell notification: {e}", file=sys.stderr)

    system = platform.system()
    if system == "Linux" and not is_wsl():
        send_linux(title, message or "")
    elif system == "Windows" or is_wsl():
        # On WSL, prefer Windows notification for visibility.
        send_windows(title, message or "")
    else:
        # Unsupported OS by request; skip silently.
        print(f"notifications not supported on {system}", file=sys.stderr)

    return 0


if __name__ == "__main__":
    sys.exit(main())
