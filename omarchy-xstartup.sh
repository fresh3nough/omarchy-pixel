#!/data/data/com.termux/files/usr/bin/bash
# Omarchy X11 startup script for Termux:X11.
# Kept short because termux-x11 -xstartup rejects very long arguments.
set -euo pipefail

PREFIX=/data/data/com.termux/files/usr
export PATH="$PREFIX/bin:$PATH"

rm -rf "$PREFIX/tmp/.X11-unix" 2>/dev/null || true
mkdir -p "$PREFIX/tmp/.X11-unix"

pulseaudio --start \
  --load="module-native-protocol-tcp auth-anonymous=1" \
  --exit-idle-time=-1 >/dev/null 2>&1 || true

exec proot-distro login archlinux \
  --user cody \
  --shared-tmp \
  --bind "$PREFIX/tmp:/tmp" \
  -- env DISPLAY=:0 \
       WAYLAND_DISPLAY=wayland-0 \
       XDG_RUNTIME_DIR=/tmp \
       HOME=/home/cody \
       PULSE_SERVER=tcp:127.0.0.1 \
       QT_QPA_PLATFORM=wayland \
       GDK_BACKEND=wayland \
       /home/cody/.local/bin/omarchy-session
