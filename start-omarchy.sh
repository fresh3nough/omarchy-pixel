#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
export PATH="$PREFIX/bin:$PATH"
HOME_DIR="${HOME:-/data/data/com.termux/files/home}"
SDCARD=/sdcard/omarchy-pixel
LOG="$SDCARD/termux-x11.log"

pkill -9 termux-x11 2>/dev/null || true
pkill -9 sway 2>/dev/null || true
pkill -9 feh 2>/dev/null || true
sleep 0.3
rm -rf "$PREFIX/tmp/.X11-unix" 2>/dev/null || true
mkdir -p "$PREFIX/tmp/.X11-unix" "$PREFIX/tmp"
: > "$LOG"

pulseaudio --start \
  --load="module-native-protocol-tcp auth-anonymous=1" \
  --exit-idle-time=-1 2>/dev/null || pulseaudio --start 2>/dev/null || true

env -u LD_PRELOAD termux-x11 :0 >"$LOG" 2>&1 &

am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity \
  --activity-clear-top --activity-single-top >/dev/null 2>&1 || true
settings put global policy_control immersive.full=com.termux.x11 2>/dev/null || true

for i in $(seq 1 40); do
  [ -S "$PREFIX/tmp/.X11-unix/X0" ] && break
  sleep 0.25
done
sleep 0.5

proot-distro login archlinux --user cody --shared-tmp -- env \
  DISPLAY=:0 XDG_RUNTIME_DIR=/tmp HOME=/home/cody \
  PULSE_SERVER=tcp:127.0.0.1 \
  WLR_BACKENDS=x11 WLR_NO_HARDWARE_CURSORS=1 \
  LANG=C.UTF-8 LC_ALL=C.UTF-8 \
  /home/cody/.local/bin/omarchy-session >>"$LOG" 2>&1 &

sleep 2
am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity >/dev/null 2>&1 || true
echo "Omarchy desktop started."
