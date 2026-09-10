#!/data/data/com.termux/files/usr/bin/bash
# Debug/launch wrapper for Omarchy on Pixel.
# Runs termux-x11 with a short xstartup script and no LD_PRELOAD.
set -euo pipefail

PREFIX=/data/data/com.termux/files/usr
HOME_DIR=/data/data/com.termux/files/home
export PATH="$PREFIX/bin:$PATH"

pkill -9 termux-x11 Xwayland pulseaudio 2>/dev/null || true
rm -rf "$PREFIX/tmp/.X11-unix" 2>/dev/null || true
mkdir -p "$PREFIX/tmp/.X11-unix"

# Unset Termux's LD_PRELOAD because Xorg refuses to start in an unsafe environment.
env -u LD_PRELOAD termux-x11 :0 \
  -xstartup /sdcard/omarchy-pixel/omarchy-xstartup.sh \
  >/sdcard/omarchy-pixel/termux-x11.log 2>&1 &

sleep 2
am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity >/dev/null 2>&1 || true
echo "Omarchy X11 launch requested."
