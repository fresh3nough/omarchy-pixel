#!/data/data/com.termux/files/usr/bin/bash
# Termux BOOT_COMPLETED hook: start the Pixel Omarchy desktop automatically.
set +e
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
HOME="${HOME:-/data/data/com.termux/files/home}"
export PREFIX HOME PATH="$PREFIX/bin:$PATH"
LOG=/sdcard/omarchy-pixel/boot.log
mkdir -p /sdcard/omarchy-pixel "$HOME/.termux/boot"

{
  echo "BOOT $(date -Iseconds)"
  # Give Android storage, PackageManager, and Termux:X11 time to settle.
  sleep "${OMARCHY_BOOT_DELAY:-12}"

  if [[ -x "$HOME/configure-termux-x11.sh" ]]; then
    "$HOME/configure-termux-x11.sh"
  fi

  if [[ -x "$HOME/start-omarchy-fullscreen.sh" ]]; then
    exec "$HOME/start-omarchy-fullscreen.sh"
  fi

  echo "Omarchy launcher is missing: $HOME/start-omarchy-fullscreen.sh"
} >>"$LOG" 2>&1
