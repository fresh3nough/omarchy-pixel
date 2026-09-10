#!/data/data/com.termux/files/usr/bin/bash
# Omarchy on Pixel - Termux + proot-distro + Arch + Termux:X11
# Author: for Cody - tested on Pixel with Termux from F-Droid
# Run INSIDE Termux, not inside the proot yet.
#
# Changes from base:
# - foot terminal instead of kitty
# - goose desktop + CLI (aarch64)
# - Pixel 10 Pro XL display defaults (auto-detects others)
# - Home-screen launcher via Termux:Widget + shortcut script

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
HOME_DIR="${HOME:-/data/data/com.termux/files/home}"
GOOSE_VERSION="${GOOSE_VERSION:-v1.50.0}"
GOOSE_URL="https://github.com/aaif-goose/goose/releases/download/${GOOSE_VERSION}/goose-aarch64-unknown-linux-gnu.tar.bz2"
GOOSE_DEB_URL="https://github.com/aaif-goose/goose/releases/download/${GOOSE_VERSION}/goose_1.50.0_arm64.deb"
ARCH_TBALL="/sdcard/omarchy-pixel/ArchLinuxARM-aarch64-latest.tar.gz"

log() { printf '\n\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }

# Detect panel for mobile monitor config
detect_monitor() {
  # Prefer Android dumpsys via toybox/getprop if available outside proot later;
  # here we use a sensible Pixel default and allow override.
  local w h r scale
  w="${OMARCHY_WIDTH:-1344}"
  h="${OMARCHY_HEIGHT:-2992}"
  r="${OMARCHY_REFRESH:-120}"
  scale="${OMARCHY_SCALE:-2.0}"
  echo "monitor=,${w}x${h}@${r},auto,${scale}"
}

log "1/7 Installing Termux base packages"
pkg update -y || true

# Repos MUST be installed before packages that live in them
pkg install -y x11-repo tur-repo || true
pkg update -y || true

# Core tools (no x11 package yet)
pkg install -y proot-distro pulseaudio wget git curl neofetch \
  tar bzip2 unzip termux-tools which sed coreutils || \
pkg install -y proot-distro pulseaudio wget git curl neofetch tar bzip2

# X11 package from x11-repo (optional name variants)
pkg install -y termux-x11-nightly 2>/dev/null \
  || pkg install -y termux-x11 2>/dev/null \
  || warn "termux-x11 pkg missing — APK may still provide the activity; continuing"

# termux-api package is optional if APK not installed
pkg install -y termux-api 2>/dev/null || true

log "2/7 Installing Arch Linux ARM container"
# proot-distro only treats a path as a local archive when it starts with /, ./, ../, or ~
# Bare names like "archlinux" are always resolved as Docker images (amd64-only upstream).
arch_installed() {
  # Prefer a real login probe — `proot-distro list` format varies by version.
  proot-distro login archlinux -- true >/dev/null 2>&1 && return 0
  local rootfs
  for rootfs in \
    "$PREFIX/var/lib/proot-distro/installed-rootfs/archlinux" \
    "$HOME/../usr/var/lib/proot-distro/installed-rootfs/archlinux"
  do
    [ -d "$rootfs" ] && [ -f "$rootfs/etc/os-release" ] && return 0
  done
  return 1
}

if arch_installed; then
  warn "Arch already installed, skipping..."
else
  proot-distro remove archlinux 2>/dev/null || true
  proot-distro remove archlinuxarm-aarch64-latest 2>/dev/null || true

  if [ -f "$ARCH_TBALL" ]; then
    log "Installing Arch Linux ARM from local rootfs tarball: $ARCH_TBALL"
    # Absolute path form is required so this is NOT treated as a Docker image name.
    proot-distro install --name archlinux "$ARCH_TBALL"
  else
    warn "Local tarball missing: $ARCH_TBALL"
    log "Falling back to Docker Hub arm64 image danhunsaker/archlinuxarm:latest"
    if ! proot-distro install --name archlinux danhunsaker/archlinuxarm:latest; then
      log "Docker fallback failed — downloading ArchLinuxARM rootfs tarball"
      mkdir -p "$(dirname "$ARCH_TBALL")"
      curl -L --fail --retry 3 -o "$ARCH_TBALL" \
        "http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz"
      proot-distro install --name archlinux "$ARCH_TBALL"
    fi
  fi

  # Sanity check
  arch_installed \
    || { echo "ERROR: archlinux container failed to install"; exit 1; }
  log "Arch container installed OK"
fi

log "3/7 Bootstrapping Arch with compositor + foot + goose"
proot-distro login archlinux -- bash -c '
set -euo pipefail
pacman-key --init 2>/dev/null || true
pacman-key --populate archlinuxarm 2>/dev/null || pacman-key --populate archlinux 2>/dev/null || true

# Prefer reachable Arch Linux ARM mirrors (default mirror often times out on mobile).
cat > /etc/pacman.d/mirrorlist << "MIRRORS"
Server = http://ca.us.mirror.archlinuxarm.org/\$arch/\$repo
Server = http://mirrors.ocf.berkeley.edu/archlinuxarm/\$arch/\$repo
Server = http://mirror.archlinuxarm.org/\$arch/\$repo
MIRRORS

pacman --disable-sandbox -Sy --noconfirm

# Base always-required packages
pacman --disable-sandbox -S --noconfirm --needed \
  base-devel git wget curl sudo tar bzip2 binutils zstd xz \
  mesa vulkan-icd-loader libxkbcommon wayland \
  foot neovim zsh tmux btop fzf ripgrep starship \
  ttf-dejavu ttf-liberation || true

# Compositor: Hyprland is not always in Arch ARM repos. Fall back to sway, then cage.
if pacman --disable-sandbox -S --noconfirm --needed hyprland waybar mako wl-clipboard grim slurp 2>/dev/null; then
  echo "compositor=hyprland"
elif pacman --disable-sandbox -S --noconfirm --needed sway waybar mako wl-clipboard grim slurp wlr-randr 2>/dev/null; then
  echo "compositor=sway"
elif pacman --disable-sandbox -S --noconfirm --needed cage foot 2>/dev/null; then
  echo "compositor=cage"
else
  echo "WARN: no compositor package installed; session will try whatever is available"
fi

# Create user (omarchy expects non-root)
id -u cody &>/dev/null || useradd -m -G wheel -s /bin/bash cody
echo "cody ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/cody
chmod 440 /etc/sudoers.d/cody

# Ensure home dirs
sudo -u cody mkdir -p /home/cody/.config /home/cody/.local/{bin,share,src} /home/cody/Downloads

# Omarchy dotfiles — cherry-pick, not full OS installer
sudo -u cody bash -c "
set -euo pipefail
if [ ! -d /home/cody/.local/share/omarchy/.git ]; then
  rm -rf /home/cody/.local/share/omarchy
  git clone --depth 1 https://github.com/basecamp/omarchy.git /home/cody/.local/share/omarchy || true
else
  git -C /home/cody/.local/share/omarchy pull --ff-only || true
fi
mkdir -p /home/cody/.config
for d in hypr quickshell nvim waybar mako foot; do
  if [ -d /home/cody/.local/share/omarchy/config/\$d ]; then
    cp -a /home/cody/.local/share/omarchy/config/\$d /home/cody/.config/ 2>/dev/null || true
  fi
done
cp /home/cody/.local/share/omarchy/config/starship.toml /home/cody/.config/ 2>/dev/null || true
"

echo "Arch bootstrap done"
'

log "4/7 Patching configs for Pixel phone (foot + mobile)"
MONITOR_LINE="$(detect_monitor)"
proot-distro login archlinux -- bash -c "
set -euo pipefail
mkdir -p /home/cody/.config/hypr /home/cody/.config/waybar /home/cody/.config/foot /home/cody/.local/bin

cat > /home/cody/.config/hypr/monitors-mobile.conf << EOF
# Pixel mobile portrait-first overrides
${MONITOR_LINE}
# Touch-friendly chrome
general {
  border_size = 2
  gaps_in = 4
  gaps_out = 8
}
decoration {
  rounding = 12
}
input {
  kb_layout = us
  touchdevice {
    enabled = true
  }
}

# Mobile binds — foot terminal + on-screen keyboard + goose
bind = SUPER, Return, exec, foot
bind = SUPER, T, exec, foot
bind = SUPER, K, exec, wvkbd-mobintl -L 240
bind = SUPER SHIFT, K, exec, pkill wvkbd-mobintl
bind = SUPER, G, exec, goose
bind = SUPER SHIFT, G, exec, Goose
bind = SUPER, Q, killactive,
bind = SUPER, F, fullscreen,

exec-once = wvkbd-mobintl --hidden &
exec-once = waybar &
exec-once = mako &
exec-once = wl-paste --watch cliphist store &
EOF

# Ensure hyprland loads mobile overrides
if [ -f /home/cody/.config/hypr/hyprland.conf ]; then
  grep -q 'monitors-mobile.conf' /home/cody/.config/hypr/hyprland.conf || \
    echo 'source = ~/.config/hypr/monitors-mobile.conf' >> /home/cody/.config/hypr/hyprland.conf
  # Prefer foot over kitty in any stock binds
  sed -i 's/\\bkitty\\b/foot/g' /home/cody/.config/hypr/hyprland.conf 2>/dev/null || true
  sed -i 's/\\balacritty\\b/foot/g' /home/cody/.config/hypr/hyprland.conf 2>/dev/null || true
else
  cat > /home/cody/.config/hypr/hyprland.conf << HYPR
# Minimal Hyprland config for Omarchy-on-Pixel
exec-once = dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
source = ~/.config/hypr/monitors-mobile.conf
env = XCURSOR_SIZE,32
misc {
  disable_hyprland_logo = true
  force_default_wallpaper = 0
}
HYPR
fi

# Waybar mobile config
mkdir -p /home/cody/.config/waybar
cat > /home/cody/.config/waybar/config << 'EOF'
{
  \"layer\": \"top\",
  \"height\": 40,
  \"modules-left\": [\"hyprland/workspaces\", \"battery\"],
  \"modules-center\": [\"clock\"],
  \"modules-right\": [\"network\", \"pulseaudio\", \"tray\"],
  \"clock\": { \"format\": \"{:%a %H:%M}\" },
  \"battery\": { \"format\": \"{capacity}% {icon}\", \"format-icons\": [\"\",\"\",\"\",\"\",\"\"] }
}
EOF

# foot config — large touch-friendly font
cat > /home/cody/.config/foot/foot.ini << 'EOF'
[main]
term=xterm-256color
font=monospace:size=14
pad=8x8
dpi-aware=yes

[mouse]
hide-when-typing=yes

[colors]
alpha=0.95
EOF

# Shell defaults
grep -q 'omarchy/default' /home/cody/.bashrc 2>/dev/null || \
  echo '[ -f ~/.local/share/omarchy/default/bash/rc ] && source ~/.local/share/omarchy/default/bash/rc' >> /home/cody/.bashrc
grep -q 'STARSHIP_CONFIG' /home/cody/.bashrc 2>/dev/null || \
  echo 'export STARSHIP_CONFIG=~/.config/starship.toml' >> /home/cody/.bashrc
grep -q 'starship init' /home/cody/.bashrc 2>/dev/null || \
  echo 'command -v starship >/dev/null && eval \"\$(starship init bash)\"' >> /home/cody/.bashrc

chown -R cody:cody /home/cody/.config /home/cody/.local /home/cody/.bashrc
"

log "5/7 Creating launchers (Termux + Arch session)"
# Prefer short -xstartup path: long inline args are rejected by termux-x11,
# and Termux LD_PRELOAD makes Xorg abort as "unsafe environment".
cat > "$HOME_DIR/omarchy-xstartup.sh" << 'XSTART'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
export PATH="$PREFIX/bin:$PATH"
rm -rf "$PREFIX/tmp/.X11-unix" 2>/dev/null || true
mkdir -p "$PREFIX/tmp/.X11-unix"
pulseaudio --start \
  --load="module-native-protocol-tcp auth-anonymous=1" \
  --exit-idle-time=-1 >/dev/null 2>&1 || true
# --shared-tmp already maps tmp; do not also --bind PREFIX/tmp:/tmp (overlap warning).
exec proot-distro login archlinux \
  --user cody \
  --shared-tmp \
  -- env DISPLAY=:0 \
       WAYLAND_DISPLAY=wayland-0 \
       XDG_RUNTIME_DIR=/tmp \
       HOME=/home/cody \
       PULSE_SERVER=tcp:127.0.0.1 \
       QT_QPA_PLATFORM=wayland \
       GDK_BACKEND=wayland \
       /home/cody/.local/bin/omarchy-session
XSTART
chmod 755 "$HOME_DIR/omarchy-xstartup.sh"
cp -f "$HOME_DIR/omarchy-xstartup.sh" /sdcard/omarchy-pixel/omarchy-xstartup.sh 2>/dev/null || true

cat > "$HOME_DIR/start-omarchy.sh" << 'LAUNCHER'
#!/data/data/com.termux/files/usr/bin/bash
# Launch Omarchy desktop via Termux:X11 + Arch proot compositor
set -euo pipefail
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
export PATH="$PREFIX/bin:$PATH"
HOME_DIR="${HOME:-/data/data/com.termux/files/home}"
SDCARD_DIR="/sdcard/omarchy-pixel"
LOG="$SDCARD_DIR/termux-x11.log"

if [ ! -f "$HOME_DIR/.omarchy-installed" ] && ! proot-distro login archlinux -- true >/dev/null 2>&1; then
  echo "Omarchy not installed yet. Running setup..."
  if [ -f "$HOME_DIR/setup-omarchy-pixel.sh" ]; then
    exec bash "$HOME_DIR/setup-omarchy-pixel.sh"
  fi
  exec bash "$SDCARD_DIR/setup-omarchy-pixel.sh"
fi

pkill -9 termux-x11 2>/dev/null || true
pkill -9 Xwayland 2>/dev/null || true
sleep 0.5
rm -rf "$PREFIX/tmp/.X11-unix" 2>/dev/null || true
mkdir -p "$PREFIX/tmp/.X11-unix" "$PREFIX/tmp"
: > "$LOG"

pulseaudio --start \
  --load="module-native-protocol-tcp auth-anonymous=1" \
  --exit-idle-time=-1 2>/dev/null || pulseaudio --start 2>/dev/null || true

# 1) Start Termux:X11 X server only.
# Unset LD_PRELOAD for Xorg only — proot still needs Termux's preload.
env -u LD_PRELOAD termux-x11 :0 >"$LOG" 2>&1 &

am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity >/dev/null 2>&1 \
  || am start --user 0 -n com.termux.x11/.MainActivity >/dev/null 2>&1 \
  || true

# 2) Wait for the X11 socket under Termux tmp
for i in $(seq 1 40); do
  if [ -S "$PREFIX/tmp/.X11-unix/X0" ]; then
    echo "X0 ready after ${i} tries" >>"$LOG"
    break
  fi
  sleep 0.5
done

if [ ! -S "$PREFIX/tmp/.X11-unix/X0" ]; then
  echo "WARN: X0 socket missing" | tee -a "$LOG"
  ls -la "$PREFIX/tmp" "$PREFIX/tmp/.X11-unix" >>"$LOG" 2>&1 || true
fi

sleep 1

# 3) Start compositor inside Arch against DISPLAY=:0
# Keep default env (incl. LD_PRELOAD) so proot can exec.
# --shared-tmp shares Termux /tmp (X0) into the proot.
proot-distro login archlinux \
  --user cody \
  --shared-tmp \
  -- env \
    DISPLAY=:0 \
    XDG_RUNTIME_DIR=/tmp \
    HOME=/home/cody \
    PULSE_SERVER=tcp:127.0.0.1 \
    WLR_BACKENDS=x11 \
    WLR_NO_HARDWARE_CURSORS=1 \
    QT_QPA_PLATFORM=wayland \
    GDK_BACKEND=wayland \
    /home/cody/.local/bin/omarchy-session \
  >>"$LOG" 2>&1 &

sleep 2
am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity >/dev/null 2>&1 \
  || am start --user 0 -n com.termux.x11/.MainActivity >/dev/null 2>&1 \
  || true

echo "Omarchy session started."
echo "SUPER+Return = foot  |  SUPER+Shift+e = exit sway"
LAUNCHER
chmod +x "$HOME_DIR/start-omarchy.sh"

# Also expose as ~/.shortcuts for Termux:Widget home-screen tap
mkdir -p "$HOME_DIR/.shortcuts"
cat > "$HOME_DIR/.shortcuts/Omarchy" << 'WIDGET'
#!/data/data/com.termux/files/usr/bin/bash
exec "$HOME/start-omarchy.sh"
WIDGET
cp -f "$HOME_DIR/.shortcuts/Omarchy" "$HOME_DIR/.shortcuts/Omarchy.sh"
chmod +x "$HOME_DIR/.shortcuts/Omarchy" "$HOME_DIR/.shortcuts/Omarchy.sh"

# Session wrapper inside Arch
proot-distro login archlinux -- bash -c '
set -e
mkdir -p /home/cody/.local/bin /home/cody/.config/foot /home/cody/.config/sway
# Safe foot config (no invalid [colors] section on newer foot)
cat > /home/cody/.config/foot/foot.ini << "FOOT"
[main]
term=xterm-256color
font=DejaVu Sans Mono:size=14
pad=8x8
FOOT
# Minimal sway config for phone
cat > /home/cody/.config/sway/config << "SWAY"
set $mod Mod4
output * bg #1a1b26 solid_color
default_border pixel 2
font pango:DejaVu Sans Mono 12
bindsym $mod+Return exec foot
bindsym $mod+t exec foot
bindsym $mod+q kill
bindsym $mod+d exec foot
bindsym $mod+Shift+e exit
exec_always waybar || true
SWAY
cat > /home/cody/.local/bin/omarchy-session << "SESS"
#!/bin/bash
export DISPLAY="${DISPLAY:-:0}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
export XDG_SESSION_TYPE=wayland
export PULSE_SERVER="${PULSE_SERVER:-tcp:127.0.0.1}"
export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-wayland}"
export GDK_BACKEND=wayland
export PATH="$HOME/.local/bin:/usr/bin:$PATH"
mkdir -p "$XDG_RUNTIME_DIR"
cd "$HOME"
if command -v Hyprland >/dev/null 2>&1; then
  export XDG_CURRENT_DESKTOP=Hyprland
  exec Hyprland
elif command -v hyprland >/dev/null 2>&1; then
  export XDG_CURRENT_DESKTOP=Hyprland
  exec hyprland
elif command -v sway >/dev/null 2>&1; then
  export XDG_CURRENT_DESKTOP=sway
  exec sway
elif command -v cage >/dev/null 2>&1; then
  export XDG_CURRENT_DESKTOP=cage
  exec cage foot
else
  exec foot
fi
SESS
chmod +x /home/cody/.local/bin/omarchy-session
chown -R cody:cody /home/cody/.local /home/cody/.config
'

log "6/7 Installing goose desktop assets check + PATH"
proot-distro login archlinux -- bash -c '
set -e
if [ -x /home/cody/.local/bin/goose ]; then
  echo -n "goose CLI: "
  sudo -u cody /home/cody/.local/bin/goose --version 2>&1 || true
else
  echo "goose binary missing — retry download"
  sudo -u cody bash -c "
    cd /tmp
    curl -L -o g.tar.bz2 \"'"${GOOSE_URL}"'\"
    tar -xjf g.tar.bz2
    BIN=\$(find . -type f -name goose | head -n1)
    install -m 755 \"\$BIN\" /home/cody/.local/bin/goose
  "
fi
# Ensure foot present
command -v foot && foot --version || pacman -S --noconfirm foot
'

# Mark installed for launcher short-circuit
touch "$HOME_DIR/.omarchy-installed" 2>/dev/null || true
cp -f "$HOME_DIR/start-omarchy.sh" "$HOME_DIR/.shortcuts/Omarchy" 2>/dev/null || true
chmod +x "$HOME_DIR/.shortcuts/Omarchy" 2>/dev/null || true
# Mirror shortcut + marker to sdcard for host
cp -f "$HOME_DIR/.omarchy-installed" /sdcard/omarchy-pixel/ 2>/dev/null || true
cp -f "$HOME_DIR/start-omarchy.sh" /sdcard/omarchy-pixel/ 2>/dev/null || true

log "7/7 Done"
cat << EOF

============================================
  Omarchy-on-Pixel ready
============================================

USAGE:
  1. From Termux:  ./start-omarchy.sh
  2. Or tap the "Omarchy" home-screen shortcut (Termux:Widget)
  3. Termux:X11 opens → Hyprland

BINDS:
  SUPER+Return  foot terminal
  SUPER+T       foot terminal
  SUPER+K       on-screen keyboard
  SUPER+G       goose
  SUPER+Q       close window

MANUAL:
  proot-distro login archlinux --user cody
  Update dots:  cd ~/.local/share/omarchy && git pull

NOTES:
  - Phone calls/SMS stay on Android. This is a desktop in a window.
  - If quickshell fails: inside Arch, install missing qt6 deps via yay.
  - Add home shortcut: long-press home → widgets → Termux:Widget → Omarchy

EOF
