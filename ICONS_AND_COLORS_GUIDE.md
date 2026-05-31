# How to Get More Icons and Colors in Iconic

## 🎨 Icons (SF Symbols)

### Current Status
- **Built-in mappings**: 350+ keyword → symbol mappings
- **Available SF Symbols**: 6,000+ symbols from Apple
- **Access method**: Multiple ways to use any SF Symbol

---

## Method 1: Symbol Browser (Built-in) ⭐ EASIEST

**Access ALL 6,000+ SF Symbols with a visual browser!**

### How to Use:
1. Open Iconic and scan a folder
2. **Right-click** any folder in the list
3. Select **"Browse Symbols…"**
4. Search or browse by category:
   - Communication
   - Weather
   - Objects
   - Nature
   - Symbols
   - Media
   - Code
   - Work
   - Travel
   - Creative
   - Gaming
   - Education
   - Health
5. Click any symbol to apply it instantly

### Tips:
- Use the search bar to find specific symbols
- Filter by category for themed icons
- Hover over symbols to see their names

---

## Method 2: Custom Mappings

**Add your own keyword → symbol mappings**

### How to Use:
1. Go to **Preferences** (⌘,)
2. Click the **"Mappings"** tab
3. Add custom mappings:
   - Keyword: `design`
   - Symbol: `paintbrush.pointed.fill`
   - Click **Add**

### Popular Symbols to Add:

**Development:**
```
swift → swift
python → snake
javascript → js.circle
typescript → ts.circle
react → atom
docker → shippingbox.fill
kubernetes → cube.transparent
database → cylinder.fill
terminal → terminal.fill
```

**Design:**
```
figma → pencil.and.outline
sketch → paintbrush
adobe → a.circle.fill
illustrator → paintpalette.fill
photoshop → photo.fill
```

**Business:**
```
sales → chart.line.uptrend.xyaxis
marketing → megaphone.fill
finance → dollarsign.circle.fill
legal → scale.3d
hr → person.2.fill
```

**Media:**
```
podcast → mic.fill
youtube → play.rectangle.fill
instagram → camera.fill
twitter → bird.fill
linkedin → briefcase.fill
```

---

## Method 3: Rules with Patterns

**Create pattern-based rules for automatic matching**

### How to Use:
1. Go to **Preferences** → **Rules** tab
2. Add rules with patterns:
   - Pattern: `*-ios` (glob)
   - Symbol: `apple.logo`
   - Enable "Auto-Apply"

### Advanced Examples:

**Project Types:**
```
Pattern: *-frontend → Symbol: paintbrush.pointed.fill
Pattern: *-backend → Symbol: server.rack
Pattern: *-mobile → Symbol: iphone
Pattern: *-desktop → Symbol: desktopcomputer
```

**Date Patterns (Regex):**
```
Pattern: ^\d{4}$ → Symbol: calendar (matches "2024")
Pattern: ^Q[1-4] → Symbol: chart.bar (matches "Q1", "Q2")
Pattern: ^\d{4}-\d{2}$ → Symbol: calendar.badge.clock (matches "2024-05")
```

---

## Method 4: Find SF Symbols Online

**Browse Apple's official SF Symbols catalog**

### Resources:
1. **SF Symbols App** (Free from Apple)
   - Download: https://developer.apple.com/sf-symbols/
   - Browse all 6,000+ symbols
   - Copy symbol names directly
   - See symbol variations

2. **Online Browsers:**
   - https://hotpot.ai/free-icons/sf-symbols
   - https://sfsymbols.com/
   - Search and copy symbol names

### How to Use:
1. Find a symbol you like (e.g., `brain.head.profile`)
2. Copy the symbol name
3. In Iconic:
   - Right-click folder → "Edit Symbol"
   - Paste the symbol name
   - Or add to Custom Mappings

---

## 🌈 Colors

### Current Status
- **Built-in palettes**: 10 themed palettes with 200+ colors
- **Custom colors**: Unlimited via color picker
- **Auto-color**: Automatic beautiful color assignment

---

## Method 1: Color Picker (Per-Folder)

**Choose any color for individual folders**

### How to Use:
1. Scan a folder
2. Click the **color circle** next to any folder
3. Choose from:
   - **Symbol Color** (the icon color)
   - **Folder Color** (the folder background)
4. Pick any color from the macOS color picker

### Tips:
- Use complementary colors for symbol + folder
- Save favorite combinations as templates
- Use hex codes for brand colors

---

## Method 2: Auto-Color Palettes

**10 themed color palettes with smart assignment**

### Current Palettes:
1. **Creative** - Vibrant purples, pinks, oranges
2. **Code** - Blues, teals, greens
3. **Media** - Rich reds, magentas, golds
4. **Music** - Deep purples, blues, pinks
5. **Work** - Professional blues, grays, navy
6. **Nature** - Greens, earth tones, browns
7. **Finance** - Greens, golds, dark blues
8. **Gaming** - Neon colors, bright accents
9. **Education** - Warm yellows, oranges, reds
10. **Travel** - Sky blues, sunset oranges

### How to Enable:
1. Go to **Preferences** → **Appearance**
2. Enable **"Automatically assign beautiful colors"**
3. Rescan your folders

### How It Works:
- Analyzes folder names
- Matches to categories (e.g., "photos" → Media palette)
- Assigns consistent colors based on name hash
- Avoids similar colors for adjacent folders

---

## Method 3: Add Custom Colors to Palettes

**Extend the built-in palettes with your own colors**

### How to Add:
1. Open `/Users/himank/Desktop/Iconic/Iconic/ColorPalette.swift`
2. Find the palette you want to extend
3. Add colors in hex format:

```swift
"creative": [
    "#FF6B9D", // Existing pink
    "#C44569", // Existing red
    "#YOUR_HEX_HERE", // Your new color
    "#ANOTHER_COLOR", // Another color
]
```

### Popular Color Schemes:

**Pastel:**
```
#FFB3BA (Light Pink)
#FFDFBA (Light Orange)
#FFFFBA (Light Yellow)
#BAFFC9 (Light Green)
#BAE1FF (Light Blue)
```

**Neon:**
```
#FF006E (Neon Pink)
#FB5607 (Neon Orange)
#FFBE0B (Neon Yellow)
#8338EC (Neon Purple)
#3A86FF (Neon Blue)
```

**Material Design:**
```
#F44336 (Red)
#E91E63 (Pink)
#9C27B0 (Purple)
#673AB7 (Deep Purple)
#3F51B5 (Indigo)
#2196F3 (Blue)
#00BCD4 (Cyan)
#009688 (Teal)
#4CAF50 (Green)
#FFC107 (Amber)
```

---

## Method 4: Create New Color Palettes

**Add entirely new themed palettes**

### How to Add:
1. Open `ColorPalette.swift`
2. Add a new palette:

```swift
"brand": [
    "#YOUR_PRIMARY",
    "#YOUR_SECONDARY",
    "#YOUR_ACCENT",
    // Add 10-20 colors
]
```

3. Add category keywords:

```swift
"brand": ["company", "client", "project", "work"]
```

4. Rebuild the app

### Example - Seasonal Palette:
```swift
"spring": [
    "#FFB6C1", // Light Pink
    "#98FB98", // Pale Green
    "#87CEEB", // Sky Blue
    "#FFFACD", // Lemon Chiffon
    "#DDA0DD", // Plum
]
```

---

## Method 5: Templates

**Save color combinations for reuse**

### How to Use:
1. Configure a folder with perfect colors
2. Right-click → **"Save as Template"**
3. Name it (e.g., "Brand Colors")
4. Apply to other folders:
   - Right-click → "Apply Template" → Select your template

### Use Cases:
- Brand colors for client folders
- Consistent project themes
- Seasonal color schemes
- Department-specific colors

---

## Method 6: Global Default Color

**Set a default color for all new icons**

### How to Use:
1. Go to **Preferences** → **Appearance**
2. Click the color picker under "Default Symbol Color"
3. Choose your preferred default color
4. All new icons will use this color (unless auto-color is enabled)

---

## 🎯 Quick Reference

### Most Popular SF Symbols

**General:**
- `folder.fill` - Folder
- `doc.fill` - Document
- `star.fill` - Favorite
- `heart.fill` - Love
- `checkmark.circle.fill` - Complete
- `xmark.circle.fill` - Error
- `exclamationmark.triangle.fill` - Warning
- `info.circle.fill` - Info

**Development:**
- `chevron.left.forwardslash.chevron.right` - Code
- `terminal.fill` - Terminal
- `server.rack` - Server
- `network` - Network
- `cpu` - CPU
- `memorychip` - Memory
- `externaldrive.fill` - Storage

**Creative:**
- `paintbrush.pointed.fill` - Design
- `photo.fill` - Photos
- `video.fill` - Video
- `music.note` - Music
- `mic.fill` - Audio
- `camera.fill` - Camera

**Business:**
- `briefcase.fill` - Work
- `chart.bar.fill` - Analytics
- `dollarsign.circle.fill` - Finance
- `person.2.fill` - Team
- `calendar` - Schedule

### Color Picker Shortcuts

- **⌘C** - Copy color
- **⌘V** - Paste color
- **Eyedropper** - Pick color from screen
- **Hex input** - Enter exact hex codes

---

## 💡 Pro Tips

### Icons:
1. **Use the SF Symbols app** - Best way to browse all symbols
2. **Search by keyword** - The symbol browser has great search
3. **Create rules for patterns** - Automate icon assignment
4. **Save favorites as templates** - Quick access to best combinations

### Colors:
1. **Enable auto-color first** - See what the algorithm suggests
2. **Tweak individual folders** - Override auto-colors as needed
3. **Use brand colors** - Set global default to your brand color
4. **Create seasonal presets** - Switch themes throughout the year

### Workflow:
1. **Start with auto-color** - Let Iconic assign colors
2. **Browse symbols** - Find perfect icons
3. **Save as template** - Reuse your favorites
4. **Create rules** - Automate for future folders

---

## 🔗 Resources

- **SF Symbols App**: https://developer.apple.com/sf-symbols/
- **Color Picker Tools**: 
  - https://coolors.co/ (Generate palettes)
  - https://color.adobe.com/ (Adobe Color)
  - https://materialui.co/colors (Material Design)
- **Icon Inspiration**:
  - https://www.apple.com/design/human-interface-guidelines/sf-symbols
  - Browse other apps for icon ideas

---

**Need Help?**
- Check FEATURES.md for complete feature list
- See MENU_BAR_GUIDE.md for background monitoring
- Review CLAUDE.md for technical details
