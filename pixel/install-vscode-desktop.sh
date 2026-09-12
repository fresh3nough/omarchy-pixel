#!/bin/bash
# Install official Visual Studio Code (aarch64) into Arch proot under
# ~/.local/share/VSCode-linux-arm64 and wire omarchy-code launcher.
set -euo pipefail
export PATH="${HOME:-/home/cody}/.local/bin:/usr/local/bin:/usr/bin:$PATH"
HOME="${HOME:-/home/cody}"
DEST="$HOME/.local/share/VSCode-linux-arm64"
TGZ="${1:-}"

if [[ -z $TGZ ]]; then
  for c in \
    "$HOME/code-stable-arm64.tar.gz" \
    /sdcard/omarchy-pixel/code-stable-arm64.tar.gz \
    /tmp/code-stable-arm64.tar.gz \
    ./code-stable-arm64.tar.gz
  do
    [[ -f $c ]] && TGZ=$c && break
  done
fi

if [[ -z ${TGZ:-} || ! -f $TGZ ]]; then
  echo "Downloading Visual Studio Code aarch64 tarball..."
  mkdir -p /tmp
  curl -fL -o /tmp/code-stable-arm64.tar.gz \
    "https://code.visualstudio.com/sha/download?build=stable&os=linux-arm64"
  TGZ=/tmp/code-stable-arm64.tar.gz
fi

echo "Using $TGZ"
rm -rf /tmp/vscode-extract
mkdir -p /tmp/vscode-extract
tar -xzf "$TGZ" -C /tmp/vscode-extract
SRC=$(find /tmp/vscode-extract -maxdepth 3 -type f -path '*/bin/code' | head -1 | xargs dirname | xargs dirname)
[[ -n $SRC && -d $SRC ]] || { echo "failed to locate VS Code tree in archive" >&2; exit 1; }
echo "SRC=$SRC"
rm -rf "$DEST"
mkdir -p "$(dirname "$DEST")"
mv "$SRC" "$DEST"
rm -rf /tmp/vscode-extract

install -d "$HOME/.local/bin" "$HOME/.local/share/applications" "$HOME/.config/Code/User" "$HOME/.vscode"
if [[ -f ${0%/*}/omarchy-code ]]; then
  install -m 0755 "${0%/*}/omarchy-code" "$HOME/.local/bin/omarchy-code"
elif [[ -f $HOME/github/omarchy-rice/pixel/omarchy-code ]]; then
  install -m 0755 "$HOME/github/omarchy-rice/pixel/omarchy-code" "$HOME/.local/bin/omarchy-code"
fi

if [[ ! -f $HOME/.config/Code/User/settings.json ]]; then
  printf '{\n  "update.mode": "none",\n  "window.titleBarStyle": "custom",\n  "security.workspace.trust.enabled": false\n}\n' \
    >"$HOME/.config/Code/User/settings.json"
fi

cat > "$HOME/.local/share/applications/code.desktop" << DESK
[Desktop Entry]
Name=Visual Studio Code
Comment=Code Editing. Redefined.
Exec=$HOME/.local/bin/omarchy-code %F
Icon=$DEST/resources/app/resources/linux/code.png
Type=Application
Categories=Development;IDE;TextEditor;
Terminal=false
StartupWMClass=Code
MimeType=text/plain;inode/directory;
DESK

echo "VS Code installed: $($DEST/bin/code --version | head -1)"
echo "Launcher: $HOME/.local/bin/omarchy-code"
