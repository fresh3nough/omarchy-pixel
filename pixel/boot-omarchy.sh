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

# Ensure launcher shortcuts are available after boot
if [ ! -f "$HOME/.shortcuts/Omarchy.sh" ] && [ -f "/sdcard/omarchy-pixel/Omarchy.sh" ]; then
  mkdir -p "$HOME/.shortcuts"
  cp -f "/sdcard/omarchy-pixel/Omarchy.sh" "$HOME/.shortcuts/Omarchy.sh"
  chmod 755 "$HOME/.shortcuts/Omarchy.sh"
fi

# Ensure home launcher exists
if [ ! -f "$HOME/start-omarchy-fullscreen.sh" ] && [ -f "/sdcard/omarchy-pixel/start-omarchy-fullscreen.sh" ]; then
  cp -f "/sdcard/omarchy-pixel/start-omarchy-fullscreen.sh" "$HOME/"
  chmod 755 "$HOME/start-omarchy-fullscreen.sh"
fi

# Restore homescreen shortcut after device boot
# The APK should be installed already, but the shortcut might be cleared
if command -v am &>/dev/null; then
  am broadcast \
    -a com.android.launcher.action.INSTALL_SHORTCUT \
    --es android.intent.extra.shortcut.NAME "Omarchy" \
    --es android.intent.extra.shortcut.INTENT "intent:#Intent;action=android.intent.action.MAIN;component=com.omarchy.launcher/.MainActivity;end" \
    --es android.intent.extra.shortcut.ICON_RESOURCE.PACKAGE com.omarchy.launcher \
    --es android.intent.extra.shortcut.ICON_RESOURCE.RESOURCE_NAME omarchy_icon \
    --ez duplicate false \
    2>/dev/null || true
fi
