#!/data/data/com.termux/files/usr/bin/bash
set +e
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
export PATH="$PREFIX/bin:$PATH"
SD=/sdcard/omarchy-pixel
LOG=$SD/termux-x11.log
LOCK=$PREFIX/tmp/omarchy-launch.lock
mkdir -p "$PREFIX/tmp" "$SD"
if [ -f "$LOCK" ]; then
  age=$(( $(date +%s) - $(stat -c %Y "$LOCK" 2>/dev/null || echo 0) ))
  [ "$age" -lt 25 ] && { am start -n com.termux.x11/com.termux.x11.MainActivity >/dev/null 2>&1; exit 0; }
fi
date +%s > "$LOCK"
echo "LAUNCH $(date -Iseconds)" | tee -a "$SD/launch-history.log"
pkill -9 termux-x11 2>/dev/null
pkill -9 sway 2>/dev/null
pkill -9 foot 2>/dev/null
pkill -9 waybar 2>/dev/null
pkill -9 swaybg 2>/dev/null
pkill -9 goose 2>/dev/null
sleep 0.7
rm -rf "$PREFIX/tmp/.X11-unix" 2>/dev/null
mkdir -p "$PREFIX/tmp/.X11-unix"
proot-distro login archlinux --user cody --shared-tmp -- bash -lc 'rm -rf $HOME/.run; mkdir -p $HOME/.run; chmod 700 $HOME/.run; rm -f /tmp/wayland-* /tmp/sway-ipc.*' 2>/dev/null
: > "$LOG"
settings put system accelerometer_rotation 0 2>/dev/null
settings put system user_rotation 1 2>/dev/null
wm user-rotation lock 1 2>/dev/null
pulseaudio --start --load="module-native-protocol-tcp auth-anonymous=1" --exit-idle-time=-1 2>/dev/null || true
env -u LD_PRELOAD termux-x11 :0 -ac >"$LOG" 2>&1 &
am start -n com.termux.x11/com.termux.x11.MainActivity --activity-clear-top >/dev/null 2>&1
settings put global policy_control immersive.full=com.termux.x11 2>/dev/null
for i in $(seq 1 50); do [ -S "$PREFIX/tmp/.X11-unix/X0" ] && break; sleep 0.2; done
sleep 0.6
proot-distro login archlinux --user cody --shared-tmp -- env \
  DISPLAY=:0 HOME=/home/cody PULSE_SERVER=tcp:127.0.0.1 \
  WLR_BACKENDS=x11 WLR_NO_HARDWARE_CURSORS=1 WLR_RENDERER=pixman \
  LIBGL_ALWAYS_SOFTWARE=1 GLYCIN_DISABLE_SANDBOX=1 BUBBLEWRAP_SKIP=1 \
  LANG=C.UTF-8 LC_ALL=C.UTF-8 /home/cody/.local/bin/omarchy-session >>"$LOG" 2>&1 &
# Only wait; do NOT restart wallpaper/bar in a temporary proot.
for i in $(seq 1 60); do
  count=$(adb shell true 2>/dev/null; proot-distro login archlinux --user cody --shared-tmp -- bash -lc 'pgrep -c -x sway; pgrep -c -x swaybg; pgrep -c -x waybar; pgrep -c -x goose' 2>/dev/null | tr '\n' ' ')
  echo "wait $i $count" >> "$LOG"
  echo "$count" | grep -Eq '[1-9].*[1-9].*[1-9].*[1-9]' && break
  sleep 0.5
done
am start -n com.termux.x11/com.termux.x11.MainActivity >/dev/null 2>&1
rm -f "$LOCK"
echo "Omarchy UI started $(date -Iseconds)" | tee -a "$LOG"
