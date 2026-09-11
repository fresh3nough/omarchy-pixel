#!/usr/bin/env bash
# Replace bwrap with a passthrough so glycin/swaybg can load images under proot.
set -euo pipefail
if [ -x /usr/bin/bwrap ] && [ ! -f /usr/bin/bwrap.real ]; then
  # only backup if it looks like real binary (not our stub)
  if ! head -1 /usr/bin/bwrap | grep -q bash; then
    sudo mv /usr/bin/bwrap /usr/bin/bwrap.real
  fi
fi
sudo tee /usr/bin/bwrap >/dev/null << 'STUB'
#!/usr/bin/bash
cmd=(); args=("$@")
for i in "${!args[@]}"; do
  a="${args[$i]}"
  if [[ "$a" == *glycin-loaders* ]]; then cmd=("${args[@]:$i}"); break; fi
  if [ "$a" = "--" ]; then cmd=("${args[@]:$((i+1))}"); break; fi
done
[ ${#cmd[@]} -eq 0 ] && exit 1
export PATH=/usr/bin:/bin HOME=/tmp XDG_RUNTIME_DIR=/tmp LD_LIBRARY_PATH=/usr/lib
exec "${cmd[@]}"
STUB
sudo chmod 755 /usr/bin/bwrap
echo "bwrap stub installed"
