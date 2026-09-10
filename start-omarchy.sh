#!/data/data/com.termux/files/usr/bin/bash
# Launch Omarchy desktop via Termux:X11 + Arch proot compositor
set -euo pipefail
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
export PATH="$PREFIX/bin:$PATH"
HOME_DIR="${HOME:-/data/data/com.termux/files/home}"
SDCARD_DIR="/sdcard/omarchy-pixel"
LOG="$SDCARD_DIR/termux-x11.log"

if [ ! -f "$HOME_DIR/.omarchy-installed" ] && ! proot-distro login archlinux -- true >/dev/null 2>&1; then
  echo "Omarchy not installed yet. Running setup..."
  if [ -f "$HOME_DIR/setup-omarchy-pixel.sh" ]; then
    exec bash "$HOME_DIR/setup-omarchy-pixel.sh"
  fi
  exec bash "$SDCARD_DIR/setup-omarchy-pixel.sh"
fi

pkill -9 termux-x11 2>/dev/null || true
pkill -9 Xwayland 2>/dev/null || true
sleep 0.5
rm -rf "$PREFIX/tmp/.X11-unix" 2>/dev/null || true
mkdir -p "$PREFIX/tmp/.X11-unix" "$PREFIX/tmp"
: > "$LOG"

pulseaudio --start \
  --load="module-native-protocol-tcp auth-anonymous=1" \
  --exit-idle-time=-1 2>/dev/null || pulseaudio --start 2>/dev/null || true

# 1) Start Termux:X11 X server only.
# Unset LD_PRELOAD for Xorg only — proot still needs Termux's preload.
env -u LD_PRELOAD termux-x11 :0 >"$LOG" 2>&1 &

am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity >/dev/null 2>&1 \
  || am start --user 0 -n com.termux.x11/.MainActivity >/dev/null 2>&1 \
  || true

# 2) Wait for the X11 socket under Termux tmp
for i in $(seq 1 40); do
  if [ -S "$PREFIX/tmp/.X11-unix/X0" ]; then
    echo "X0 ready after ${i} tries" >>"$LOG"
    break
  fi
  sleep 0.5
done

if [ ! -S "$PREFIX/tmp/.X11-unix/X0" ]; then
  echo "WARN: X0 socket missing" | tee -a "$LOG"
  ls -la "$PREFIX/tmp" "$PREFIX/tmp/.X11-unix" >>"$LOG" 2>&1 || true
fi

sleep 1

# 3) Start compositor inside Arch against DISPLAY=:0
# Keep default env (incl. LD_PRELOAD) so proot can exec.
# --shared-tmp shares Termux /tmp (X0) into the proot.
proot-distro login archlinux \
  --user cody \
  --shared-tmp \
  -- env \
    DISPLAY=:0 \
    XDG_RUNTIME_DIR=/tmp \
    HOME=/home/cody \
    PULSE_SERVER=tcp:127.0.0.1 \
    WLR_BACKENDS=x11 \
    WLR_NO_HARDWARE_CURSORS=1 \
    QT_QPA_PLATFORM=wayland \
    GDK_BACKEND=wayland \
    /home/cody/.local/bin/omarchy-session \
  >>"$LOG" 2>&1 &

sleep 2
am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity >/dev/null 2>&1 \
  || am start --user 0 -n com.termux.x11/.MainActivity >/dev/null 2>&1 \
  || true

echo "Omarchy session started."
echo "SUPER+Return = foot  |  SUPER+Shift+e = exit sway"
