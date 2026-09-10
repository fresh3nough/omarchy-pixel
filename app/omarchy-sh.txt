#!/data/data/com.termux/files/usr/bin/bash
# Omarchy App - Pixel Edition
# Termux:Widget / RUN_COMMAND entry → start-omarchy.sh
set -euo pipefail
HOME_DIR="${HOME:-/data/data/com.termux/files/home}"
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
export PATH="$PREFIX/bin:$PATH"

if [ -x "$HOME_DIR/start-omarchy.sh" ]; then
  exec bash "$HOME_DIR/start-omarchy.sh"
fi

# Fallback if start script not yet seeded into $HOME
if [ -x /sdcard/omarchy-pixel/start-omarchy.sh ]; then
  exec bash /sdcard/omarchy-pixel/start-omarchy.sh
fi

echo "start-omarchy.sh not found. Run bootstrap-on-device.sh first." >&2
exit 1
