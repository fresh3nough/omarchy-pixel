#!/data/data/com.termux/files/usr/bin/bash
# Launch Omarchy desktop fullscreen on Termux:X11 (landscape / monitor-mirror ready)
set +e
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
export PATH="$PREFIX/bin:$PATH"
SD=/sdcard/omarchy-pixel
LOG=$SD/termux-x11.log

pkill -9 termux-x11 2>/dev/null
pkill -9 sway 2>/dev/null
pkill -9 foot 2>/dev/null
pkill -9 waybar 2>/dev/null
pkill -9 swaybg 2>/dev/null
pkill -9 feh 2>/dev/null
sleep 0.5
rm -rf "$PREFIX/tmp/.X11-unix" 2>/dev/null
mkdir -p "$PREFIX/tmp/.X11-unix" "$PREFIX/tmp"

# Clean stale compositor sockets inside Arch
proot-distro login archlinux --user cody --shared-tmp -- bash -lc \
  'rm -f /tmp/wayland-* /tmp/sway-ipc.* 2>/dev/null; rm -rf "$HOME/.run"; mkdir -p "$HOME/.run"; chmod 700 "$HOME/.run"' 2>/dev/null

: > "$LOG"

# Prefer landscape for monitor mirroring
settings put system accelerometer_rotation 0 2>/dev/null
settings put system user_rotation 1 2>/dev/null
wm user-rotation lock 1 2>/dev/null

pulseaudio --start \
  --load="module-native-protocol-tcp auth-anonymous=1" \
  --exit-idle-time=-1 2>/dev/null || pulseaudio --start 2>/dev/null

env -u LD_PRELOAD termux-x11 :0 -ac >"$LOG" 2>&1 &
am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity \
  --activity-clear-top --activity-single-top >/dev/null 2>&1
settings put global policy_control immersive.full=com.termux.x11 2>/dev/null

for i in $(seq 1 50); do
  [ -S "$PREFIX/tmp/.X11-unix/X0" ] && break
  sleep 0.2
done
sleep 0.5

proot-distro login archlinux --user cody --shared-tmp -- env \
  DISPLAY=:0 HOME=/home/cody \
  PULSE_SERVER=tcp:127.0.0.1 \
  WLR_BACKENDS=x11 WLR_NO_HARDWARE_CURSORS=1 WLR_RENDERER=pixman \
  LIBGL_ALWAYS_SOFTWARE=1 GLYCIN_DISABLE_SANDBOX=1 BUBBLEWRAP_SKIP=1 \
  LANG=C.UTF-8 LC_ALL=C.UTF-8 \
  /home/cody/.local/bin/omarchy-session >>"$LOG" 2>&1 &

sleep 3
proot-distro login archlinux --user cody --shared-tmp -- env \
  DISPLAY=:0 HOME=/home/cody \
  XDG_RUNTIME_DIR=/home/cody/.run WAYLAND_DISPLAY=wayland-1 \
  /home/cody/.local/bin/omarchy-wallpaper >>"$LOG" 2>&1

am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity >/dev/null 2>&1
echo "Omarchy landscape desktop started." | tee -a "$LOG"
