#!/bin/bash
set -e
export HOME=/home/cody PATH=$HOME/.local/bin:/usr/bin:$PATH
SD=/sdcard/omarchy-pixel
mkdir -p $HOME/.config/{sway,waybar,foot,goose} $HOME/.local/bin $HOME/.run $HOME/.local/share/omarchy-pixel/backgrounds
chmod 700 $HOME/.run $HOME/.config/goose
cp -f $SD/waybar-config.json $HOME/.config/waybar/config
cp -f $SD/waybar-style.css $HOME/.config/waybar/style.css
install -m 0755 $SD/omarchy-wallpaper $HOME/.local/bin/omarchy-wallpaper
install -m 0755 $SD/omarchy-command $HOME/.local/bin/omarchy-command
install -m 0755 $SD/omarchy-waybar $HOME/.local/bin/omarchy-waybar
[ -f $SD/backgrounds/1-quattro.jpg ] && cp -f $SD/backgrounds/1-quattro.jpg $HOME/.local/share/omarchy-pixel/backgrounds/1-quattro.jpg

cat > $HOME/.config/sway/config << 'SWAY'
set $mod Mod4
set $term foot
set $browser /home/cody/.local/bin/omarchy-chromium
set $goosebin /home/cody/.local/bin/omarchy-goose
set $onepass /home/cody/.local/bin/1password

# Match the native landscape Termux:X11 surface instead of wlroots' 1024x768 default.
output X11-1 mode 2992x1344 scale 1
output * bg #1a1b26 solid_color
default_border pixel 2
default_floating_border pixel 2
font pango:DejaVu Sans Mono 12
gaps inner 6
gaps outer 4
smart_gaps on
smart_borders on
focus_follows_mouse yes
client.focused          #7aa2f7 #1a1b26 #c0caf5 #7aa2f7 #7aa2f7
client.focused_inactive #414868 #1a1b26 #a9b1d6 #414868 #414868
client.unfocused        #1a1b26 #13141c #565f89 #1a1b26 #1a1b26
client.urgent           #f7768e #1a1b26 #c0caf5 #f7768e #f7768e

for_window [app_id="foot"] border pixel 2
# Proportional sizing stays usable on the native 2992x1344 output and mirrored monitors.
for_window [app_id="omarchy-rice"] border pixel 2
for_window [app_id="window-arrange"] border pixel 2
for_window [app_id="omarchy-command-menu"] floating enable, sticky enable, border pixel 2, resize set width 44 ppt height 54 ppt, move position center
for_window [app_id="omarchy-goose"] floating enable, border pixel 2, resize set width 42 ppt height 82 ppt, move position 1 ppt 6 ppt
for_window [class="Chromium"] border pixel 2
for_window [class="1Password"] border pixel 2

bindsym $mod+Return exec $term
bindsym $mod+t exec $term
bindsym $mod+q kill
bindsym $mod+g exec $goosebin
bindsym $mod+b exec $browser
bindsym $mod+p exec $onepass
bindsym $mod+f fullscreen
bindsym $mod+Space floating toggle
bindsym $mod+Shift+e exit
bindsym $mod+r reload
bindsym $mod+1 workspace number 1
bindsym $mod+2 workspace number 2
bindsym $mod+3 workspace number 3
bindsym $mod+Left focus left
bindsym $mod+Right focus right
bindsym $mod+Up focus up
bindsym $mod+Down focus down

input type:touch {
    tap enabled
    natural_scroll enabled
}
input type:pointer {
    natural_scroll disabled
    accel_profile flat
}

# Sway owns these processes so they survive and inherit SWAYSOCK.
bar {
    swaybar_command /home/cody/.local/bin/omarchy-waybar
}
exec_always /home/cody/.local/bin/omarchy-wallpaper
exec /home/cody/.local/bin/omarchy-goose
SWAY

cat > $HOME/.local/bin/omarchy-goose << 'GOOSE'
#!/bin/bash
export HOME="${HOME:-/home/cody}"
export PATH="$HOME/.local/bin:/usr/bin:$PATH"
export DISPLAY="${DISPLAY:-:0}"
export LANG=C.UTF-8 LC_ALL=C.UTF-8
[ -f "$HOME/.config/goose/env.sh" ] && . "$HOME/.config/goose/env.sh"
export OPENROUTER_HOST="${OPENROUTER_HOST:-https://openrouter.ai}"
export GOOSE_PROVIDER="${GOOSE_PROVIDER:-openrouter}"
export GOOSE_MODEL="${GOOSE_MODEL:-x-ai/grok-4.5}"
exec foot --app-id=omarchy-goose --title=Goose bash -lc '
  export HOME=/home/cody LANG=C.UTF-8 LC_ALL=C.UTF-8
  [ -f "$HOME/.config/goose/env.sh" ] && . "$HOME/.config/goose/env.sh"
  export GOOSE_PROVIDER=openrouter GOOSE_MODEL=x-ai/grok-4.5 OPENROUTER_HOST=https://openrouter.ai
  cd "$HOME"
  exec goose
'
GOOSE
chmod 755 $HOME/.local/bin/omarchy-goose

# Config contains no secret; key is already in secrets.yaml mode 600.
cat > $HOME/.config/goose/config.yaml << 'CFG'
OPENROUTER_HOST: https://openrouter.ai
providers:
  openrouter:
    enabled: true
    model: x-ai/grok-4.5
    configured: true
GOOSE_MODE: auto
GOOSE_TELEMETRY_ENABLED: false
GOOSE_THINKING_EFFORT: medium
active_provider: openrouter
extensions:
  developer:
    enabled: true
    type: platform
    name: developer
    display_name: Developer
    bundled: true
  todo:
    enabled: true
    type: platform
    name: todo
    display_name: Todo
    bundled: true
CFG
cat > $HOME/.config/goose/env.sh << 'ENV'
export OPENROUTER_HOST="${OPENROUTER_HOST:-https://openrouter.ai}"
if [ -z "${OPENROUTER_API_KEY:-}" ] && [ -f "$HOME/.config/goose/secrets.yaml" ]; then
  OPENROUTER_API_KEY="$(awk -F': *' '/^OPENROUTER_API_KEY:/{print $2; exit}' "$HOME/.config/goose/secrets.yaml" | tr -d '"' | tr -d '\r')"
  export OPENROUTER_API_KEY
fi
export GOOSE_PROVIDER="${GOOSE_PROVIDER:-openrouter}"
export GOOSE_MODEL="${GOOSE_MODEL:-x-ai/grok-4.5}"
ENV
chmod 600 $HOME/.config/goose/secrets.yaml $HOME/.config/goose/env.sh

# Validate without printing key.
. $HOME/.config/goose/env.sh
printf 'goose=%s model=%s key_set=%s\n' "$(goose --version | head -1)" "$GOOSE_MODEL" "$([ -n "$OPENROUTER_API_KEY" ] && echo yes || echo no)"
echo APPLY_FINAL_OK
