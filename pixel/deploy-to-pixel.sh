#!/usr/bin/env bash
# Deploy Omarchy rice configs to Pixel over ADB and relaunch landscape desktop.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$ROOT/.." && pwd)"
SD=/sdcard/omarchy-pixel
SD_RICE=/sdcard/omarchy-rice

need_adb() {
  adb get-state 2>/dev/null | grep -q device || {
    echo "ADB device not ready — restarting server..."
    adb kill-server 2>/dev/null || true
    sudo adb start-server
    sleep 1
  }
  adb get-state 2>/dev/null | grep -q device || {
    echo "ERROR: no adb device" >&2
    exit 1
  }
  echo "device: $(adb shell getprop ro.product.model)"
}

echo "=== deploy Omarchy Pixel rice ==="
need_adb

# Push assets
adb shell "mkdir -p $SD/backgrounds $SD_RICE/pixel"
adb push "$ROOT/1-quattro.jpg" "$SD/backgrounds/1-quattro.jpg" >/dev/null
adb push "$ROOT/sway-config" "$SD/sway-config" >/dev/null
adb push "$ROOT/foot.ini" "$SD/foot.ini" >/dev/null
adb push "$ROOT/waybar-config.json" "$SD/waybar-config.json" >/dev/null
adb push "$ROOT/waybar-style.css" "$SD/waybar-style.css" >/dev/null
adb push "$ROOT/omarchy-wallpaper" "$SD/omarchy-wallpaper" >/dev/null
adb push "$ROOT/start-omarchy-fullscreen.sh" "$SD/start-omarchy-fullscreen.sh" >/dev/null
adb push "$ROOT/Omarchy.sh" "$SD/Omarchy.sh" >/dev/null
adb push "$ROOT/omarchy-chromium" "$SD/omarchy-chromium" >/dev/null
adb push "$ROOT/omarchy-goose" "$SD/omarchy-goose" >/dev/null
adb push "$ROOT/omarchy-start-apps" "$SD/omarchy-start-apps" >/dev/null
adb push "$ROOT/install-1password-desktop.sh" "$SD/install-1password-desktop.sh" >/dev/null
adb push "$ROOT/install-bwrap-stub.sh" "$SD/install-bwrap-stub.sh" >/dev/null
adb push "$ROOT/sway-config" "$SD_RICE/pixel/sway-config" >/dev/null
adb push "$ROOT/foot.ini" "$SD_RICE/pixel/foot.ini" >/dev/null
adb push "$ROOT/waybar-config.json" "$SD_RICE/pixel/waybar-config.json" >/dev/null
adb push "$ROOT/waybar-style.css" "$SD_RICE/pixel/waybar-style.css" >/dev/null
adb push "$ROOT/omarchy-wallpaper" "$SD_RICE/pixel/omarchy-wallpaper" >/dev/null
adb push "$ROOT/start-omarchy-fullscreen.sh" "$SD_RICE/pixel/start-omarchy-fullscreen.sh" >/dev/null
adb push "$ROOT/Omarchy.sh" "$SD_RICE/pixel/Omarchy.sh" >/dev/null
adb push "$ROOT/omarchy-chromium" "$SD_RICE/pixel/omarchy-chromium" >/dev/null
adb push "$ROOT/omarchy-goose" "$SD_RICE/pixel/omarchy-goose" >/dev/null
adb push "$ROOT/omarchy-start-apps" "$SD_RICE/pixel/omarchy-start-apps" >/dev/null
adb push "$ROOT/install-1password-desktop.sh" "$SD_RICE/pixel/install-1password-desktop.sh" >/dev/null
# Also keep install-pixel available
if [ -f "$REPO/install-pixel.sh" ]; then
  adb push "$REPO/install-pixel.sh" "$SD_RICE/install-pixel.sh" >/dev/null
fi

# On-device apply script (runs via Termux RUN_COMMAND or app_process free shell via am)
cat > /tmp/omarchy-apply-on-device.sh <<'APPLY'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
export PATH=/data/data/com.termux/files/usr/bin:$PATH
SD=/sdcard/omarchy-pixel
HOME_DIR=/data/data/com.termux/files/home
LOG=$SD/deploy-apply.log
: > "$LOG"
exec > >(tee -a "$LOG") 2>&1
echo "APPLY_START $(date -Iseconds)"

mkdir -p "$HOME_DIR/.shortcuts" "$HOME_DIR/.local/bin" 2>/dev/null || true
cp -f "$SD/start-omarchy-fullscreen.sh" "$HOME_DIR/start-omarchy-fullscreen.sh"
cp -f "$SD/start-omarchy-fullscreen.sh" "$HOME_DIR/start-omarchy.sh"
cp -f "$SD/start-omarchy-fullscreen.sh" "$HOME_DIR/.shortcuts/Omarchy"
cp -f "$SD/start-omarchy-fullscreen.sh" "$HOME_DIR/.shortcuts/Omarchy.sh"
# widget-friendly short launcher
cat > "$HOME_DIR/.shortcuts/Omarchy" <<'SC'
#!/data/data/com.termux/files/usr/bin/bash
exec bash /data/data/com.termux/files/home/start-omarchy-fullscreen.sh
SC
chmod 755 "$HOME_DIR/start-omarchy-fullscreen.sh" "$HOME_DIR/start-omarchy.sh" \
  "$HOME_DIR/.shortcuts/Omarchy" "$HOME_DIR/.shortcuts/Omarchy.sh" \
  "$SD/start-omarchy-fullscreen.sh" "$SD/omarchy-wallpaper"

# Apply inside Arch proot as cody
proot-distro login archlinux --user cody --shared-tmp -- bash -lc '
set -euo pipefail
export HOME=/home/cody
export PATH=$HOME/.local/bin:/usr/bin:$PATH
SD=/sdcard/omarchy-pixel
mkdir -p ~/.config/sway ~/.config/foot ~/.config/waybar \
  ~/.local/bin ~/.local/share/omarchy-pixel/backgrounds

# Wallpaper assets
cp -f $SD/backgrounds/1-quattro.jpg ~/.local/share/omarchy-pixel/backgrounds/1-quattro.jpg
ln -sfn ~/.local/share/omarchy-pixel/backgrounds/1-quattro.jpg ~/.local/share/omarchy-pixel/background.jpg
# PNG fallback (smaller for soft renderers)
if command -v magick >/dev/null 2>&1; then
  magick ~/.local/share/omarchy-pixel/backgrounds/1-quattro.jpg -resize 1920x1080 \
    ~/.local/share/omarchy-pixel/background.png || true
elif command -v convert >/dev/null 2>&1; then
  convert ~/.local/share/omarchy-pixel/backgrounds/1-quattro.jpg -resize 1920x1080 \
    ~/.local/share/omarchy-pixel/background.png || true
elif [ ! -f ~/.local/share/omarchy-pixel/background.png ]; then
  cp -f ~/.local/share/omarchy-pixel/backgrounds/1-quattro.jpg \
    ~/.local/share/omarchy-pixel/background.png || true
fi

install -m 0644 $SD/sway-config ~/.config/sway/config
install -m 0644 $SD/foot.ini ~/.config/foot/foot.ini
# Also write colors-dark twin for older foot builds
if ! foot --config=/dev/null -c ~/.config/foot/foot.ini -e true 2>/dev/null; then
  :
fi
# Dual section foot config for max compatibility
cat > ~/.config/foot/foot.ini << "FOOT"
[main]
term=xterm-256color
font=DejaVu Sans Mono:size=13
pad=10x10
login-shell=yes
dpi-aware=yes

[colors]
alpha=1.0
foreground=a9b1d6
background=1a1b26
selection-foreground=c0caf5
selection-background=292e42
urls=7aa2f7
regular0=1a1b26
regular1=f7768e
regular2=9ece6a
regular3=e0af68
regular4=7aa2f7
regular5=ad8ee6
regular6=449dab
regular7=a9b1d6
bright0=414868
bright1=ff7a93
bright2=b9f27c
bright3=ff9e64
bright4=7da6ff
bright5=bb9af7
bright6=0db9d7
bright7=c0caf5

[cursor]
color=1a1b26 c0caf5
style=block
blink=no
FOOT

install -m 0644 $SD/waybar-config.json ~/.config/waybar/config
install -m 0644 $SD/waybar-style.css ~/.config/waybar/style.css
install -m 0755 $SD/omarchy-wallpaper ~/.local/bin/omarchy-wallpaper
install -m 0755 $SD/omarchy-chromium ~/.local/bin/omarchy-chromium 2>/dev/null || true
install -m 0755 $SD/omarchy-goose ~/.local/bin/omarchy-goose 2>/dev/null || true
install -m 0755 $SD/omarchy-start-apps ~/.local/bin/omarchy-start-apps 2>/dev/null || true
# 1password wrapper only if desktop binary present
if [ -x /opt/1Password/1password ] && [ ! -x ~/.local/bin/1password ]; then
  cat > ~/.local/bin/1password << "WRAP"
#!/bin/bash
export DISPLAY="${DISPLAY:-:0}" LIBGL_ALWAYS_SOFTWARE=1 ELECTRON_OZONE_PLATFORM_HINT=x11
cd /opt/1Password
exec ./1password --no-sandbox --disable-gpu --disable-gpu-compositing --disable-gpu-sandbox --disable-dev-shm-usage --ozone-platform=x11 --in-process-gpu "$@"
WRAP
  chmod 755 ~/.local/bin/1password
fi


# Session launcher
cat > ~/.local/bin/omarchy-session << "SESS"
#!/bin/bash
export DISPLAY="${DISPLAY:-:0}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
export XDG_SESSION_TYPE=wayland
export PULSE_SERVER="${PULSE_SERVER:-tcp:127.0.0.1}"
export PATH="$HOME/.local/bin:/usr/bin:$PATH"
export LANG=C.UTF-8 LC_ALL=C.UTF-8
export GLYCIN_DISABLE_SANDBOX=1
export BUBBLEWRAP_SKIP=1
unset WAYLAND_DISPLAY
export WLR_BACKENDS=x11
export WLR_NO_HARDWARE_CURSORS=1
# Software render avoids DRI3/DRM permission failures under proot
export WLR_RENDERER="${WLR_RENDERER:-pixman}"
export LIBGL_ALWAYS_SOFTWARE=1
mkdir -p "$XDG_RUNTIME_DIR" /tmp
cd "$HOME"
# Ensure configs present
[ -f "$HOME/.config/sway/config" ] || true
if command -v sway >/dev/null 2>&1; then
  export XDG_CURRENT_DESKTOP=sway
  exec sway -d 2>>/sdcard/omarchy-pixel/sway-debug.log
fi
if command -v Hyprland >/dev/null 2>&1; then
  export XDG_CURRENT_DESKTOP=Hyprland
  exec Hyprland
fi
exec foot
SESS
chmod +x ~/.local/bin/omarchy-session ~/.local/bin/omarchy-wallpaper

# Ensure wallpaper tools
sudo pacman --disable-sandbox -S --noconfirm --needed swaybg feh waybar foot 2>&1 | tail -20 || true

echo "--- verify ---"
ls -la ~/.config/sway/config ~/.config/foot/foot.ini ~/.config/waybar/config ~/.config/waybar/style.css
ls -la ~/.local/bin/omarchy-session ~/.local/bin/omarchy-wallpaper
ls -lh ~/.local/share/omarchy-pixel/backgrounds/1-quattro.jpg ~/.local/share/omarchy-pixel/background.png || true
foot --version || true
sway -v || true
waybar --version || true
test -f ~/.local/share/omarchy-pixel/backgrounds/1-quattro.jpg && echo BG_OK || echo BG_MISSING
'
echo "APPLY_DONE $(date -Iseconds)"
APPLY

adb push /tmp/omarchy-apply-on-device.sh "$SD/apply-landscape.sh" >/dev/null
adb shell chmod 755 "$SD/apply-landscape.sh" "$SD/start-omarchy-fullscreen.sh" "$SD/omarchy-wallpaper"

# Run apply via Termux (non-debuggable — use am start service RUN_COMMAND)
echo "Running apply via Termux..."
adb shell am startservice \
  -n com.termux/.app.RunCommandService \
  -a com.termux.RUN_COMMAND \
  --es com.termux.RUN_COMMAND_PATH /data/data/com.termux/files/usr/bin/bash \
  --esa com.termux.RUN_COMMAND_ARGUMENTS "-lc,/sdcard/omarchy-pixel/apply-landscape.sh" \
  --ez com.termux.RUN_COMMAND_BACKGROUND true \
  --es com.termux.RUN_COMMAND_WORKDIR /data/data/com.termux/files/home \
  >/dev/null 2>&1 || true

# Fallback: try app_process free form via termux-tasker style
sleep 2
# Poll for apply log
for i in $(seq 1 40); do
  if adb shell "grep -q APPLY_DONE $SD/deploy-apply.log 2>/dev/null"; then
    echo "apply finished"
    break
  fi
  sleep 1
done
adb shell "tail -80 $SD/deploy-apply.log 2>/dev/null || echo 'apply log missing — will try alternate launch'"

echo "=== force landscape + launch desktop ==="
# Landscape lock
adb shell settings put system accelerometer_rotation 0
adb shell settings put system user_rotation 1
adb shell wm user-rotation lock 1 2>/dev/null || adb shell wm user-rotation 1 2>/dev/null || true

# Kill old session bits
adb shell "am force-stop com.termux.x11" 2>/dev/null || true
sleep 0.5

adb shell am startservice \
  -n com.termux/.app.RunCommandService \
  -a com.termux.RUN_COMMAND \
  --es com.termux.RUN_COMMAND_PATH /data/data/com.termux/files/usr/bin/bash \
  --esa com.termux.RUN_COMMAND_ARGUMENTS "-lc,/sdcard/omarchy-pixel/start-omarchy-fullscreen.sh" \
  --ez com.termux.RUN_COMMAND_BACKGROUND true \
  --es com.termux.RUN_COMMAND_WORKDIR /data/data/com.termux/files/home \
  >/dev/null 2>&1 || true

echo "waiting for sway..."
for i in $(seq 1 45); do
  if adb shell "ps -A 2>/dev/null | grep -E ' [Ss]way$| sway '" | grep -qv grep; then
    echo "sway is up"
    break
  fi
  sleep 1
done
sleep 3
adb shell "ps -A -o pid,comm,args 2>/dev/null | grep -Ei 'termux-x11|sway|foot|waybar|swaybg|feh|proot' | grep -v grep | head -40"
adb shell "tail -40 $SD/termux-x11.log 2>/dev/null || true"
echo "=== deploy script done ==="
