# Omarchy on Pixel (Termux + Arch proot + Termux:X11)

Tokyo-night desktop with Audi quattro wallpaper, optimized for **landscape monitor mirroring** via `scrcpy`.

## What's running

| Layer | Component |
|-------|-----------|
| Android | Termux, Termux:X11, Termux:Widget, Omarchy launcher APK |
| Termux | `Omarchy.sh` → `start-omarchy-fullscreen.sh` |
| Arch proot | sway (WLR_BACKENDS=x11) + waybar + foot + swaybg |
| Apps | goose (foot), Chromium (`omarchy-chromium`), **1Password desktop** (`/opt/1Password`) |
| Theme | tokyo-night + `1-quattro.jpg` wallpaper |

## Launch desktop

**Home shortcut:** tap **Omarchy.sh** (Termux:Widget)

```bash
bash ~/start-omarchy-fullscreen.sh
# or
bash ~/.shortcuts/Omarchy.sh
```

The launcher configures Termux:X11 and nested Sway for the Pixel's native
**2992×1344 landscape** surface, enables Android immersive fullscreen, and hides
the Termux:X11 extra-key bar. Override the X resolution when needed:

```bash
OMARCHY_X11_RESOLUTION=1920x1080 bash ~/configure-termux-x11.sh
```

## Start automatically after Android boot

The deploy script installs:

```text
~/.termux/boot/00-omarchy.sh
```

Google Play Termux includes a `BOOT_COMPLETED` receiver, so no separate
Termux:Boot package is required for this build. Disable auto-start by removing
that file. Change the default 12-second boot delay with `OMARCHY_BOOT_DELAY`.

**Mirror to monitor (host USB):**
```bash
scrcpy --video-codec=h264 --max-fps=60 --stay-awake --window-title='Omarchy Pixel'
```

## Apps (after desktop is up)

From a foot shell on the Pixel desktop:

```bash
# all three
omarchy-start-apps

# or individually
omarchy-goose &
omarchy-chromium https://archlinux.org &
1password &
```

### Install 1Password desktop (once)

Official aarch64 tarball → `/opt/1Password`:

```bash
# host: download and push, or from device:
curl -fL -o ~/1password-latest.tar.gz \
  https://downloads.1password.com/linux/tar/stable/aarch64/1password-latest.tar.gz
proot-distro login archlinux --user cody --shared-tmp -- \
  bash -lc 'bash /sdcard/omarchy-rice/pixel/install-1password-desktop.sh ~/1password-latest.tar.gz'
# or copy install-1password-desktop.sh into Arch and run there
```

Install app wrappers into Arch `$HOME/.local/bin`:

```bash
cp omarchy-chromium omarchy-goose omarchy-start-apps ~/.local/bin/
chmod 755 ~/.local/bin/omarchy-*
# 1password wrapper is created by install-1password-desktop.sh
```

## Keybinds (sway)

| Key | Action |
|-----|--------|
| Super+Return / Super+T | foot |
| Super+G | goose |
| Super+B | chromium |
| Super+P | 1Password desktop |
| Super+Q | close |
| Super+F | fullscreen |
| Super+Shift+E | exit sway |

## Deploy from host

```bash
bash pixel/deploy-to-pixel.sh
```

## Notes

- Play Store Termux has **no** `RUN_COMMAND` — use **Omarchy.sh** widget, not the launcher APK alone.
- `/sdcard` is `noexec` and ADB-pushed files are mode `660`; run scripts from Termux `$HOME` or `bash /path`.
- swaybg → glycin → bwrap needs `install-bwrap-stub.sh` under proot.
- Foot on Arch ARM 1.28 uses `[colors-dark]`.
- Chromium/1Password need X11 ozone + `--no-sandbox` + `--disable-gpu` under proot; launch from the **live** foot/sway session so processes stay parented correctly.
