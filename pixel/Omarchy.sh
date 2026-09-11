#!/data/data/com.termux/files/usr/bin/bash
# Home-screen Termux:Widget shortcut
export PATH="${PREFIX:-/data/data/com.termux/files/usr}/bin:$PATH"
H="${HOME:-/data/data/com.termux/files/home}"
if [ -x "$H/start-omarchy-fullscreen.sh" ]; then
  exec bash "$H/start-omarchy-fullscreen.sh"
fi
if [ -f /sdcard/omarchy-pixel/start-omarchy-fullscreen.sh ]; then
  # sdcard is noexec — run via bash
  exec bash /sdcard/omarchy-pixel/start-omarchy-fullscreen.sh
fi
echo "Omarchy start script missing" >&2
exit 1
