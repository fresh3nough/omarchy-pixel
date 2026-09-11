#!/usr/bin/env bash
# Install official 1Password desktop app (aarch64) into Arch proot.
# Usage (inside Arch as cody, or via proot-distro):
#   bash install-1password-desktop.sh [/path/to/1password-latest.tar.gz]
set -euo pipefail
export PATH="${HOME:-/home/cody}/.local/bin:/usr/local/bin:/usr/bin:$PATH"
TGZ="${1:-}"
if [ -z "$TGZ" ]; then
  for c in \
    "$HOME/1password-latest.tar.gz" \
    /data/data/com.termux/files/home/1password-latest.tar.gz \
    /sdcard/omarchy-pixel/1password-latest.tar.gz \
    ./1password-latest.tar.gz
  do
    [ -f "$c" ] && TGZ=$c && break
  done
fi
if [ -z "${TGZ:-}" ] || [ ! -f "$TGZ" ]; then
  echo "Downloading 1Password aarch64 desktop tarball..."
  curl -fL -o /tmp/1password-latest.tar.gz \
    https://downloads.1password.com/linux/tar/stable/aarch64/1password-latest.tar.gz
  TGZ=/tmp/1password-latest.tar.gz
fi
echo "Using $TGZ"
rm -rf /tmp/1p-extract
mkdir -p /tmp/1p-extract
tar -xf "$TGZ" -C /tmp/1p-extract
SRC=$(find /tmp/1p-extract -maxdepth 2 -type f -name 1password | head -1 | xargs dirname)
echo "SRC=$SRC"
sudo mkdir -p /opt/1Password
sudo rm -rf /opt/1Password/*
sudo cp -a "$SRC"/. /opt/1Password/
if [ -f /opt/1Password/after-install.sh ]; then
  sudo sed -i 's/systemctl/#systemctl/g' /opt/1Password/after-install.sh || true
  sudo bash /opt/1Password/after-install.sh || true
fi
sudo ln -sfn /opt/1Password/1password /usr/local/bin/1password-bin
install -d "$HOME/.local/bin" "$HOME/.local/share/applications"
cat > "$HOME/.local/bin/1password" << 'WRAP'
#!/bin/bash
# Omarchy Pixel — 1Password desktop (Electron) under Termux:X11 / proot
export DISPLAY="${DISPLAY:-:0}"
export LIBGL_ALWAYS_SOFTWARE=1
export ELECTRON_OZONE_PLATFORM_HINT=x11
export PATH="${HOME:-/home/cody}/.local/bin:/opt/1Password:/usr/bin:$PATH"
cd /opt/1Password
exec ./1password \
  --no-sandbox \
  --disable-gpu \
  --disable-gpu-compositing \
  --disable-gpu-sandbox \
  --disable-dev-shm-usage \
  --ozone-platform=x11 \
  --in-process-gpu \
  "$@"
WRAP
chmod 755 "$HOME/.local/bin/1password"
ICON=/opt/1Password/resources/icons/hicolor/256x256/apps/1password.png
[ -f "$ICON" ] || ICON=1password
cat > "$HOME/.local/share/applications/1password.desktop" << DESK
[Desktop Entry]
Name=1Password
Exec=$HOME/.local/bin/1password %U
Icon=$ICON
Type=Application
Categories=Utility;Security;
Terminal=false
StartupWMClass=1Password
DESK
echo "1Password desktop installed: $(ls -la /opt/1Password/1password)"
