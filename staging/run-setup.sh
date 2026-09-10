#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME"
# shellcheck disable=SC1091
[ -f "$HOME/omarchy-env" ] && source "$HOME/omarchy-env"
exec bash "$HOME/setup-omarchy-pixel.sh" 2>&1 | tee "$HOME/omarchy-setup.log"
