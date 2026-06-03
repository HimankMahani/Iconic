# Iconic

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-macOS%2014+-lightgrey.svg)]()
[![Tests](https://img.shields.io/badge/Tests-231-brightgreen.svg)]()

Pretty up your folders. Iconic scans a directory tree and assigns each subfolder
a custom icon — composited from the default macOS folder graphic plus a
matching SF Symbol — based on the folder's name.

![Iconic main window](https://raw.githubusercontent.com/HimankMahani/Iconic/main/docs/screenshots/main-window.png)

Customized folders in Finder — each folder gets a unique icon and color:

![Finder after applying icons](https://raw.githubusercontent.com/HimankMahani/Iconic/main/docs/screenshots/after-finder.png)

Emoji icon mode — use emoji instead of SF Symbols:

![Emoji icon mode](https://raw.githubusercontent.com/HimankMahani/Iconic/main/docs/screenshots/app-emoji-mode.png)

Optional Gemini AI integration for smarter matching:

![Settings - Gemini AI](https://raw.githubusercontent.com/HimankMahani/Iconic/main/docs/screenshots/settings-gemini.png)

## Why Iconic?

Default macOS folders all look the same. Iconic makes your project directories
instantly recognizable by matching each folder's purpose to a meaningful icon.
Code folders get a `chevron.left.forwardslash.chevron.right`, photos get
`photo`, music gets `music.note` — all rendered onto the standard macOS folder
graphic so it feels native.

- **Zero config** — point at a folder, review previews, click Apply
- **AI-powered matching** (optional) — Gemini analyzes folder names in batch
- **350+ built-in keyword mappings** — works fully offline
- **Quick Look preview** — spacebar to see Finder-size icons before applying
- **Undo/Redo** — reversible batch operations
- **No telemetry** — 100% local, open source, MIT licensed

## Features

| Feature | Description |
|---------|-------------|
| Smart matching | Fuzzy matching (Levenshtein), substring, exact, token — with 350+ keyword dictionary |
| AI matching | Optional Google Gemini 2.5 Flash for intelligent symbol selection |
| Multi-layer symbols | Stack up to 3 SF Symbols per folder with opacity, scale, and gradient |
| Color control | Auto-color by category or manual color picker per folder |
| Presets | Save, load, export, and import full configurations |
| Rules | Per-folder IF/THEN rules (highest priority wins) |
| Templates | Reusable symbol-stack templates with layers and gradients |
| Backup & restore | Snapshot a folder's icon set for one-click restore |
| Keyboard shortcuts | Full keyboard navigation (see ⌘/ menu) |

## Building from source

```sh
git clone https://github.com/HimankMahani/Iconic.git
cd Iconic
open Iconic.xcodeproj
```

Press ⌘R to build and run.

> **Note**: The first build takes ~30 minutes because two large metadata files
> are auto-generated from Apple's system plists. Subsequent builds are fast.

### Bundle identifier

If you plan to distribute your own build, rename the bundle identifier to
avoid conflicts with other Iconic installations:

1. Open `Iconic.xcodeproj` in Xcode
2. Select the **Iconic** target → **Signing & Capabilities**
3. Change **Bundle Identifier** from `app.iconic.Iconic` to your own
   (e.g. `com.yourname.Iconic`)
4. Do the same for the **IconicTests** target

### Running the tests

```sh
xcodebuild -project Iconic.xcodeproj -scheme Iconic -destination 'platform=macOS' test
```

The `IconicTests` target contains 231 tests covering SymbolMapper, ColorPalette,
IconRenderer, IconApplier, KeychainHelper, FolderScanner, QuickLookPreviewRenderer,
UndoManager, EmojiMapper, SymbolSearchEngine, FolderTypeDetector, IconClipboard,
IconMapExporter, TemplatesStore, PreferencesStore, RulesStore, PresetsStore,
BackupStore, and the IconicViewModel.

## Keyboard shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘O | Open folder |
| ⌘A | Select all folders |
| Space | Quick Look preview |
| ⌘Z / ⇧⌘Z | Undo / Redo |
| ⌘, | Settings |
| ⌘E | Export icon map |
| Delete | Clear custom icon |

## Project structure

```
Iconic/
├── App Entry
│   ├── IconicApp.swift              # App entry, environment setup, onboarding
│   └── OnboardingView.swift         # First-launch API key setup
│
├── Main Views
│   ├── ContentView.swift            # Main window: header, search, list, footer
│   ├── FolderRowView.swift          # Per-folder row: preview, buttons, color picker
│   ├── ComparisonView.swift         # Before/after icon diff
│   ├── SymbolBrowserView.swift      # Searchable SF Symbol picker
│   ├── KeyboardShortcutsView.swift  # In-app shortcut reference
│   ├── PreferencesView.swift        # Settings: 9 tabs
│   └── AboutView.swift              # About panel
│
├── Core Logic
│   ├── IconicViewModel.swift        # Coordinator: scan → match → render → apply
│   ├── FolderScanner.swift          # Async recursive folder enumeration
│   ├── SymbolMapper.swift           # 350+ keyword dictionary + fuzzy matching
│   ├── SymbolSearchEngine.swift     # Tag-based SF Symbol search (Apple metadata)
│   ├── EmojiMapper.swift            # Emoji-style matching alternative
│   ├── IconRenderer.swift           # NSImage compositor (folder + SF Symbol)
│   ├── IconApplier.swift            # NSWorkspace.setIcon wrapper
│   ├── FolderTypeDetector.swift     # Content-based folder type detection
│   ├── FolderContentAnalyzer.swift  # Deep folder content inspection
│   ├── FolderWatcher.swift          # FSEvents-based live watcher
│   ├── BackgroundFolderMonitor.swift# New-folder auto-icon pipeline
│   └── QuickLookPreviewRenderer.swift# Finder-size icon preview composition
│
├── AI & Services
│   ├── GeminiService.swift          # REST client for Gemini API (URLSession)
│   ├── SettingsViewModel.swift      # API key management + validation
│   ├── KeychainHelper.swift         # Secure API key storage (Security framework)
│   ├── AILearningStore.swift        # Records user accept/reject signals
│   └── SmartSuggestionsStore.swift  # Per-folder smart suggestions cache
│
├── Persistence & State
│   ├── PreferencesStore.swift       # Bookmarks, custom mappings, toggles
│   ├── PresetsStore.swift           # Save/load/export/import presets
│   ├── ColorPreferences.swift       # Global default color (UserDefaults)
│   ├── ColorPalette.swift           # 10 themed palettes + assignment logic
│   ├── BackupStore.swift            # Icon-set backup snapshots
│   ├── RulesStore.swift             # Per-folder IF/THEN rules
│   ├── TemplatesStore.swift         # Reusable symbol-stack templates
│   ├── AnalyticsStore.swift         # Local-only apply/reject counters
│   ├── IconClipboard.swift          # Copy/paste between folders
│   ├── IconMapExporter.swift        # Export icon set as JSON
│   └── UndoManager.swift            # Undo/redo for the last batch apply
│
├── Platform
│   ├── AppVersion.swift             # Version/build info for About panel
│   ├── MenuBarManager.swift         # Optional menu-bar mode
│   └── Iconic.entitlements          # Sandbox disabled (required for setIcon)
│
├── Resources
│   ├── Assets.xcassets/             # App icon (10 sizes) + accent color
│   └── PrivacyInfo.xcprivacy        # Required-reason API declarations
│
└── Generated/
    ├── SymbolMetadata.swift         # ~7,900 SF Symbols (Apple metadata)
    └── EmojiMetadata.swift          # ~1,900 emoji (Apple metadata)
```

## Privacy

Iconic does not collect telemetry, does not track users, and stores the
optional Gemini API key in the macOS Keychain. The app ships with an
`Iconic/PrivacyInfo.xcprivacy` manifest declaring the Required Reason APIs
it touches: `UserDefaults` (for preferences) and `FileManager` disk-space
reads (for folder size display). See [LICENSE](LICENSE) for license terms.

## Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for
guidelines on reporting bugs, requesting features, and submitting pull requests.

## License

MIT — see [LICENSE](LICENSE) for details.
