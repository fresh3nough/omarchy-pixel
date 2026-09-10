#!/data/data/com.termux/files/usr/bin/bash
# Optional -xstartup helper. Prefer start-omarchy.sh two-step launch.
set -euo pipefail
PREFIX=/data/data/com.termux/files/usr
export PATH="$PREFIX/bin:$PATH"
sleep 1
exec proot-distro login archlinux \
  --user cody \
  --shared-tmp \
  -- env DISPLAY=:0 \
       XDG_RUNTIME_DIR=/tmp \
       HOME=/home/cody \
       PULSE_SERVER=tcp:127.0.0.1 \
       WLR_BACKENDS=x11 \
       WLR_NO_HARDWARE_CURSORS=1 \
       /home/cody/.local/bin/omarchy-session
