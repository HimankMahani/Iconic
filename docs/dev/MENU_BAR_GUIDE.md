# Iconic Menu Bar App - User Guide

## Overview

Iconic now runs as a **menu bar app** with **system-wide background monitoring**. This means you can close the main window and Iconic will continue running in the background, automatically applying icons to new folders as you create them.

## Features

### 🎯 Menu Bar Mode

When enabled, Iconic stays running in your menu bar even when you close the main window.

**How to Enable:**
1. Open Iconic
2. Go to Preferences (⌘,)
3. Click the "Background" tab
4. Enable "Keep app in menu bar when window closes"

**Menu Bar Icon:**
- Click the folder icon in your menu bar to access:
  - Show Window
  - Background Monitoring (toggle on/off)
  - Preferences
  - Quit Iconic

### 🔍 Background Monitoring

Automatically detects new folders in monitored locations and applies icons based on your rules.

**How It Works:**
1. You create rules in the "Rules" tab (e.g., "photos" → camera icon)
2. Enable "Auto-Apply" on the rules you want to run automatically
3. Enable "Background Monitoring" in preferences
4. Create a new folder in a monitored location
5. Iconic automatically applies the matching icon!

**Default Monitored Locations:**
- Desktop
- Documents
- Downloads

**Add More Locations:**
1. Go to Preferences → Background tab
2. Enable "Monitor folders for new subfolders"
3. Click "Add Location..."
4. Choose any folder you want to monitor

### 🔔 Notifications

Get notified when Iconic automatically applies an icon.

**Enable Notifications:**
1. Go to Preferences → Background tab
2. Enable "Show notifications when icons are applied"
3. Grant notification permissions when prompted

**What You'll See:**
- Notification title: "Icon Applied"
- Notification body: "Applied [symbol] to [folder name]"

## Setup Guide

### Quick Start (5 minutes)

1. **Create Auto-Apply Rules**
   - Open Preferences → Rules tab
   - Add rules for common folder names:
     - Pattern: `photos` → Symbol: `camera.fill` → Enable "Auto-Apply"
     - Pattern: `code` → Symbol: `chevron.left.forwardslash.chevron.right` → Enable "Auto-Apply"
     - Pattern: `music` → Symbol: `music.note` → Enable "Auto-Apply"
     - Pattern: `videos` → Symbol: `video.fill` → Enable "Auto-Apply"

2. **Enable Menu Bar Mode**
   - Preferences → Background tab
   - Enable "Keep app in menu bar when window closes"

3. **Enable Background Monitoring**
   - Preferences → Background tab
   - Enable "Monitor folders for new subfolders"
   - Enable "Show notifications when icons are applied"

4. **Test It!**
   - Close the Iconic window (app stays in menu bar)
   - Create a new folder on your Desktop called "photos"
   - Watch as Iconic automatically applies a camera icon!
   - You'll get a notification confirming the icon was applied

### Advanced Configuration

**Pattern Matching Types:**
- **Contains**: Matches if the pattern appears anywhere in the folder name
- **Exact**: Matches only if the folder name exactly matches the pattern
- **Glob**: Use wildcards (* and ?) for flexible matching
- **Regex**: Use regular expressions for complex patterns

**Examples:**
- `*-backup` (glob) → Matches "project-backup", "files-backup"
- `^[0-9]{4}$` (regex) → Matches year folders like "2024", "2025"
- `temp` (contains) → Matches "temp", "temporary", "templates"

**Priority:**
Rules are applied in order of priority (drag to reorder). Higher priority rules are checked first.

## Use Cases

### 1. Project Organization
Create rules for project types:
- `*-ios` → `apple.logo`
- `*-android` → `android.logo`
- `*-web` → `globe`
- `*-api` → `server.rack`

### 2. Client Work
Organize client folders:
- `client-*` → `person.2.fill`
- `invoice-*` → `dollarsign.circle`
- `contract-*` → `doc.text`

### 3. Media Management
Auto-categorize media:
- `*-raw` → `camera.aperture`
- `*-edited` → `wand.and.stars`
- `*-final` → `checkmark.seal.fill`

### 4. Date-Based Folders
Use regex for date patterns:
- `^\d{4}-\d{2}-\d{2}$` → `calendar` (matches "2024-05-31")
- `^Q[1-4]-\d{4}$` → `chart.bar` (matches "Q1-2024")

## Tips & Tricks

### 🎨 Combine with Auto-Color
Enable "Automatically assign beautiful colors" in Appearance tab for colorful icons.

### 📊 Track Usage
Check the Analytics tab to see which symbols are most used.

### 💾 Create Presets
Save your rule configurations as presets for easy switching between different workflows.

### ⚡ Keyboard Shortcuts
- `⌘,` - Open Preferences
- `⌘/` - Show Keyboard Shortcuts help

### 🔄 Undo Mistakes
If an icon is applied incorrectly, use `⌘Z` to undo (works for the last 20 actions).

## Troubleshooting

### Icons Not Auto-Applying?

**Check:**
1. Background monitoring is enabled (Preferences → Background)
2. The folder is in a monitored location
3. You have at least one rule with "Auto-Apply" enabled
4. The folder name matches one of your rules
5. The app is running (check menu bar icon)

### Notifications Not Showing?

**Check:**
1. Notifications are enabled in Iconic (Preferences → Background)
2. System notifications are allowed:
   - System Settings → Notifications → Iconic
   - Enable "Allow Notifications"

### Menu Bar Icon Not Appearing?

**Check:**
1. Menu bar mode is enabled (Preferences → Background)
2. Try quitting and restarting Iconic
3. Check if the icon is hidden in the menu bar overflow (click the double arrows)

### High CPU Usage?

**Solutions:**
1. Reduce the number of monitored locations
2. Disable background monitoring when not needed
3. Use more specific rules (exact match instead of contains)

## Privacy & Security

### Local Only
- All monitoring happens locally on your Mac
- No data is sent to external servers
- Analytics are stored locally (see Analytics tab)

### Permissions Required
- **File System Access**: To read folder names and apply icons
- **Notifications**: To show alerts when icons are applied (optional)

### What's Monitored
- Only the folders you specify in monitored locations
- Only folder creation events (not file contents)
- Only folder names (not file names inside folders)

## Performance

### Resource Usage
- **Idle**: Minimal CPU and memory usage
- **Active Monitoring**: Uses FSEvents (efficient macOS API)
- **Icon Application**: Brief CPU spike when applying icons

### Recommended Settings
- Monitor 3-5 locations maximum
- Use specific rules (avoid overly broad patterns)
- Disable monitoring when working on large file operations

## FAQ

**Q: Can I monitor my entire home directory?**
A: Yes, but it's not recommended. Monitor specific folders (Desktop, Documents, Downloads) for better performance.

**Q: Will this work with network drives?**
A: FSEvents may not work reliably on network drives. Best used with local folders.

**Q: Can I use this with Dropbox/iCloud folders?**
A: Yes! Add your Dropbox or iCloud Drive folder to monitored locations.

**Q: Does this work when my Mac is asleep?**
A: No, the app must be running. Icons will be applied when you wake your Mac.

**Q: Can I disable the menu bar icon?**
A: Yes, disable "Keep app in menu bar when window closes" in preferences. The app will quit when you close the window.

**Q: How many rules can I create?**
A: No limit! However, more rules = slightly slower matching. Keep it reasonable (20-50 rules).

**Q: Can I export my rules?**
A: Yes! Use the Presets tab to save and export your entire configuration.

## Support

For issues or feature requests:
- Check the main README.md
- Review FEATURES.md for complete feature list
- Check CLAUDE.md for technical documentation

---

**Version**: 1.0  
**Last Updated**: 2026-05-31  
**Requires**: macOS 14.0 or later
