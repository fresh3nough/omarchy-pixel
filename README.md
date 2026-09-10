# Omarchy-Pixel - Hyprland Desktop on Pixel via Termux

A guide to set up and run Omarchy (Hyprland desktop) on a Pixel phone using Termux and ADB.

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
| **SUPER + G** | Goose desktop app |

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
   - **SUPER + G** - launch Goose desktop

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
- **Goose app**: Use **SUPER + G** to launch the Goose desktop interface
- The setup uses **proot-distro** to run Arch Linux inside Termux, allowing full desktop experience
- All scripts are designed for **aarch64** (ARM64) architecture

## License

Based on the original Omarchy project and Goose framework.
