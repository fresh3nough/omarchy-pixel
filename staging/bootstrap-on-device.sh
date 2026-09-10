#!/data/data/com.termux/files/usr/bin/bash
# Runs inside Termux. Seeds home, enables external apps, starts Omarchy setup.
set -euo pipefail

SRC="${1:-/sdcard/omarchy-pixel}"
HOME_DIR="${HOME:-/data/data/com.termux/files/home}"
mkdir -p /sdcard/omarchy-pixel
echo "BOOTSTRAP_ENTER $(date -Iseconds 2>/dev/null || date)" > /sdcard/omarchy-pixel/status.txt
cd "$HOME_DIR"
mkdir -p "$HOME_DIR" "$HOME_DIR/.termux" "$HOME_DIR/.shortcuts" "$HOME_DIR/bin"

cp -f "$SRC/setup-omarchy-pixel.sh" "$HOME_DIR/"
cp -f "$SRC/start-omarchy.sh" "$HOME_DIR/"
cp -f "$SRC/run-setup.sh" "$HOME_DIR/" 2>/dev/null || true
cp -f "$SRC/omarchy-env" "$HOME_DIR/" 2>/dev/null || true
cp -f "$SRC/ADD-HOME-SHORTCUT.txt" "$HOME_DIR/" 2>/dev/null || true
cp -f "$SRC/omarchy-xstartup.sh" "$HOME_DIR/" 2>/dev/null || true
cp -f "$SRC/run-fixed-launcher.sh" "$HOME_DIR/" 2>/dev/null || true
# Widget + RUN_COMMAND entry points (MainActivity looks for Omarchy.sh)
if [ -f "$SRC/Omarchy.sh" ]; then
  cp -f "$SRC/Omarchy.sh" "$HOME_DIR/.shortcuts/Omarchy"
  cp -f "$SRC/Omarchy.sh" "$HOME_DIR/.shortcuts/Omarchy.sh"
elif [ -f "$SRC/Omarchy" ]; then
  cp -f "$SRC/Omarchy" "$HOME_DIR/.shortcuts/Omarchy"
  cp -f "$SRC/Omarchy" "$HOME_DIR/.shortcuts/Omarchy.sh"
fi
cp -f "$SRC/termux.properties" "$HOME_DIR/.termux/termux.properties" 2>/dev/null || true
echo "COPIED_SCRIPTS $(date -Iseconds 2>/dev/null || date)" >> /sdcard/omarchy-pixel/status.txt

# Ensure allow-external-apps
if ! grep -q 'allow-external-apps=true' "$HOME_DIR/.termux/termux.properties" 2>/dev/null; then
  echo 'allow-external-apps=true' >> "$HOME_DIR/.termux/termux.properties"
fi

chmod 755 "$HOME_DIR/setup-omarchy-pixel.sh" \
          "$HOME_DIR/start-omarchy.sh" \
          "$HOME_DIR/run-setup.sh" 2>/dev/null || true
chmod 755 "$HOME_DIR/omarchy-xstartup.sh" 2>/dev/null || true
chmod 755 "$HOME_DIR/run-fixed-launcher.sh" 2>/dev/null || true
chmod 755 "$HOME_DIR/.shortcuts/Omarchy" "$HOME_DIR/.shortcuts/Omarchy.sh" 2>/dev/null || true

# Live-mirror log to sdcard for host tailing
mkdir -p /sdcard/omarchy-pixel
(
  while true; do
    cp -f "$HOME_DIR/omarchy-setup.log" /sdcard/omarchy-pixel/omarchy-setup.log 2>/dev/null || true
    cp -f "$HOME_DIR/seed-done.txt" /sdcard/omarchy-pixel/seed-done.txt 2>/dev/null || true
    sleep 4
  done
) &
echo $! > /sdcard/omarchy-pixel/mirror.pid

echo "SEED_DONE $(date -Iseconds)" | tee "$HOME_DIR/seed-done.txt" /sdcard/omarchy-pixel/seed-done.txt

# Single-flight setup
exec 9>"$HOME_DIR/.setup-lock"
HAVE_LOCK=1
if command -v flock >/dev/null 2>&1; then
  flock -n 9 || HAVE_LOCK=0
elif [ -f "$HOME_DIR/.setup-running" ]; then
  # stale lock older than 3h is ignored
  if [ -n "$(find "$HOME_DIR/.setup-running" -mmin -180 2>/dev/null)" ]; then
    HAVE_LOCK=0
  fi
fi
if [ "$HAVE_LOCK" = "1" ]; then
  touch "$HOME_DIR/.setup-running"
  # shellcheck disable=SC1091
  [ -f "$HOME_DIR/omarchy-env" ] && source "$HOME_DIR/omarchy-env"
  echo "SETUP_START $(date -Iseconds)" | tee -a /sdcard/omarchy-pixel/status.txt
  bash "$HOME_DIR/setup-omarchy-pixel.sh" 2>&1 | tee "$HOME_DIR/omarchy-setup.log" /sdcard/omarchy-pixel/omarchy-setup.log
  touch "$HOME_DIR/.omarchy-installed"
  rm -f "$HOME_DIR/.setup-running"
  echo "SETUP_DONE $(date -Iseconds)" | tee -a /sdcard/omarchy-pixel/status.txt
  bash "$HOME_DIR/start-omarchy.sh" | tee -a /sdcard/omarchy-pixel/launch.log || true
else
  echo "Setup already running" | tee -a /sdcard/omarchy-pixel/status.txt
  exit 0
fi
