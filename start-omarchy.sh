#!/data/data/com.termux/files/usr/bin/bash
# Omarchy.sh home shortcut — landscape desktop + quattro wallpaper
set +e
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
export PATH="$PREFIX/bin:$PATH"
SD=/sdcard/omarchy-pixel
LOG=$SD/termux-x11.log
H="${HOME:-/data/data/com.termux/files/home}"
mkdir -p "$SD" "$H/.shortcuts" "$PREFIX/tmp"

LOCK=$PREFIX/tmp/omarchy-launch.lock
if [ -f "$LOCK" ]; then
  age=$(( $(date +%s) - $(stat -c %Y "$LOCK" 2>/dev/null || echo 0) ))
  if [ "$age" -lt 25 ]; then
    am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity >/dev/null 2>&1
    exit 0
  fi
fi
date +%s > "$LOCK"
echo "LAUNCH $(date -Iseconds)" | tee -a "$SD/launch-history.log"

pkill -9 termux-x11 2>/dev/null
pkill -9 sway 2>/dev/null
pkill -9 foot 2>/dev/null
pkill -9 waybar 2>/dev/null
pkill -9 swaybg 2>/dev/null
pkill -9 feh 2>/dev/null
pkill -9 chromium 2>/dev/null
sleep 0.6

rm -rf "$PREFIX/tmp/.X11-unix" 2>/dev/null
mkdir -p "$PREFIX/tmp/.X11-unix" "$PREFIX/tmp"
proot-distro login archlinux --user cody --shared-tmp -- bash -lc \
  'rm -f /tmp/wayland-* /tmp/sway-ipc.* 2>/dev/null
   rm -rf "$HOME/.run"; mkdir -p "$HOME/.run"; chmod 700 "$HOME/.run"' 2>/dev/null

: > "$LOG"
settings put system accelerometer_rotation 0 2>/dev/null
settings put system user_rotation 1 2>/dev/null
wm user-rotation lock 1 2>/dev/null

pulseaudio --start --load="module-native-protocol-tcp auth-anonymous=1" --exit-idle-time=-1 2>/dev/null || pulseaudio --start 2>/dev/null

env -u LD_PRELOAD termux-x11 :0 -ac >"$LOG" 2>&1 &
am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity \
  --activity-clear-top --activity-single-top >/dev/null 2>&1
settings put global policy_control immersive.full=com.termux.x11 2>/dev/null

for i in $(seq 1 50); do
  [ -S "$PREFIX/tmp/.X11-unix/X0" ] && break
  sleep 0.2
done
sleep 0.6

proot-distro login archlinux --user cody --shared-tmp -- env \
  DISPLAY=:0 HOME=/home/cody \
  PULSE_SERVER=tcp:127.0.0.1 \
  WLR_BACKENDS=x11 WLR_NO_HARDWARE_CURSORS=1 WLR_RENDERER=pixman \
  LIBGL_ALWAYS_SOFTWARE=1 GLYCIN_DISABLE_SANDBOX=1 BUBBLEWRAP_SKIP=1 \
  LANG=C.UTF-8 LC_ALL=C.UTF-8 \
  /home/cody/.local/bin/omarchy-session >>"$LOG" 2>&1 &

for i in $(seq 1 40); do
  if proot-distro login archlinux --user cody --shared-tmp -- bash -lc 'pgrep -x sway >/dev/null' 2>/dev/null; then
    break
  fi
  sleep 0.3
done
sleep 2

# Wallpaper + bar with retries (uses live sway env)
for attempt in 1 2 3; do
  proot-distro login archlinux --user cody --shared-tmp -- bash -lc '
    export HOME=/home/cody PATH=$HOME/.local/bin:/usr/bin:$PATH DISPLAY=:0
    export GLYCIN_DISABLE_SANDBOX=1 BUBBLEWRAP_SKIP=1
    BG=$HOME/.local/share/omarchy-pixel/backgrounds/1-quattro.jpg
    [ -f "$BG" ] || cp -f /sdcard/omarchy-pixel/backgrounds/1-quattro.jpg "$BG" 2>/dev/null
    # bwrap stub
    if [ -x /usr/bin/bwrap ] && ! head -1 /usr/bin/bwrap 2>/dev/null | grep -q bash; then
      [ -f /usr/bin/bwrap.real ] || sudo mv /usr/bin/bwrap /usr/bin/bwrap.real
      printf "%s\n" "#!/usr/bin/bash" "cmd=(); args=(\"\$@\")" "for i in \"\${!args[@]}\"; do" " a=\"\${args[\$i]}\"" " if [[ \"\$a\" == *glycin-loaders* ]]; then cmd=(\"\${args[@]:\$i}\"); break; fi" " if [ \"\$a\" = \"--\" ]; then cmd=(\"\${args[@]:\$((i+1))}\"); break; fi" "done" "[ \${#cmd[@]} -eq 0 ] && exit 1" "export PATH=/usr/bin:/bin HOME=/tmp XDG_RUNTIME_DIR=/tmp LD_LIBRARY_PATH=/usr/lib" "exec \"\${cmd[@]}\"" | sudo tee /usr/bin/bwrap >/dev/null
      sudo chmod 755 /usr/bin/bwrap
    fi
    /home/cody/.local/bin/omarchy-wallpaper
    pgrep -x waybar >/dev/null || waybar >/tmp/waybar.log 2>&1 &
    pgrep -x foot >/dev/null || foot >/dev/null 2>&1 &
    pgrep -a swaybg; pgrep -a waybar; pgrep -a foot
    grep -q swaybg_ok /tmp/wp.log 2>/dev/null && exit 0
    exit 1
  ' >>"$LOG" 2>&1 && break
  sleep 1
done

am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity >/dev/null 2>&1
rm -f "$LOCK"
echo "Omarchy landscape desktop started $(date -Iseconds)" | tee -a "$LOG"
