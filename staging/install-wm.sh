#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
export PATH="/data/data/com.termux/files/usr/bin:$PATH"
LOG=/sdcard/omarchy-pixel/wm-install.log
: > "$LOG"
echo "WM_START $(date -Iseconds)" | tee -a /sdcard/omarchy-pixel/status.txt

# Inner script written to a file to avoid proot stdin issues
cat > /sdcard/omarchy-pixel/wm-inner.sh << 'INNER'
#!/bin/bash
set -euo pipefail
rm -f /var/lib/pacman/db.lck
cat > /etc/pacman.d/mirrorlist << 'MIRRORS'
Server = http://ca.us.mirror.archlinuxarm.org/$arch/$repo
Server = http://mirrors.ocf.berkeley.edu/archlinuxarm/$arch/$repo
Server = http://mirror.archlinuxarm.org/$arch/$repo
MIRRORS
pacman --disable-sandbox -Sy --noconfirm
pacman --disable-sandbox -S --noconfirm --needed jack2 || true
if ! pacman --disable-sandbox -S --noconfirm --needed \
    sway waybar mako foot wlr-randr wl-clipboard grim slurp \
    ttf-dejavu ttf-liberation; then
  pacman --disable-sandbox -S --noconfirm --needed cage foot ttf-dejavu || true
fi
mkdir -p /home/cody/.config/foot /home/cody/.config/sway /home/cody/.local/bin
cat > /home/cody/.config/foot/foot.ini << 'FOOT'
[main]
term=xterm-256color
font=DejaVu Sans Mono:size=14
pad=8x8
FOOT
cat > /home/cody/.config/sway/config << 'SWAY'
set $mod Mod4
output * bg #1a1b26 solid_color
default_border pixel 2
font pango:DejaVu Sans Mono 12
bindsym $mod+Return exec foot
bindsym $mod+t exec foot
bindsym $mod+q kill
bindsym $mod+Shift+e exit
exec_always waybar || true
SWAY
cat > /home/cody/.local/bin/omarchy-session << 'SESS'
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
chown -R cody:cody /home/cody/.config /home/cody/.local 2>/dev/null || true
echo BINS:
command -v sway || true
command -v cage || true
command -v foot || true
pacman -Q sway cage foot 2>&1 || true
INNER

proot-distro login archlinux -- bash /sdcard/omarchy-pixel/wm-inner.sh 2>&1 | tee -a "$LOG"
echo "WM_DONE $(date -Iseconds)" | tee -a /sdcard/omarchy-pixel/status.txt
