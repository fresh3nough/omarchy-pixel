#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
export PATH="${PREFIX:-/data/data/com.termux/files/usr}/bin:$PATH"
HOME_DIR="${HOME:-/data/data/com.termux/files/home}"
if [ -x "$HOME_DIR/start-omarchy-fullscreen.sh" ]; then
  exec bash "$HOME_DIR/start-omarchy-fullscreen.sh"
fi
if [ -x "$HOME_DIR/start-omarchy.sh" ]; then
  exec bash "$HOME_DIR/start-omarchy.sh"
fi
exec bash /sdcard/omarchy-pixel/start-omarchy-fullscreen.sh
