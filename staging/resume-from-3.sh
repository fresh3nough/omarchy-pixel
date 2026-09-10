#!/data/data/com.termux/files/usr/bin/bash
# Resume setup after Arch rootfs is already installed (skip steps 1-2).
set -euo pipefail
export PATH="/data/data/com.termux/files/usr/bin:$PATH"
export HOME="${HOME:-/data/data/com.termux/files/home}"
export PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
SRC=/sdcard/omarchy-pixel
LOG="$SRC/omarchy-setup.log"
cp -f "$SRC/setup-omarchy-pixel.sh" "$HOME/setup-omarchy-pixel.sh"
chmod 755 "$HOME/setup-omarchy-pixel.sh" "$SRC/setup-omarchy-pixel.sh"
echo "RESUME_FROM_3 $(date -Iseconds)" | tee -a "$SRC/status.txt"

# Verify arch is reachable
if ! proot-distro login archlinux -- true; then
  echo "ERROR: archlinux not login-able" | tee -a "$SRC/status.txt" "$LOG"
  proot-distro list 2>&1 | tee -a "$LOG" || true
  ls -la "$PREFIX/var/lib/proot-distro/installed-rootfs" 2>&1 | tee -a "$LOG" || true
  exit 1
fi
echo "ARCH_OK $(date -Iseconds)" | tee -a "$SRC/status.txt"

# Run full setup; step 2 will skip because arch_installed succeeds
bash "$HOME/setup-omarchy-pixel.sh" 2>&1 | tee -a "$HOME/omarchy-setup.log" "$LOG"
echo "SETUP_DONE $(date -Iseconds)" | tee -a "$SRC/status.txt"
bash "$HOME/start-omarchy.sh" 2>&1 | tee -a "$SRC/launch.log" || true
