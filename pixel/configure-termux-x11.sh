#!/data/data/com.termux/files/usr/bin/bash
# Persist native high-resolution landscape output in Termux:X11.
set -euo pipefail

# Use the physical Android display size when available, normalized to landscape.
# Pixel 10 Pro XL fallback: 2992x1344.
resolution="${OMARCHY_X11_RESOLUTION:-}"
if [[ -z "$resolution" ]] && command -v wm >/dev/null 2>&1; then
  physical="$(wm size 2>/dev/null | sed -n 's/^Physical size: //p' | tail -n1)"
  if [[ "$physical" =~ ^([0-9]+)x([0-9]+)$ ]]; then
    a="${BASH_REMATCH[1]}"
    b="${BASH_REMATCH[2]}"
    if (( a >= b )); then
      resolution="${a}x${b}"
    else
      resolution="${b}x${a}"
    fi
  fi
fi
resolution="${resolution:-2992x1344}"

if [[ ! "$resolution" =~ ^[1-9][0-9]*x[1-9][0-9]*$ ]]; then
  echo "Invalid OMARCHY_X11_RESOLUTION: $resolution" >&2
  exit 1
fi

# These are supported exported preferences in Termux:X11. They persist across
# restarts and reboots; no root access or direct SharedPreferences edit needed.
# Android may wait for the receiver while Termux:X11 is recreating its window;
# cap that wait so shortcut and boot startup can never stall here.
timeout 8 am broadcast -a com.termux.x11.CHANGE_PREFERENCE -p com.termux.x11 \
  --es displayResolutionMode custom \
  --es displayResolutionCustom "$resolution" \
  --es displayStretch true \
  --es adjustResolution true \
  --es displayFilteringMode nearest \
  --es displayScale 100 \
  --es fullscreen true \
  --es forceOrientation landscape \
  --es hideCutout true \
  --es showAdditionalKbd false \
  --es additionalKbdVisible false \
  --es Reseed false \
  --es PIP false \
  >/dev/null 2>&1 || true

printf '%s\n' "$resolution" > "${HOME:-/data/data/com.termux/files/home}/.omarchy-x11-resolution"
echo "Termux:X11 configured: ${resolution}, landscape, fullscreen, extra keys hidden"
