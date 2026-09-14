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
Server = http://fl.us.mirror.archlinuxarm.org/$arch/$repo
Server = http://mirrors.ocf.berkeley.edu/archlinuxarm/$arch/$repo
Server = http://ca.us.mirror.archlinuxarm.org/$arch/$repo
Server = http://mirror.archlinuxarm.org/$arch/$repo
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
# SUPER+G → Goose Desktop (Electron, proot-safe --no-zygote wrapper)
# SUPER+Shift+G → goose CLI
bind = SUPER, Return, exec, foot
bind = SUPER, T, exec, foot
bind = SUPER, K, exec, wvkbd-mobintl -L 240
bind = SUPER SHIFT, K, exec, pkill wvkbd-mobintl
bind = SUPER, G, exec, goose-desktop
bind = SUPER SHIFT, G, exec, goose
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

# Persist a native landscape Termux:X11 surface. Its exported preference
# receiver is supported by the app and avoids editing private app data.
cat > "$HOME_DIR/configure-termux-x11.sh" << 'X11PREFS'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
resolution="${OMARCHY_X11_RESOLUTION:-}"
if [[ -z "$resolution" ]] && command -v wm >/dev/null 2>&1; then
  physical="$(wm size 2>/dev/null | sed -n 's/^Physical size: //p' | tail -n1)"
  if [[ "$physical" =~ ^([0-9]+)x([0-9]+)$ ]]; then
    a="${BASH_REMATCH[1]}"; b="${BASH_REMATCH[2]}"
    (( a >= b )) && resolution="${a}x${b}" || resolution="${b}x${a}"
  fi
fi
resolution="${resolution:-2992x1344}"
timeout 8 am broadcast -a com.termux.x11.CHANGE_PREFERENCE -p com.termux.x11 \
  --es displayResolutionMode custom --es displayResolutionCustom "$resolution" \
  --es displayStretch true --es adjustResolution true \
  --es displayFilteringMode nearest --es displayScale 100 \
  --es fullscreen true --es forceOrientation landscape --es hideCutout true \
  --es showAdditionalKbd false --es additionalKbdVisible false \
  --es Reseed false --es PIP false >/dev/null
printf '%s\n' "$resolution" > "$HOME/.omarchy-x11-resolution"
X11PREFS
chmod 755 "$HOME_DIR/configure-termux-x11.sh"
"$HOME_DIR/configure-termux-x11.sh"

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

# Reapply native high-resolution/fullscreen preferences on every launch.
[ -x "$HOME_DIR/configure-termux-x11.sh" ] && "$HOME_DIR/configure-termux-x11.sh"

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

# Auto-launch Omarchy after Android BOOT_COMPLETED. This Google Play Termux
# build has a built-in boot receiver and runs executable scripts in this path.
mkdir -p "$HOME_DIR/.termux/boot"
cat > "$HOME_DIR/.termux/boot/00-omarchy.sh" << 'BOOT'
#!/data/data/com.termux/files/usr/bin/bash
set +e
export PATH="${PREFIX:-/data/data/com.termux/files/usr}/bin:$PATH"
sleep "${OMARCHY_BOOT_DELAY:-12}"
[ -x "$HOME/configure-termux-x11.sh" ] && "$HOME/configure-termux-x11.sh"
exec "$HOME/start-omarchy.sh"
BOOT
chmod 755 "$HOME_DIR/.termux/boot/00-omarchy.sh"
# Best-effort background eligibility for this Google Play Termux build.
am set-standby-bucket com.termux active >/dev/null 2>&1 || true
cmd deviceidle whitelist +com.termux >/dev/null 2>&1 || true

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
# The wlroots nested X11 backend defaults to 1024x768; fill native Pixel landscape.
output X11-1 mode 2992x1344 scale 1
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
# Stage launcher onto sdcard before proot so Arch can install it
GOOSE_DESKTOP_SRC=""
for cand in \
  "$HOME_DIR/goose-desktop" \
  /sdcard/omarchy-pixel/goose-desktop \
  /sdcard/omarchy-pixel/staging/goose-desktop \
  "$(cd "$(dirname "$0")" && pwd)/staging/goose-desktop"
do
  [ -f "$cand" ] && GOOSE_DESKTOP_SRC="$cand" && break
done
if [ -n "${GOOSE_DESKTOP_SRC:-}" ]; then
  mkdir -p /sdcard/omarchy-pixel/staging 2>/dev/null || true
  cp -f "$GOOSE_DESKTOP_SRC" /sdcard/omarchy-pixel/goose-desktop 2>/dev/null || true
  cp -f "$GOOSE_DESKTOP_SRC" /sdcard/omarchy-pixel/staging/goose-desktop 2>/dev/null || true
  chmod 755 /sdcard/omarchy-pixel/goose-desktop /sdcard/omarchy-pixel/staging/goose-desktop 2>/dev/null || true
fi

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

# Goose Desktop .deb (Electron app under /usr/lib/goose) when missing
if [ ! -x /usr/lib/goose/Goose ]; then
  echo "Installing Goose Desktop package..."
  tmp=$(mktemp -d)
  if curl -fL -o "$tmp/goose.deb" "'"${GOOSE_DEB_URL}"'"; then
    cd "$tmp"
    if command -v bsdtar >/dev/null 2>&1; then bsdtar -xf goose.deb; else ar x goose.deb 2>/dev/null || true; fi
    data_tar=$(find . -maxdepth 1 -type f -name "data.tar.*" | head -1 || true)
    if [ -n "$data_tar" ]; then
      mkdir -p root
      case "$data_tar" in
        *.xz) tar -xJf "$data_tar" -C root ;;
        *.gz) tar -xzf "$data_tar" -C root ;;
        *.zst) tar --zstd -xf "$data_tar" -C root ;;
        *) tar -xf "$data_tar" -C root ;;
      esac
      if [ -d root/usr/lib/goose ]; then
        mkdir -p /usr/lib/goose
        cp -a root/usr/lib/goose/. /usr/lib/goose/
        echo "Goose Desktop extracted to /usr/lib/goose"
      fi
    fi
  else
    echo "WARN: Goose Desktop deb download failed"
  fi
  rm -rf "$tmp"
fi

# Proot-safe Goose Desktop launcher (--no-zygote required)
mkdir -p /home/cody/.local/bin /home/cody/.local/share/applications
if [ -f /sdcard/omarchy-pixel/goose-desktop ]; then
  install -m 0755 /sdcard/omarchy-pixel/goose-desktop /home/cody/.local/bin/goose-desktop
elif [ -f /sdcard/omarchy-pixel/staging/goose-desktop ]; then
  install -m 0755 /sdcard/omarchy-pixel/staging/goose-desktop /home/cody/.local/bin/goose-desktop
else
  cat > /home/cody/.local/bin/goose-desktop << "GDESK"
#!/bin/bash
# Goose Desktop launcher for Omarchy/PRoot — --no-zygote required under proot
set -euo pipefail
export HOME="${HOME:-/home/cody}"
export PATH="$HOME/.local/bin:/usr/bin:$PATH"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-$HOME/.run}"
mkdir -p "$XDG_RUNTIME_DIR"; chmod 700 "$XDG_RUNTIME_DIR" 2>/dev/null || true
export DISPLAY="${DISPLAY:-:1}"
if [[ -z ${WAYLAND_DISPLAY:-} ]]; then
  if [[ -S $XDG_RUNTIME_DIR/wayland-1 ]]; then export WAYLAND_DISPLAY=wayland-1
  elif [[ -S /tmp/wayland-1 ]]; then export XDG_RUNTIME_DIR=/tmp WAYLAND_DISPLAY=wayland-1
  fi
fi
export LANG="${LANG:-C.UTF-8}" LC_ALL="${LC_ALL:-C.UTF-8}"
export LIBGL_ALWAYS_SOFTWARE=1 ELECTRON_OZONE_PLATFORM_HINT=x11
export GOOSE_DISABLE_KEYRING="${GOOSE_DISABLE_KEYRING:-1}" GLYCIN_DISABLE_SANDBOX=1
[[ -f $HOME/.config/goose/env.sh ]] && . "$HOME/.config/goose/env.sh"
export GOOSE_MAX_TOKENS="${GOOSE_MAX_TOKENS:-32768}"
export GOOSE_PROVIDER="${GOOSE_PROVIDER:-openrouter}"
export GOOSE_MODEL="${GOOSE_MODEL:-x-ai/grok-4.5}"
export OPENROUTER_HOST="${OPENROUTER_HOST:-https://openrouter.ai}"
BIN=/usr/lib/goose/Goose
[[ -x $BIN ]] || BIN="$HOME/.local/share/Goose/Goose"
[[ -x $BIN ]] || { echo "goose desktop binary not found" >&2; exit 1; }
cfg="$HOME/.config/Goose"
if [[ -L $cfg/SingletonLock ]]; then
  lock_pid="$(readlink "$cfg/SingletonLock" 2>/dev/null | sed "s/.*-//")"
  if [[ $lock_pid =~ ^[0-9]+$ ]] && ! kill -0 "$lock_pid" 2>/dev/null; then
    rm -f "$cfg/SingletonLock" "$cfg/SingletonSocket" "$cfg/SingletonCookie"
  fi
fi
exec "$BIN" --no-sandbox --disable-setuid-sandbox --disable-seccomp-filter-sandbox \
  --disable-dev-shm-usage --no-zygote --disable-gpu --disable-gpu-compositing \
  --disable-gpu-sandbox --use-gl=angle --use-angle=swiftshader --in-process-gpu \
  --ozone-platform=x11 "$@"
GDESK
  chmod 755 /home/cody/.local/bin/goose-desktop
fi
chown cody:cody /home/cody/.local/bin/goose-desktop 2>/dev/null || true
cat > /home/cody/.local/share/applications/goose-desktop.desktop << DESK
[Desktop Entry]
Name=Goose Desktop
Comment=goose Desktop (Electron) — Omarchy/PRoot safe launcher
Exec=/home/cody/.local/bin/goose-desktop %U
Icon=/usr/share/pixmaps/goose.png
Terminal=false
Type=Application
Categories=Development;
StartupWMClass=Goose
DESK
chown -R cody:cody /home/cody/.local/share/applications 2>/dev/null || true
if grep -q -- "--no-zygote" /home/cody/.local/bin/goose-desktop; then
  echo "goose-desktop launcher OK (no-zygote)"
else
  echo "WARN: goose-desktop launcher missing --no-zygote"
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
  SUPER+G       goose-desktop (Electron, proot-safe)
  SUPER+Shift+G goose CLI
  SUPER+Q       close window

MANUAL:
  proot-distro login archlinux --user cody
  Update dots:  cd ~/.local/share/omarchy && git pull

NOTES:
  - Phone calls/SMS stay on Android. This is a desktop in a window.
  - If quickshell fails: inside Arch, install missing qt6 deps via yay.
  - Add home shortcut: long-press home → widgets → Termux:Widget → Omarchy

EOF
