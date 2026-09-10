#!/usr/bin/env bash
# Host-side installer: push Omarchy-on-Pixel to a USB-connected phone and run it.
# Android 10+ blocks adb from reading /data/data/com.termux — we drive Termux via
# input injection and monitor progress only through /sdcard/omarchy-pixel/.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APK_DIR="$ROOT/apks"
SETUP_SCRIPT="$ROOT/setup-omarchy-pixel.sh"
START_SCRIPT="$ROOT/start-omarchy.sh"
TERMUX_HOME="/data/data/com.termux/files/home"
TERMUX_PREFIX="/data/data/com.termux/files/usr"
LOG="$ROOT/install-log.txt"
STAGING="$ROOT/staging"
SDCARD_DIR="/sdcard/omarchy-pixel"
SETUP_LOG="$STAGING/omarchy-setup.log"
mkdir -p "$STAGING" "$APK_DIR"

log() { printf '\n\033[1;32m[adb]\033[0m %s\n' "$*" | tee -a "$LOG"; }
die() { printf '\033[1;31m[err]\033[0m %s\n' "$*" | tee -a "$LOG"; exit 1; }

: > "$LOG"

command -v adb >/dev/null || die "adb not found"
adb start-server >/dev/null
DEVICE="$(adb devices | awk '/\tdevice$/{print $1; exit}')"
[ -n "$DEVICE" ] || die "No adb device in 'device' state."
MODEL="$(adb shell getprop ro.product.model | tr -d '\r')"
log "Using device: $DEVICE ($MODEL)"

SIZE="$(adb shell wm size | tr -d '\r' | awk -F': ' '/Physical/{print $2}')"
DENSITY="$(adb shell wm density | tr -d '\r' | awk -F': ' '/Physical/{print $2}')"
W="${SIZE%x*}"; H="${SIZE#*x}"
SCALE="$(python3 - <<PY
d=${DENSITY:-480}
print(round(max(1.5, min(2.5, d/160.0*0.7)), 2))
PY
)"
log "Display ${W}x${H} density=${DENSITY} → scale=${SCALE}"

need_apk() {
  local pkg="$1" apk="$2" url="${3:-}"
  if adb shell pm path "$pkg" 2>/dev/null | grep -q "package:"; then
    log "Already installed: $pkg"
    return 0
  fi
  if [ ! -f "$apk" ] && [ -n "$url" ]; then
    log "Downloading $(basename "$apk")..."
    curl -L --fail -o "$apk" "$url"
  fi
  [ -f "$apk" ] || die "Missing APK: $apk"
  log "Installing $(basename "$apk") → $pkg"
  if ! adb install -r -g "$apk" 2>&1 | tee -a "$LOG"; then
    adb install -r "$apk" 2>&1 | tee -a "$LOG"
  fi
  adb shell pm path "$pkg" 2>/dev/null | grep -q "package:" || die "Failed to install $pkg"
}

need_apk com.termux \
  "$APK_DIR/termux.apk" \
  "https://f-droid.org/repo/com.termux_1022.apk"
# Non-sharedUid X11 matches F-Droid Termux signature
need_apk com.termux.x11 \
  "$APK_DIR/termux-x11-noshared.apk" \
  "https://github.com/termux/termux-x11/releases/download/nightly/termux-x11-universal-debug.apk"
need_apk com.termux.widget \
  "$APK_DIR/termux-widget.apk" \
  "https://f-droid.org/repo/com.termux.widget_1001.apk"
if [ ! -f "$APK_DIR/termux-api.apk" ]; then
  curl -L --fail -o "$APK_DIR/termux-api.apk" \
    "https://f-droid.org/repo/com.termux.api_1002.apk" 2>/dev/null || true
fi
[ -f "$APK_DIR/termux-api.apk" ] && need_apk com.termux.api "$APK_DIR/termux-api.apk" || true

log "Granting permissions / background exemptions"
for pkg in com.termux com.termux.x11 com.termux.widget com.termux.api; do
  adb shell pm grant "$pkg" android.permission.POST_NOTIFICATIONS 2>/dev/null || true
  adb shell dumpsys deviceidle whitelist +"$pkg" 2>/dev/null || true
  adb shell appops set "$pkg" RUN_IN_BACKGROUND allow 2>/dev/null || true
  adb shell appops set "$pkg" RUN_ANY_IN_BACKGROUND allow 2>/dev/null || true
done
adb shell appops set com.termux.x11 SYSTEM_ALERT_WINDOW allow 2>/dev/null || true

# ---- Stage files ----
cat > "$STAGING/termux.properties" << 'PROPS'
allow-external-apps=true
use-black-ui=true
bell-character=ignore
PROPS

cat > "$STAGING/Omarchy" << 'WID'
#!/data/data/com.termux/files/usr/bin/bash
bash "$HOME/start-omarchy.sh"
WID

cat > "$STAGING/ADD-HOME-SHORTCUT.txt" << 'TXT'
Add Omarchy to your home screen:
1. Long-press home screen → Widgets
2. Find "Termux:Widget" → drag to home
3. Tap it → choose "Omarchy"

One tap opens Hyprland + foot + goose via Termux:X11.
Binds: SUPER+Return foot | SUPER+K keyboard | SUPER+G goose
TXT

cat > "$STAGING/omarchy-env" << EOF
export OMARCHY_WIDTH=${W:-1344}
export OMARCHY_HEIGHT=${H:-2992}
export OMARCHY_REFRESH=120
export OMARCHY_SCALE=${SCALE:-2.0}
EOF

cat > "$STAGING/run-setup.sh" << 'RUN'
#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME"
# shellcheck disable=SC1091
[ -f "$HOME/omarchy-env" ] && source "$HOME/omarchy-env"
exec bash "$HOME/setup-omarchy-pixel.sh" 2>&1 | tee "$HOME/omarchy-setup.log"
RUN

chmod +x "$STAGING/Omarchy" "$STAGING/run-setup.sh" "$STAGING/bootstrap-on-device.sh"
chmod +x "$SETUP_SCRIPT" "$START_SCRIPT"

log "Pushing payload to $SDCARD_DIR"
adb shell "rm -rf $SDCARD_DIR; mkdir -p $SDCARD_DIR"
adb push "$SETUP_SCRIPT" "$SDCARD_DIR/setup-omarchy-pixel.sh" | tee -a "$LOG"
adb push "$START_SCRIPT" "$SDCARD_DIR/start-omarchy.sh" | tee -a "$LOG"
adb push "$ROOT/omarchy-xstartup.sh" "$SDCARD_DIR/omarchy-xstartup.sh" | tee -a "$LOG"
adb push "$ROOT/run-fixed-launcher.sh" "$SDCARD_DIR/run-fixed-launcher.sh" | tee -a "$LOG"
adb push "$STAGING/termux.properties" "$SDCARD_DIR/termux.properties" | tee -a "$LOG"
adb push "$STAGING/Omarchy" "$SDCARD_DIR/Omarchy" | tee -a "$LOG"
adb push "$STAGING/Omarchy.sh" "$SDCARD_DIR/Omarchy.sh" | tee -a "$LOG"
adb push "$STAGING/ADD-HOME-SHORTCUT.txt" "$SDCARD_DIR/ADD-HOME-SHORTCUT.txt" | tee -a "$LOG"
adb push "$STAGING/omarchy-env" "$SDCARD_DIR/omarchy-env" | tee -a "$LOG"
adb push "$STAGING/run-setup.sh" "$SDCARD_DIR/run-setup.sh" | tee -a "$LOG"
adb push "$STAGING/bootstrap-on-device.sh" "$SDCARD_DIR/bootstrap-on-device.sh" | tee -a "$LOG"
adb shell "chmod 755 $SDCARD_DIR/*.sh $SDCARD_DIR/Omarchy 2>/dev/null; ls -la $SDCARD_DIR" | tr -d '\r' | tee -a "$LOG"

# Wake + unlock-ish
adb shell input keyevent KEYCODE_WAKEUP 2>/dev/null || true
adb shell wm dismiss-keyguard 2>/dev/null || true

launch_termux() {
  adb shell am start -n com.termux/.app.TermuxActivity >/dev/null 2>&1 || \
    adb shell am start -n com.termux/com.termux.app.TermuxActivity >/dev/null 2>&1 || \
    adb shell monkey -p com.termux -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1 || true
}

type_cmd() {
  # Type a command with spaces as %s. Avoid shell metacharacters.
  local cmd="$1"
  local encoded
  encoded="$(printf '%s' "$cmd" | sed 's/ /%s/g')"
  adb shell input text "$encoded"
  sleep 0.35
  adb shell input keyevent 66
  sleep 0.6
}

log "Opening Termux (first launch bootstraps bootstrap packages — can take a minute)"
adb shell am force-stop com.termux 2>/dev/null || true
sleep 1
launch_termux
sleep 6

# Tap center of screen a few times to dismiss "Welcome" / grant storage dialogs
# Get size for tap coords
TAP_X=$(( ${W:-1344} / 2 ))
TAP_Y=$(( ${H:-2992} * 2 / 3 ))
for _ in 1 2 3; do
  adb shell input tap "$TAP_X" "$TAP_Y" 2>/dev/null || true
  sleep 0.5
  adb shell input keyevent 66 2>/dev/null || true
  sleep 0.5
done
launch_termux
sleep 3

# Wait until Termux process is alive (proxy for bootstrap)
for i in $(seq 1 60); do
  if adb shell "pidof com.termux" 2>/dev/null | grep -qE '[0-9]'; then
    log "Termux process up (try $i)"
    break
  fi
  launch_termux
  sleep 2
done
sleep 5  # let first-run bootstrap unzip finish

# Ensure focus on Termux terminal
launch_termux
sleep 2
# Escape any menus
adb shell input keyevent 4 2>/dev/null || true
sleep 0.5
launch_termux
sleep 1

log "Injecting bootstrap (runs full setup)"
# Ctrl-C any prior line, then run
adb shell input keyevent 67 2>/dev/null || true
type_cmd "bash /sdcard/omarchy-pixel/bootstrap-on-device.sh"

# Also fire RUN_COMMAND — works once allow-external-apps is set mid-bootstrap
try_run_command() {
  adb shell am startservice --user 0 \
    -n com.termux/com.termux.app.RunCommandService \
    -a com.termux.RUN_COMMAND \
    --es com.termux.RUN_COMMAND_PATH "$TERMUX_PREFIX/bin/bash" \
    --esa com.termux.RUN_COMMAND_ARGUMENTS "-lc,bash /sdcard/omarchy-pixel/bootstrap-on-device.sh" \
    --ez com.termux.RUN_COMMAND_BACKGROUND true \
    --es com.termux.RUN_COMMAND_WORKDIR "$TERMUX_HOME" 2>&1 || true
}
try_run_command | tee -a "$LOG" || true

log "Tailing $SDCARD_DIR/omarchy-setup.log (up to 90 min)"
deadline=$((SECONDS + 5400))
last_size=0
stalls=0
kicks=0
: > "$SETUP_LOG"

while (( SECONDS < deadline )); do
  adb pull "$SDCARD_DIR/omarchy-setup.log" "$SETUP_LOG" >/dev/null 2>&1 || true
  adb pull "$SDCARD_DIR/status.txt" "$STAGING/status.txt" >/dev/null 2>&1 || true
  adb pull "$SDCARD_DIR/seed-done.txt" "$STAGING/seed-done.txt" >/dev/null 2>&1 || true

  if grep -q 'Omarchy-on-Pixel ready' "$SETUP_LOG" 2>/dev/null; then
    log "Setup finished successfully."
    break
  fi

  size=$(wc -c < "$SETUP_LOG" 2>/dev/null || echo 0)
  if [ "$size" != "$last_size" ] && [ "${size:-0}" != "0" ]; then
    stalls=0
    last_size="$size"
    echo "----- log tail ($(date +%H:%M:%S)) size=$size -----" | tee -a "$LOG"
    tail -n 15 "$SETUP_LOG" | tee -a "$LOG" || true
  else
    stalls=$((stalls + 1))
  fi

  if (( stalls > 9 && kicks < 10 )); then
    kicks=$((kicks + 1))
    log "No progress — kick #$kicks (stalls=$stalls)"
    # Keep screen awake
    adb shell input keyevent KEYCODE_WAKEUP 2>/dev/null || true
    adb shell svc power stayon true 2>/dev/null || true
    launch_termux
    sleep 1
    type_cmd "bash /sdcard/omarchy-pixel/bootstrap-on-device.sh"
    try_run_command >/dev/null || true
    stalls=0
  fi
  sleep 10
done

if grep -q 'Omarchy-on-Pixel ready' "$SETUP_LOG" 2>/dev/null; then
  log "Launching Omarchy desktop session"
  launch_termux
  sleep 1
  type_cmd "bash /data/data/com.termux/files/home/start-omarchy.sh"
  adb shell am startservice --user 0 \
    -n com.termux/com.termux.app.RunCommandService \
    -a com.termux.RUN_COMMAND \
    --es com.termux.RUN_COMMAND_PATH "$TERMUX_HOME/start-omarchy.sh" \
    --ez com.termux.RUN_COMMAND_BACKGROUND false \
    --es com.termux.RUN_COMMAND_WORKDIR "$TERMUX_HOME" 2>&1 | tee -a "$LOG" || true
  # Bring X11 to front after a few seconds
  sleep 5
  adb shell am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity >/dev/null 2>&1 || true
else
  log "Setup incomplete/timeout. Last tail:"
  tail -n 60 "$SETUP_LOG" 2>/dev/null | tee -a "$LOG" || true
  cat "$STAGING/status.txt" 2>/dev/null | tee -a "$LOG" || true
fi

log "Refreshing Termux:Widget + opening shortcut creator"
adb shell am broadcast -a com.termux.widget.ACTION_REFRESH_WIDGET 2>/dev/null || true
adb shell am start -n com.termux.widget/.TermuxCreateShortcutActivity >/dev/null 2>&1 || \
  adb shell am start -n com.termux.widget/com.termux.widget.TermuxCreateShortcutActivity >/dev/null 2>&1 || true

# Stay awake off
adb shell svc power stayon false 2>/dev/null || true

log "Host-side steps complete."
echo
echo "============================================"
echo " Phone next steps:"
echo "  1. Long-press home → Widgets → Termux:Widget → Omarchy"
echo "  2. Or Termux: ./start-omarchy.sh"
echo " Binds: SUPER+Return=foot  SUPER+K=keyboard  SUPER+G=goose"
echo " Setup log: $SETUP_LOG"
echo "============================================"
