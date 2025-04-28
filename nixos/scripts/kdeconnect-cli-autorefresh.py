import sys
import os
import subprocess
import time

if len(sys.argv) != 2:
    print("Usage: kdeconnect-cli-autorefresh.py <sleep-seconds>")
    sys.exit(1)

sleep_seconds = int(sys.argv[1])

print(f"Refreshing every {sleep_seconds} seconds")

while True:
    # Check if kdeconnectd is running
    kdeconnectd_running = subprocess.run(
        ["pgrep", "kdeconnectd"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    ).returncode == 0

    if kdeconnectd_running:
        # Run kdeconnect-cli --refresh
        try:
            subprocess.run(["kdeconnect-cli", "--refresh"], check=True)
        except subprocess.CalledProcessError as e:
            print(f"Error running kdeconnect-cli: {e}", file=sys.stderr)

    time.sleep(sleep_seconds)
