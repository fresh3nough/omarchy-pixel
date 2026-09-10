#!/data/data/com.termux/files/usr/bin/bash
# Clear stale locks and re-run bootstrap with latest scripts from /sdcard
set -e
HOME_DIR="${HOME:-/data/data/com.termux/files/home}"
rm -f "$HOME_DIR/.setup-running" "$HOME_DIR/.setup-lock"
# Stop prior setup children if any (not the login shell)
pkill -f 'setup-omarchy-pixel' 2>/dev/null || true
pkill -f 'run-setup' 2>/dev/null || true
sleep 1
exec bash /sdcard/omarchy-pixel/bootstrap-on-device.sh
