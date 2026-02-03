#!/bin/sh
# Wait for linux-enable-ir-emitter video device and v4l devices to be ready
# Usage: wait-for-ir-emitter-devices.sh <video-device>
# Example: wait-for-ir-emitter-devices.sh /dev/video2

set -e

if [ $# -ne 1 ]; then
  echo "Usage: $0 <video-device>" >&2
  echo "Example: $0 /dev/video2" >&2
  exit 1
fi

video_device="$1"

# Wait for the primary video device
echo "Waiting for video device: $video_device"
until [ -e "$video_device" ]; do
  sleep 0.5
done
echo "Found video device: $video_device"

# Find configured device path and wait for v4l devices to appear
config_dir="/var/lib/linux-enable-ir-emitter"
if [ -d "$config_dir" ]; then
  # Find all device config files (excluding .ini files)
  for device_file in "$config_dir"/*; do
    # Skip if it's an .ini file or not a regular file
    if [ ! -f "$device_file" ] || [ "${device_file%.ini}" != "$device_file" ]; then
      continue
    fi
    
    # Extract device name from path
    device_name=$(basename "$device_file")
    v4l_device="/dev/v4l/by-path/$device_name"
    
    # Wait for the v4l device to appear
    echo "Waiting for v4l device: $v4l_device"
    until [ -e "$v4l_device" ]; do
      sleep 0.5
    done
    echo "Found v4l device: $v4l_device"
  done
else
  echo "Warning: Config directory $config_dir does not exist" >&2
fi

echo "All IR emitter devices ready"
