#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
export PATH="${PREFIX:-/data/data/com.termux/files/usr}/bin:$PATH"
HOME_DIR="${HOME:-/data/data/com.termux/files/home}"
SD=/sdcard/omarchy-pixel
LOG=$SD/fix-session.log
exec > >(tee -a "$LOG") 2>&1
echo "FIX_START $(date -Iseconds)"

mkdir -p "$HOME_DIR/.shortcuts" "$HOME_DIR/.termux/boot" "$HOME_DIR/.local/bin"

# Prefer fullscreen launcher
cp -f "$SD/start-omarchy-fullscreen.sh" "$HOME_DIR/start-omarchy-fullscreen.sh"
cp -f "$SD/start-omarchy-fullscreen.sh" "$HOME_DIR/start-omarchy.sh"
cp -f "$SD/configure-termux-x11.sh" "$HOME_DIR/configure-termux-x11.sh" 2>/dev/null || true
cp -f "$SD/boot-omarchy.sh" "$HOME_DIR/.termux/boot/00-omarchy.sh" 2>/dev/null || true
chmod 755 "$HOME_DIR/start-omarchy-fullscreen.sh" "$HOME_DIR/start-omarchy.sh" \
  "$HOME_DIR/configure-termux-x11.sh" "$HOME_DIR/.termux/boot/00-omarchy.sh" 2>/dev/null || true

# Widget shortcut
cat > "$HOME_DIR/.shortcuts/Omarchy" << 'SC'
#!/data/data/com.termux/files/usr/bin/bash
export PATH="${PREFIX:-/data/data/com.termux/files/usr}/bin:$PATH"
H="${HOME:-/data/data/com.termux/files/home}"
if [ -x "$H/start-omarchy-fullscreen.sh" ]; then
  exec bash "$H/start-omarchy-fullscreen.sh"
fi
exec bash /sdcard/omarchy-pixel/start-omarchy-fullscreen.sh
SC
cp -f "$HOME_DIR/.shortcuts/Omarchy" "$HOME_DIR/.shortcuts/Omarchy.sh"
cp -f "$HOME_DIR/.shortcuts/Omarchy" "$HOME_DIR/Omarchy.sh"
chmod 755 "$HOME_DIR/.shortcuts/Omarchy" "$HOME_DIR/.shortcuts/Omarchy.sh" "$HOME_DIR/Omarchy.sh"

# allow external apps for RUN_COMMAND / widget / launcher APK
mkdir -p "$HOME_DIR/.termux"
grep -q 'allow-external-apps=true' "$HOME_DIR/.termux/termux.properties" 2>/dev/null \
  || echo 'allow-external-apps=true' >> "$HOME_DIR/.termux/termux.properties"

# Fix omarchy-session inside Arch: prefer sway (hyprland fails under proot X11)
proot-distro login archlinux -- bash -lc '
set -euo pipefail
# ensure cody user
if ! id cody >/dev/null 2>&1; then
  useradd -m -G wheel -s /bin/bash cody || true
fi
echo "cody ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/cody
chmod 440 /etc/sudoers.d/cody

# Install sway stack if missing
pacman --disable-sandbox -Sy --noconfirm 2>/dev/null || true
pacman --disable-sandbox -S --noconfirm --needed \
  sway waybar swaybg foot wlr-randr wl-clipboard grim slurp \
  mesa libxkbcommon wayland xorg-xwayland 2>/dev/null \
  || pacman --disable-sandbox -S --noconfirm --needed sway waybar foot 2>/dev/null || true

install -d -o cody -g cody /home/cody/.local/bin /home/cody/.config/sway \
  /home/cody/.config/foot /home/cody/.config/waybar \
  /home/cody/.local/share/omarchy-pixel/backgrounds

# Session launcher: sway first (hyprland dies under proot)
cat > /home/cody/.local/bin/omarchy-session << "SESS"
#!/usr/bin/env bash
set +e
export HOME=/home/cody
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/runtime-cody}"
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"
export XDG_CURRENT_DESKTOP=sway
export WLR_BACKENDS="${WLR_BACKENDS:-x11}"
export WLR_RENDERER="${WLR_RENDERER:-pixman}"
export WLR_NO_HARDWARE_CURSORS=1
export LIBGL_ALWAYS_SOFTWARE=1
export MOZ_ENABLE_WAYLAND=0
cd "$HOME"
if command -v sway >/dev/null 2>&1; then
  echo "Starting sway session" >&2
  exec sway -d
fi
if command -v Hyprland >/dev/null 2>&1; then
  echo "Fallback Hyprland" >&2
  exec Hyprland
fi
if command -v hyprland >/dev/null 2>&1; then
  exec hyprland
fi
echo "No compositor found" >&2
sleep 30
SESS
chmod 755 /home/cody/.local/bin/omarchy-session
chown cody:cody /home/cody/.local/bin/omarchy-session

# Apply pixel sway config if present
SD=/sdcard/omarchy-pixel
if [ -f "$SD/sway-config" ]; then
  install -m 0644 -o cody -g cody "$SD/sway-config" /home/cody/.config/sway/config
else
  cat > /home/cody/.config/sway/config << "SWAY"
set $mod Mod4
output * bg #1a1b26 solid_color
default_border pixel 2
font pango:monospace 11
bindsym $mod+Return exec foot
bindsym $mod+Shift+q kill
bindsym $mod+Shift+e exit
bindsym $mod+d exec foot -e bash -lc "ls"
bindsym $mod+k exec foot
exec_always waybar
exec foot
SWAY
  chown cody:cody /home/cody/.config/sway/config
fi

[ -f "$SD/foot.ini" ] && install -m 0644 -o cody -g cody "$SD/foot.ini" /home/cody/.config/foot/foot.ini || true
[ -f "$SD/waybar-config.json" ] && install -m 0644 -o cody -g cody "$SD/waybar-config.json" /home/cody/.config/waybar/config || true
[ -f "$SD/waybar-style.css" ] && install -m 0644 -o cody -g cody "$SD/waybar-style.css" /home/cody/.config/waybar/style.css || true
[ -f "$SD/backgrounds/1-quattro.jpg" ] && install -m 0644 -o cody -g cody "$SD/backgrounds/1-quattro.jpg" /home/cody/.local/share/omarchy-pixel/backgrounds/1-quattro.jpg || true

# helper bins
for f in omarchy-wallpaper goose-desktop omarchy-chromium omarchy-goose omarchy-code omarchy-files omarchy-start-apps omarchy-command omarchy-waybar omarchy-super-bridge; do
  if [ -f "$SD/$f" ]; then
    install -m 0755 -o cody -g cody "$SD/$f" /home/cody/.local/bin/$f
  fi
done

# Ensure sway is first in PATH session
which sway; which foot; which waybar; ls -la /home/cody/.local/bin/omarchy-session
echo "ARCH_FIX_DONE"
'

echo "FIX_DONE $(date -Iseconds)"
# Launch desktop
bash "$HOME_DIR/start-omarchy-fullscreen.sh" || bash "$SD/start-omarchy-fullscreen.sh" || true
