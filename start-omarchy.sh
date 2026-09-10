#!/data/data/com.termux/files/usr/bin/bash
# Launch Omarchy (Hyprland via Termux:X11) — foot + goose
set -euo pipefail
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
export PATH="$PREFIX/bin:$PATH"
HOME_DIR="${HOME:-/data/data/com.termux/files/home}"
SDCARD_DIR="/sdcard/omarchy-pixel"
XSTARTUP=""

# Prefer a short -xstartup script path; long inline commands get rejected.
for candidate in \
  "$HOME_DIR/omarchy-xstartup.sh" \
  "$SDCARD_DIR/omarchy-xstartup.sh" \
  "$HOME_DIR/bin/omarchy-xstartup.sh"
do
  if [ -f "$candidate" ]; then
    XSTARTUP="$candidate"
    break
  fi
done

if [ ! -f "$HOME_DIR/.omarchy-installed" ] && ! proot-distro list 2>/dev/null | grep -qi archlinux; then
  echo "Omarchy not installed yet. Running setup..."
  if [ -f "$HOME_DIR/setup-omarchy-pixel.sh" ]; then
    exec bash "$HOME_DIR/setup-omarchy-pixel.sh"
  fi
  exec bash "$SDCARD_DIR/setup-omarchy-pixel.sh"
fi

pkill -9 termux-x11 2>/dev/null || true
pkill -9 Xwayland 2>/dev/null || true
pkill -9 pulseaudio 2>/dev/null || true
sleep 0.5
rm -rf "$PREFIX/tmp/.X11-unix" 2>/dev/null || true
mkdir -p "$PREFIX/tmp/.X11-unix"

pulseaudio --start \
  --load="module-native-protocol-tcp auth-anonymous=1" \
  --exit-idle-time=-1 2>/dev/null || pulseaudio --start 2>/dev/null || true

if [ -n "$XSTARTUP" ]; then
  # Unset Termux LD_PRELOAD — Xorg refuses unsafe environments.
  env -u LD_PRELOAD termux-x11 :0 -xstartup "$XSTARTUP" \
    >"$SDCARD_DIR/termux-x11.log" 2>&1 &
else
  env -u LD_PRELOAD termux-x11 :0 -xstartup \
    "sleep 1; proot-distro login archlinux --user cody --shared-tmp --bind ${PREFIX}/tmp:/tmp -- env DISPLAY=:0 WAYLAND_DISPLAY=wayland-0 XDG_RUNTIME_DIR=/tmp HOME=/home/cody PULSE_SERVER=tcp:127.0.0.1 QT_QPA_PLATFORM=wayland GDK_BACKEND=wayland /home/cody/.local/bin/omarchy-session" \
    >"$SDCARD_DIR/termux-x11.log" 2>&1 &
fi

sleep 1
am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity >/dev/null 2>&1 \
  || am start --user 0 -n com.termux.x11/.MainActivity >/dev/null 2>&1 \
  || true

echo "Omarchy session started."
echo "SUPER+Return = foot  |  SUPER+K = keyboard  |  SUPER+G = goose"
