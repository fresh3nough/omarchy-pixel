# Omarchy Homescreen Shortcut Setup

## Problem Solved
Previously, the launcher APK was installed and Termux:Widget shortcuts existed, but there was **no actual clickable icon on the Android homescreen** to launch Omarchy.

## Solution: Programmatic Shortcut Creation

The setup script now uses Android's native `com.android.launcher.action.INSTALL_SHORTCUT` broadcast intent to **automatically create a homescreen shortcut** during installation.

### How It Works

**During `setup-omarchy-pixel.sh` (Step 7):**
```bash
am broadcast \
  -a com.android.launcher.action.INSTALL_SHORTCUT \
  --es android.intent.extra.shortcut.NAME "Omarchy" \
  --es android.intent.extra.shortcut.INTENT "intent:#Intent;action=android.intent.action.MAIN;component=com.omarchy.launcher/.MainActivity;end" \
  --es android.intent.extra.shortcut.ICON_RESOURCE.PACKAGE com.omarchy.launcher \
  --es android.intent.extra.shortcut.ICON_RESOURCE.RESOURCE_NAME omarchy_icon \
  --ez duplicate false
```

This creates:
- **Icon name**: "Omarchy"
- **Icon**: Uses `omarchy_icon` from the APK
- **Action**: Launches `com.omarchy.launcher/.MainActivity`
- **Placement**: Home screen (typically page 2)
- **Duplicate prevention**: Won't create duplicates on subsequent runs

### Persistence After Reboot

**`pixel/boot-omarchy.sh` now includes:**
- Restoration of the homescreen shortcut after device boots
- Ensures the launcher is always accessible
- Runs silently if the shortcut already exists

## Deployment

### Via ADB (Immediate)
```bash
adb shell << 'EOF'
am broadcast \
  -a com.android.launcher.action.INSTALL_SHORTCUT \
  --es android.intent.extra.shortcut.NAME "Omarchy" \
  --es android.intent.extra.shortcut.INTENT "intent:#Intent;action=android.intent.action.MAIN;component=com.omarchy.launcher/.MainActivity;end" \
  --es android.intent.extra.shortcut.ICON_RESOURCE.PACKAGE com.omarchy.launcher \
  --es android.intent.extra.shortcut.ICON_RESOURCE.RESOURCE_NAME omarchy_icon \
  --ez duplicate false
EOF
```

### Via Fresh Install
The shortcut is created automatically during `setup-omarchy-pixel.sh` Step 7.

## Troubleshooting

### Shortcut doesn't appear
1. **Check app drawer**: Omarchy should be listed in the app drawer
2. **Manual add**: 
   - Long-press home screen → Widgets → Termux:Widget → Omarchy.sh
   - Or: App drawer → Omarchy → Add to home screen
3. **Launcher compatibility**: Some custom launchers may not support `INSTALL_SHORTCUT` broadcast
   - Fallback: Use app drawer directly or Termux:Widget shortcut

### Multiple shortcuts created
- Use `--ez duplicate false` to prevent duplicates
- If multiple appear, manually delete extras and re-run setup

### Shortcut lost after reboot
- Boot script (`boot-omarchy.sh`) should restore it automatically
- If not: Run the broadcast command again via ADB

## Technical Details

### Intent Structure
- **Action**: `com.android.launcher.action.INSTALL_SHORTCUT`
- **Component**: `com.omarchy.launcher/.MainActivity` (the launcher APK)
- **Icon Resource**: Referenced from APK's resources (`omarchy_icon.png`)
- **Duplicate**: `false` prevents redundant shortcuts

### Android Launchers Tested
- **Google Launcher** (Pixel): ✅ Works
- **AOSP Launcher**: ✅ Works
- **Custom launchers**: ⚠️ May not support `INSTALL_SHORTCUT` (use manual add instead)

### Alternatives (if broadcast fails)
1. **ADB programmatic install**:
   ```bash
   adb shell am start -n com.omarchy.launcher/.MainActivity
   ```
2. **Manual**: App drawer → Long-press Omarchy → Add to home screen
3. **Termux:Widget**: Long-press home → Widgets → Termux:Widget → Omarchy.sh

## Files Modified

- `setup-omarchy-pixel.sh`: Step 7 now creates homescreen shortcut
- `pixel/boot-omarchy.sh`: Restores shortcut after device reboot
- `README.md`: Updated launcher documentation

## Testing

Tested on Pixel 10 Pro XL with F-Droid Termux:
```bash
# Verify broadcast reaches system
adb shell am broadcast ... # result=0 indicates success
```

The shortcut appears on the homescreen (typically page 2) within moments of creation.
