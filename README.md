# Omarchy-Pixel - Linux Desktop on Pixel via Termux

A guide to set up and run Omarchy-style desktop (Hyprland when available, otherwise **sway** on Arch Linux ARM) on a Pixel phone using Termux and ADB.

## Overview

This project sets up a full-featured desktop environment (Hyprland) on a Pixel phone by:
- Installing **proot-distro** (Arch Linux container) inside Termux
- Installing **Omarchy** (the desktop environment) via the official release
- Configuring **Termux:X11** to run Hyprland on the phone
- Adding **home-screen shortcuts** via Termux:Widget

## Prerequisites

- **Pixel phone** with USB-C connection
- **Termux** installed on the phone (must be reinstalled after removing the old version)
- **ADB** (Android Debug Bridge) enabled on the phone
- A computer with internet access

## Installation

### 1. Remove Old Termux (Required)

Before starting, you must remove the existing Termux installation:

1. On your Pixel, go to **Settings → Apps**
2. Find **Termux** and tap **Uninstall** (not Disable)
3. Confirm deletion
4. Restart your device (optional but recommended)

### 2. Reinstall Termux

1. After restart, go to **Settings → Apps** again
2. Find **Termux** and tap **Install** (it should be available now)
3. Wait for installation to complete
4. When Termux starts, you'll see a prompt for **RUN_COMMAND permission** - **TAP "Allow"**

### 3. Configure ADB (Optional)

Ensure ADB is properly configured on your computer:
```bash
adb devices
```
You should see your Pixel listed as connected.

## Setup Scripts

### Main Installer
```bash
cd /home/fresh/github/omarchy-pixel
./setup-omarchy-pixel.sh
```

This script performs the following:
- Installs proot-distro, Arch Linux, and basic tools
- Sets up the X11 repository and termux-x11-nightly
- Configures the RUN_COMMAND service (requires permission)
- Creates home-screen shortcuts via Termux:Widget
- Prepares the Omarchy session

### Launcher Script
```bash
./start-omarchy.sh
```

Starts PulseAudio, launches Termux:X11 with Hyprland, and opens the Omarchy session.

### Fixed Debugger
```bash
./run-fixed-launcher.sh
```

Useful for debugging launch issues (removes LD_PRELOAD conflicts).

## How to Run Omarchy

### Method 1: Direct Launch (Recommended)
```bash
cd /home/fresh/github/omarchy-pixel
./start-omarchy.sh
```

This will:
- Start PulseAudio
- Launch Termux:X11 with Hyprland
- Open the Omarchy desktop session
- Display keybindings

### Keybindings
| Shortcut | Action |
|----------|---------|
| **SUPER + Return** | Foot key (fullscreen overlay) |
| **SUPER + K** | Switch to keyboard mode |
| **SUPER + G** | Goose Desktop (`goose-desktop`, proot-safe) |
| **SUPER + Shift + G** | goose CLI |

### Method 2: Using the App on Home Screen

After installation, you can add Omarchy as a clickable app on your home screen:

1. Open **Termux:Widget** (or the Widget app)
2. Navigate to the `.shortcuts/` directory
3. You should see an **Omarchy** shortcut
4. Long-press the shortcut to view properties
5. Tap to add it to your home screen

## Verification

To verify the setup worked:

1. Check that the Omarchy session is running on your phone
2. Look for the Hyprland window (dark theme with floating panels)
3. Try the keybindings:
   - **SUPER + Return** - toggle foot mode
   - **SUPER + K** - switch between keyboard and desktop modes
   - **SUPER + G** - launch Goose Desktop (`goose-desktop` with `--no-zygote`)
   - **SUPER + Shift + G** - goose CLI

## Troubleshooting

### RUN_COMMAND Permission Not Shown
- Ensure Termux was **fully reinstalled** (old version didn't show the prompt)
- Some users need to reboot Termux after reinstalling

### Omarchy Won't Start
- Check that `termux-x11` is running: `ps aux | grep termux-x11`
- Verify ADB is connected: `adb devices`
- Make sure the RUN_COMMAND service is declared in `/data/data/com.termux/files/usr/etc/system/services/`

### Home-Screen Shortcut Missing
- The shortcut is created in `~/.shortcuts/Omarchy` (via Termux:Widget)
- If missing, try deleting and recreating the shortcut
- Ensure Termux:Widget is installed and enabled

## Project Structure

```
omarchy-pixel/
├── setup-omarchy-pixel.sh    # Main installer (proot-distro, Arch, Hyprland, Omarchy)
├── start-omarchy.sh          # Launcher script (PulseAudio + Termux:X11 + Hyprland)
├── run-fixed-launcher.sh      # Debug wrapper (removes LD_PRELOAD conflicts)
├── omarchy-xstartup.sh       # X11 startup script for Hyprland
├── install-via-adb.sh        # ADB-based deployment helper
├── FINAL-INSTALL-NOTES.txt   # Installation notes
└── README.md                 # This file
```

## Notes

- **Foot key**: Use **SUPER + Return** to enter foot mode (overlay mode)
- **Keyboard mode**: Use **SUPER + K** to switch to keyboard navigation
- **Goose Desktop**: Use **SUPER + G** → `goose-desktop`. Under proot, Electron needs `--no-zygote` (and the usual `--no-sandbox` / software GL flags) or the process exits immediately. **SUPER + Shift + G** launches the CLI.
- The setup uses **proot-distro** to run Arch Linux inside Termux, allowing full desktop experience
- All scripts are designed for **aarch64** (ARM64) architecture

## License

Based on the original Omarchy project and Goose framework.

## Session Setup Commands (Post-Installation)

After running the initial install scripts, these commands were used to optimize the deployment:

### Termux Package Verification
```bash
# Verify Termux packages after reset
adb shell "command -v proot-distro; ls /data/data/com.termux/files/usr/bin/proot* 2>/dev/null"
```

### Pacman Mirror Fix
The setup script was updated to fix mirror URLs that were causing 404 errors:
```bash
# Before: Server = http://mirror.archlinuxarm.org/\$arch/\$repo  
# After:  Server = http://mirror.archlinuxarm.org/$arch/$repo
```

### Play Store Termux Compatibility
- Play Store Termux lacks `RUN_COMMAND` service
- Deployment uses keyboard injection via ADB as fallback
- Scripts auto-detect and adapt to available execution methods

### Running Rice Scripts Inside Pixel Session
After base Omarchy is running, you can enhance it with omarchy-rice:

1. **Push rice repo to device:**
```bash
adb push /path/to/omarchy-rice /sdcard/omarchy-rice
```

2. **Execute in foot terminal inside sway:**
```bash
# Via adb shell (if available)
adb shell "proot-distro login archlinux --user cody -- bash -lc 'cd ~/github/omarchy-rice && bash ./install-pixel.sh'"

# Or via swaymsg from inside the session
swaymsg "exec foot --title=rice bash -lc 'cd ~/github/omarchy-rice && bash ./install-pixel.sh'"
```

### Debugging Commands
```bash
# Check running processes
adb shell "ps -A -o pid,comm,args | grep -E 'sway|foot|termux-x11'"

# Monitor install progress
adb shell "tail -f /sdcard/omarchy-pixel/install-pixel-live.log"

# Check pacman configuration
adb shell "proot-distro login archlinux -- cat /etc/pacman.d/mirrorlist"
```

---

## Pixel Integration (Termux + Arch proot)

This rice can be run inside the Omarchy-on-Pixel environment via the `install-pixel.sh` script.

### Prerequisites
1. **Base Omarchy setup completed** via `omarchy-pixel` repo
2. **Arch proot with sway/foot running** under Termux:X11
3. **passwordless sudo configured** for user `cody`

### Installation Methods

#### Method 1: Direct ADB Push + Execution
```bash
# From host (with rice repo)
adb push . /sdcard/omarchy-rice
adb shell "proot-distro login archlinux --user cody --shared-tmp -- bash -lc 'cd /sdcard && cp -a omarchy-rice ~/github/ && cd ~/github/omarchy-rice && bash ./install-pixel.sh'"
```

#### Method 2: Inside Pixel Session (via foot)
```bash
# 1. Copy rice to device
rsync -a --exclude '.git' /sdcard/omarchy-rice/ ~/github/omarchy-rice/

# 2. Launch in foot terminal 
swaymsg "exec foot --title=rice bash -lc 'cd ~/github/omarchy-rice && bash ./install-pixel.sh'"
```

### Pixel-Specific Adaptations

The `install-pixel.sh` script configures rice for Arch ARM proot environment:

- **Pacman**: Uses `--disable-sandbox` wrapper for proot compatibility
- **Kernel packages**: Skips `linux-*` and `mkinitcpio` (IgnorePkg)
- **Mirror priority**: Prefers working ARM mirrors (fl.us, ocf.berkeley.edu)
- **Heavy packages**: Skips Docker, Steam, VS Code by default (`INSTALL_*=0`)
- **Passwordless**: Disables SDDM/TPM unlock setup (`INSTALL_PASSWORDLESS_BOOT=0`)

### Environment Variables
```bash
export INSTALL_DESKTOP=1           # Install desktop apps
export CLONE_REPOS=1               # Clone GitHub repos  
export INSTALL_SESSION_RESTORE=1   # Auto-launch apps
export SKIP_SYSTEM_UPDATE=1        # No pacman -Syu (would hang)
export PREFER_CHROMIUM_ON_ARM=1     # Use Chromium instead of Chrome
```

### Troubleshooting

**Pacman 404 errors**: Ensure mirrors use `$arch/$repo` not `\$arch/\$repo`
```bash
cat /etc/pacman.d/mirrorlist  # Should show real URLs like aarch64/core
```

**Sudo failures**: Fix sudoers as root
```bash
proot-distro login archlinux -- bash -c 'echo "cody ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/cody'
```

**Missing packages**: Check DisableSandbox is under `[options]` section
```bash
grep -A5 '\[options\]' /etc/pacman.conf
```

### Integration with window-arrange
The rice automatically installs `window-arrange` from the bundled scripts for Pixel-optimized tiling.


## Launcher Options

Omarchy-on-Pixel provides multiple ways to launch the desktop:

### 1. Native Android Launcher APK 
**Recommended for daily use**

The installation automatically includes `Omarchy.apk` - a native Android launcher app:
- **One-tap launch** directly from Android home screen
- **Status monitoring** - shows if session is running
- **Quick stop/restart** functionality  
- **Configuration options** for resolution and auto-boot
- **Professional interface** with Omarchy branding

Install location: `com.omarchy.launcher` package

### 2. Termux:Widget Shortcut
**Best for power users**

Fast home screen widget that directly executes scripts:
- **Zero overhead** - directly calls bash scripts
- **Fastest startup time** (bypasses launcher app)
- **Customizable** - edit `~/.shortcuts/Omarchy.sh`
- **Multiple shortcuts** - can create variants (debug mode, etc.)

Location: `$HOME/.shortcuts/Omarchy.sh`

### 3. Manual Termux Commands
**For debugging and development**

Direct execution from Termux terminal:
```bash
# Full desktop session
~/start-omarchy-fullscreen.sh

# Basic session (for testing)  
~/start-omarchy.sh

# Configuration only
~/configure-termux-x11.sh
```

### Auto-Launch Setup

All methods are configured during installation:

1. **APK Installation**: `setup-omarchy-pixel.sh` installs the launcher APK
2. **Widget Creation**: Termux shortcut automatically created in `~/.shortcuts/`
3. **Boot Integration**: `boot-omarchy.sh` ensures persistence after reboots
4. **Home Copies**: Scripts copied to `$HOME` for faster access

### Launcher File Hierarchy

```
$HOME/
├── start-omarchy-fullscreen.sh    # Main launcher (copied from /sdcard)
├── Omarchy.sh                     # Widget launcher (same as .shortcuts)
└── .shortcuts/
    └── Omarchy.sh                 # Termux:Widget entry point

/sdcard/omarchy-pixel/
├── Omarchy.apk                    # Native Android launcher
├── Omarchy.sh                     # Widget script template  
└── start-omarchy-fullscreen.sh   # Master launcher script
```

### Usage After Installation

**Android Home Screen**: 
- Look for "Omarchy" app icon → tap to launch
- Or add Termux:Widget → select "Omarchy.sh"

**Termux Terminal**:
```bash
~/start-omarchy-fullscreen.sh  # Direct launch
```

**Remote/ADB**:
```bash
adb shell "am start -n com.omarchy.launcher/.MainActivity"  # Native app
adb shell "su -c '~/Omarchy.sh'"                           # Widget script
```

The installation sets up all options simultaneously so you can use whichever method fits your workflow.

