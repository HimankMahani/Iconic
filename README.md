# Iconic

Pretty up your folders. Iconic scans a directory tree and assigns each subfolder
a custom icon — composited from the default macOS folder graphic plus a
matching SF Symbol — based on the folder's name.

## What it does

1. Pick any folder via the system Open panel (⌘O) or drag & drop it onto the window.
2. Iconic recursively walks every subfolder.
3. Each folder name is matched to an SF Symbol using either:
   - **AI Mode** (optional): Google Gemini 2.5 Flash analyzes all folder names in one batch API call and returns intelligent SF Symbol matches
   - **Local Mode** (default): Built-in keyword dictionary with 350+ entries spanning music, photos, code, finance, travel, work, gaming, education, health, creative, system folders, etc.
4. Local matching uses (in order) custom user mappings → exact / token match → substring → fuzzy similarity (Levenshtein ratio). Unmatched folders fall back to `folder.fill`.
5. The chosen SF Symbol is rendered onto the standard macOS folder icon (multiple representation sizes from 16×16 up to 512×512) and applied via `NSWorkspace.setIcon(_:forFile:options:)`.
6. **Quick Look preview**: tap the spacebar on any row to see the proposed icon at Finder sizes (16/32/64/128/256/512) before applying.
7. Click **Apply All** to commit, or **Restore Defaults** to clear.

## AI-Powered Matching (Optional)

Iconic supports **Google Gemini AI** for intelligent folder icon matching:

- **First Launch**: Onboarding screen offers optional Gemini API key setup
- **Get a Free Key**: Visit [Google AI Studio](https://aistudio.google.com/apikey) (no credit card required)
- **Secure Storage**: API keys stored in macOS Keychain (never logged or exposed)
- **Batch Processing**: All folder names sent in one API call for efficiency
- **Smart Fallback**: Invalid SF Symbol names automatically fall back to local matching
- **Works Offline**: App fully functional without AI using 350+ built-in keyword mappings

## Settings (⌘,)

Nine tabs cover every configuration surface:

- **Gemini AI** — Add/test/remove your API key, toggle AI matching on/off
- **Appearance** — Auto-color assignment, global default color, accent
- **Mappings** — Custom keyword → SF Symbol overrides
- **Detection** — Smart content detection (Git, Xcode, Node.js, Docker, etc.)
- **Presets** — Save, load, export, and import named configurations
- **Backup** — Snapshot a folder's icon set for one-click restore
- **Rules** — Per-folder IF/THEN rules (priority: highest)
- **Templates** — Reusable symbol-stack templates with layers + gradients
- **Excludes** — Folder name patterns to skip during scans

## Requirements

- macOS 14 (Sonoma) or later
- Xcode 15+ (for building)
- App Sandbox is **disabled** — required so `setIcon` can write extended attributes for arbitrary user-selected folders. The provided entitlements file (`Iconic/Iconic.entitlements`) declares `com.apple.security.app-sandbox = NO`.
- **Optional**: Free Google Gemini API key for AI-powered matching

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
│   └── PreferencesView.swift        # Settings: 9 tabs
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
│   ├── QuickLookPreviewRenderer.swift# Finder-size icon preview composition
│   └── ComparisonView.swift         # Side-by-side before/after diff
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
│   ├── AppDelegate.swift            # App lifecycle, menu bar, notifications
│   ├── MenuBarManager.swift         # Optional menu-bar mode
│   └── Iconic.entitlements          # Sandbox disabled (required for setIcon)
│
├── Resources
│   ├── Assets.xcassets/             # App icon (10 sizes) + accent color
│   └── PrivacyInfo.xcprivacy        # Required-reason API declarations
│
└── Generated/
    ├── SymbolMetadata.swift         # ~7,000 SF Symbols (Apple metadata)
    └── EmojiMetadata.swift          # ~1,900 emoji (Apple metadata)
```

## Build & run

```sh
open Iconic.xcodeproj
```

Press ⌘R. On first launch, optionally add a Gemini API key or skip to use local matching. Choose a folder, review the preview list, and hit **Apply All**.

### Run the tests

```sh
xcodebuild -project Iconic.xcodeproj -scheme Iconic -destination 'platform=macOS' test
```

Test target `IconicTests` covers SymbolMapper, ColorPalette, IconRenderer, IconApplier, KeychainHelper, FolderScanner, and QuickLookPreviewRenderer.

> **Heads-up**: The first test/build of the main app is slow (~30+ min cold) because of the two large auto-generated symbol/emoji metadata files (~926 KB combined). Subsequent incremental builds are fast.

## Notes & limitations

- **SIP-protected paths** (e.g. `/System`) and folders without write permission will fail during apply; the row shows a red warning icon with the OS error in its tooltip. The scan continues past unreadable subfolders.
- Custom icons live as extended attributes on the folder. Removing the folder, copying it across volumes that strip xattrs, or running **Restore Defaults** clears them.
- The first folder you open is remembered via a security-scoped bookmark and re-opened on next launch.
- **Gemini API**: Rate limits apply (free tier: 15 requests/minute). Large folder trees are batched in one call. Network errors gracefully fall back to local matching.
- No third-party dependencies. Pure Swift / SwiftUI / AppKit / Security framework.

## Custom mappings

Open **Iconic → Settings… → Mappings** (⌘,) to add your own keyword → SF Symbol overrides. Custom mappings take priority over both AI and built-in dictionary. Browse symbol names with Apple's [SF Symbols](https://developer.apple.com/sf-symbols/) app.

## Privacy

The app ships with an `Iconic/PrivacyInfo.xcprivacy` manifest declaring the `Required Reason` APIs it touches: `UserDefaults` (for preferences) and `FileManager` disk-space reads (for folder size display). It does not collect telemetry, does not track users, and stores the optional Gemini API key in the macOS Keychain. See [LICENSE](LICENSE) for license terms.

---

## Release v1.0

First public release. Direct download, no App Store, no telemetry.

### Download

[Download Iconic v1.0 for macOS 14+ (Apple Silicon) →](#)

- 48 MB Debug build (see build notes below for why)
- 100% open source, MIT licensed — see [LICENSE](LICENSE)

### First launch (Gatekeeper)

Iconic is distributed outside the App Store and is **not signed with an Apple Developer ID**. macOS Gatekeeper blocks apps that don't have a known developer the first time you open them. The workaround is a one-time confirmation:

1. Open Finder and go to **Applications**.
2. **Right-click** (or Control-click) on `Iconic.app`.
3. Choose **Open** from the context menu.
4. Click **Open** in the "are you sure?" dialog that appears.
5. From then on, a normal double-click works.

Alternative path via System Settings:

1. Try to open `Iconic.app` the normal way and dismiss the Gatekeeper warning.
2. Open **System Settings → Privacy & Security**.
3. Scroll to the bottom of the window.
4. Next to the message about `Iconic.app` being blocked, click **Open Anyway**.
5. Confirm with Touch ID or your password.

This only happens once per machine. macOS remembers the approval.

### Known build notes

This v1.0 ships a **Debug configuration** binary, not Release. Reason: the Release build currently fails on Xcode 26.5 due to a known Swift compiler bug with `.d` dependency files ([swiftlang/swift#76289](https://github.com/swiftlang/swift/issues/76289)).

The Debug binary is functionally identical to Release for this app — Iconic is SwiftUI + AppKit with a small in-memory dataset and no performance-sensitive path. The only practical difference is size: 48 MB vs. ~30 MB for Release.

Future versions will ship a Release build once the Xcode 26.5 toolchain bug is fixed.

### Requirements

- **macOS 14.0** (Sonoma) or later
- **Apple Silicon** (M1 / M2 / M3 / M4) — Intel is not currently supported
- No other dependencies. No installer. Drag from `.dmg` to Applications.

### Verifying the download

A SHA-256 checksum for the `.dmg` will be published alongside the download. To verify:

```sh
shasum -a 256 ~/Downloads/Iconic-1.0.dmg
```

Compare the output against the checksum posted on the download page.

### Reporting issues

Found a bug or have a feature request? Open an issue:

https://github.com/&lt;owner&gt;/Iconic/issues

Please include your macOS version, Apple Silicon chip, and (if applicable) the folder name that triggered the problem.
