# Iconic - Project Documentation

**Version**: 1.0  
**Platform**: macOS 14+ (Sonoma)  
**Language**: Swift 5, SwiftUI  
**Build System**: Xcode 15+

## Overview

Iconic is a macOS app that automatically assigns custom icons to folders based on their names. It composites SF Symbols onto the standard macOS folder icon and applies them using `NSWorkspace.setIcon()`.

## Core Functionality

### What It Does
1. User selects a folder (via file picker or drag & drop)
2. App recursively scans all subfolders
3. Matches each folder name to an SF Symbol using:
   - **AI Mode** (optional): Google Gemini 2.5 Flash API
   - **Smart Detection** (optional): Analyzes folder contents (Git repos, Xcode projects, etc.)
   - **Local Mode** (default): 350+ keyword dictionary with fuzzy matching
4. Renders SF Symbol onto macOS folder icon (16×16 to 512×512 multi-resolution)
5. Applies custom icon via `NSWorkspace.setIcon(_:forFile:options:)`

### Key Features
- 🤖 **AI-Powered Matching**: Gemini 2.5 Flash batch API calls
- 🎨 **Auto-Color Assignment**: 10 themed color palettes (200+ colors)
- 🔍 **Search & Filter**: Real-time search + status filters
- 🛡️ **Dry Run Mode**: Preview before applying
- 🧠 **Smart Content Detection**: Detects Git, Xcode, Node.js, Docker, etc.
- 💾 **Presets**: Save/load configurations
- ⚡ **Drag & Drop**: Drop folders onto app window
- 🎨 **Color Customization**: Per-folder or global default colors

## Architecture

### Project Structure

```
Iconic/
├── App Entry
│   ├── IconicApp.swift              # App entry, environment setup, onboarding
│   └── OnboardingView.swift         # First-launch API key setup
│
├── Main Views
│   ├── ContentView.swift            # Main window: header, search, list, footer
│   ├── FolderRowView.swift          # Per-folder row: preview, buttons, color picker
│   └── PreferencesView.swift        # Settings: 5 tabs (Gemini, Appearance, Mappings, Detection, Presets)
│
├── Core Logic
│   ├── IconicViewModel.swift       # Coordinator: scan → match → render → apply
│   ├── FolderScanner.swift         # Async recursive folder enumeration
│   ├── SymbolMapper.swift          # 350+ keyword dictionary + fuzzy matching
│   ├── IconRenderer.swift          # NSImage compositor (folder + SF Symbol)
│   ├── IconApplier.swift           # NSWorkspace.setIcon wrapper
│   └── FolderTypeDetector.swift    # Content-based folder type detection
│
├── AI & Services
│   ├── GeminiService.swift         # REST client for Gemini API (URLSession)
│   ├── SettingsViewModel.swift    # API key management + validation
│   └── KeychainHelper.swift        # Secure API key storage (Security framework)
│
├── Data & Persistence
│   ├── PreferencesStore.swift      # Bookmarks, custom mappings, toggles (UserDefaults)
│   ├── PresetsStore.swift          # Save/load/export/import presets
│   ├── ColorPreferences.swift      # Global default color (UserDefaults + NSKeyedArchiver)
│   └── ColorPalette.swift          # 10 themed color palettes + assignment logic
│
└── Resources
    ├── Iconic.entitlements          # Sandbox disabled (required for setIcon)
    └── Assets.xcassets
```

### Data Flow

```
User Action (Choose Folder / Drag & Drop)
    ↓
IconicViewModel.scan()
    ↓
FolderScanner.scan() → [URL]
    ↓
Matching Priority:
    1. Smart Content Detection (if enabled)
    2. Custom Mappings (user-defined)
    3. Gemini AI (if enabled + key exists)
    4. Local Dictionary (350+ keywords + fuzzy)
    ↓
Auto-Color Assignment (if enabled)
    ↓
IconRenderer.makeIcon() → NSImage (multi-resolution)
    ↓
User Reviews (Search/Filter/Dry Run)
    ↓
IconApplier.apply() → NSWorkspace.setIcon()
```

## Key Classes & Models

### IconicViewModel
**Purpose**: Main coordinator, observable object driving the UI

**Key Properties**:
- `items: [FolderItem]` - All scanned folders
- `filteredItems` - Computed property applying search/filter
- `isDryRunMode: Bool` - Preview mode toggle
- `matchingMode: .ai | .local` - Current matching mode
- `searchText: String` - Search filter
- `statusFilter: StatusFilter` - Status filter (.all, .applied, .failed, etc.)

**Key Methods**:
- `scan(_ root: URL) async` - Main scan flow
- `scanWithGemini()` / `scanWithLocalMatcher()` - Matching strategies
- `assignBeautifulColors()` - Auto-color assignment
- `apply(_ item:)` / `applyAll()` - Icon application
- `restore(_ item:)` / `restoreAll()` - Reset to default icons

### FolderItem
**Purpose**: Model for a single folder

**Properties**:
- `url: URL` - Folder path
- `symbolName: String` - SF Symbol name (e.g., "music.note")
- `symbolColor: NSColor?` - Custom color (nil = use default)
- `preview: NSImage?` - Rendered icon preview
- `status: FolderItemStatus` - .pending, .applying, .applied, .restored, .failed

### SymbolMapper
**Purpose**: Maps folder names to SF Symbols

**Features**:
- 350+ built-in keyword mappings
- Tokenization (handles camelCase, spaces, special chars)
- Matching strategies:
  1. Exact full-name match
  2. Token match (word-by-word)
  3. Substring match ("photographs" → "photo")
  4. Fuzzy match (Levenshtein similarity > 0.78)
- Custom mappings take priority

### GeminiService
**Purpose**: REST client for Google Gemini API

**Endpoint**: `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent`

**Request Format**:
```json
{
  "contents": [{
    "parts": [{"text": "Given these folder names: [...]. Return JSON array..."}]
  }]
}
```

**Features**:
- Batch processing (all folders in one API call)
- JSON response parsing
- Error handling (rate limits, network failures)
- Symbol validation (falls back to local if invalid)

### ColorPalette
**Purpose**: Automatic beautiful color assignment

**Palettes**: 10 themed categories (creative, code, media, music, work, nature, finance, gaming, education, travel)

**Algorithm**:
1. Match folder name to category via keywords
2. Use hash of folder name to pick consistent color
3. Track last 10 colors to ensure variety
4. Avoid similar colors for adjacent folders

## Settings & Persistence

### UserDefaults Keys
- `iconic.hasLaunched` - First launch flag
- `iconic.aiEnabled` - Gemini AI toggle
- `iconic.smartContentDetection.enabled` - Content detection toggle
- `iconic.autoColor.enabled` - Auto-color toggle
- `iconic.customMappings.v1` - Custom keyword mappings (JSON)
- `iconic.presets.v1` - Saved presets (JSON)
- `iconic.lastFolder.bookmark` - Security-scoped bookmark
- `iconic.defaultSymbolColor` - Global default color (NSKeyedArchiver)

### Keychain
- Service: `app.iconic.Iconic.gemini`
- Account: `gemini-api-key`
- Stores Gemini API key securely (never logged)

## UI Structure

### ContentView
**Layout**: VStack with header, content, footer

**Header**:
- App icon + title
- Current folder path
- `…` overflow menu (Recents, Favorites, Backups, Export Icon Map)
- `?` (keyboard shortcuts)
- `sparkles` (feature discovery)
- "Choose Folder" button (⌘O)

**Content**:
- Empty state (when no folder selected)
- Search bar + filter chips
- Scrollable list of FolderRowView items

**Footer**:
- Matching mode badge (AI/Local)
- Progress bar (when applying)
- Error message (if any)
- Dry run banner (when in preview mode)
- Action buttons: Preview Mode, Apply All, Restore Defaults

### FolderRowView
**Per-row layout (left to right)**: preview · name+symbol+match-source-dot · status icon · combined swatch button · pencil (edit) · `…` (more) · Apply.

**Single source of truth**: a private `rowMenuItems` view-builder is rendered in both the `…` button and the `.contextMenu`, so right-click and the menu button always stay in sync. Menu items: Apply, Restore Default, Re-match Folder, Reveal in Finder, Copy Path, Copy/Paste Icon Settings, Save as Template…, Apply Template ▸, Compare Before/After, Import Current Finder Icon, Add to Exclude Patterns.

**Match-source pill → dot**: the colored badge ("Dictionary", "AI", etc.) was collapsed to a 6×6 colored dot inline with the symbol name; full text moved to the tooltip. Saves a full row of vertical chrome.

**Combined swatch button**: the folder + symbol color swatches are wrapped in a single `Button` that opens the unified Edit popover (which contains the color pickers).

**Unified Edit popover** (opened by the pencil): one popover with six sections — Symbol, Adjustments (size/opacity/offset), Layers (max 3), Colors, Gradient, Custom Image — and a Reset / Done footer. Replaces the previous separate symbol-editor + adjust-sliders popovers.

### PreferencesView (5 Tabs)

1. **Gemini AI**: API key management, test/save/remove, enable toggle
2. **Appearance**: Auto-color toggle, default color picker
3. **Mappings**: Custom keyword → symbol overrides
4. **Detection**: Smart content detection toggle + detected types list
5. **Presets**: Save/load/export/import configurations

## Important Technical Details

### Sandbox & Permissions
- **App Sandbox**: DISABLED (required for `NSWorkspace.setIcon` to work system-wide)
- **Entitlements**: `com.apple.security.app-sandbox = NO`
- **Hardened Runtime**: Enabled
- **Security-scoped bookmarks**: Used for persistent folder access

### Concurrency
- **Main Actor**: All view models and UI state
- **Task.detached**: Heavy operations (scanning, rendering, API calls)
- **async/await**: Throughout for non-blocking operations
- **Actor isolation warnings**: Present but non-blocking (Swift 5 mode with upcoming features)

### Icon Rendering
- **Base**: `NSWorkspace.shared.icon(for: .folder)` - system folder icon
- **Symbol**: SF Symbol from `NSImage(systemSymbolName:)`
- **Composition**: Draw symbol centered on folder face with drop shadow
- **Multi-resolution**: 16, 32, 64, 128, 256, 512 pt representations
- **Color**: Tinted symbol with user-selected or auto-assigned color

### Error Handling
- **SIP-protected paths**: Gracefully fail with error message
- **Permission denied**: Skip folder, continue scanning
- **Invalid SF Symbols**: Fall back to local matching
- **Network errors**: Fall back to local mode
- **API rate limits**: Show user-friendly error

## Common Tasks

### Adding a New Keyword Mapping
1. Edit `SymbolMapper.swift`
2. Add to `builtInMappings` array: `("keyword", "symbol.name")`
3. Rebuild

### Adding a New Color Palette
1. Edit `ColorPalette.swift`
2. Add to `palettes` dictionary
3. Add keywords to `categoryKeywords`
4. Rebuild

### Adding a New Folder Type Detection
1. Edit `FolderTypeDetector.swift`
2. Add detection method (check for marker files)
3. Add to `detectFolderType()` switch
4. Update PreferencesView detection list
5. Rebuild

### Debugging
- **Build warnings**: Actor isolation warnings are expected (Swift 5 mode)
- **Icon not applying**: Check sandbox is disabled in entitlements
- **API 404**: Verify Gemini model name is correct
- **Colors not showing**: Check AutoColorStore.isEnabled

## Dependencies

**Zero third-party dependencies**. Uses only:
- Foundation
- SwiftUI
- AppKit
- Security (Keychain)
- UniformTypeIdentifiers

## Build Configuration

- **Deployment Target**: macOS 14.0
- **Swift Version**: 5.0
- **Xcode**: 15+
- **Architecture**: Universal (arm64 + x86_64)
- **Code Signing**: Automatic
- **Sandbox**: Disabled

## Testing Checklist

- [ ] Folder scanning (small/large trees)
- [ ] AI matching (valid/invalid API key)
- [ ] Local matching (common folder names)
- [ ] Smart detection (Git, Xcode, Node.js repos)
- [ ] Auto-color assignment (various categories)
- [ ] Search & filter (name, status)
- [ ] Dry run mode (preview, apply, cancel)
- [ ] Drag & drop (folder, file rejection)
- [ ] Color picker (per-folder, global default)
- [ ] Presets (save, load, export, import)
- [ ] Apply/restore (individual, batch)
- [ ] Error handling (SIP paths, permissions)
- [ ] First launch onboarding
- [ ] Settings persistence

## Known Limitations

- **SIP-protected folders**: Cannot change icons (e.g., `/System`)
- **Network dependency**: AI mode requires internet
- **API rate limits**: Gemini free tier: 15 requests/minute
- **Icon persistence**: Icons stored as extended attributes (lost on some file operations)
- **macOS only**: Uses AppKit, NSWorkspace (not cross-platform)

## Future Enhancements

- Finder extension (right-click context menu)
- Multi-select folders
- Folder tree view (hierarchical)
- Community preset sharing

---

**Last Updated**: 2026-05-30  
**Build Status**: ✅ Compiles successfully  
**Lines of Code**: ~25,900
