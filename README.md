# Iconic

Pretty up your folders. Iconic scans a directory tree and assigns each subfolder
a custom icon — composited from the default macOS folder graphic plus a
matching SF Symbol — based on the folder's name.

## What it does

1. Pick any folder via the system Open panel.
2. Iconic recursively walks every subfolder.
3. Each folder name is matched to an SF Symbol using either:
   - **AI Mode** (optional): Google Gemini 2.0 Flash analyzes all folder names in one batch API call and returns intelligent SF Symbol matches
   - **Local Mode** (default): Built-in keyword dictionary with 350+ entries spanning music, photos, code, finance, travel, work, gaming, education, health, creative, system folders, etc.
4. Local matching uses (in order) custom user mappings → exact / token match → substring → fuzzy similarity (Levenshtein ratio). Unmatched folders fall back to `folder.fill`.
5. The chosen SF Symbol is rendered onto the standard macOS folder icon (multiple representation sizes from 16×16 up to 512×512) and applied via `NSWorkspace.setIcon(_:forFile:options:)`.
6. Click **Apply All** to commit, or **Restore Defaults** to clear.

## AI-Powered Matching (Optional)

Iconic supports **Google Gemini AI** for intelligent folder icon matching:

- **First Launch**: Onboarding screen offers optional Gemini API key setup
- **Get a Free Key**: Visit [Google AI Studio](https://aistudio.google.com/apikey) (no credit card required)
- **Secure Storage**: API keys stored in macOS Keychain (never logged or exposed)
- **Batch Processing**: All folder names sent in one API call for efficiency
- **Smart Fallback**: Invalid SF Symbol names automatically fall back to local matching
- **Works Offline**: App fully functional without AI using 350+ built-in keyword mappings

### Settings

Open **Iconic → Settings… → Gemini AI** (⌘,) to:
- Add/test/remove your API key
- Toggle AI matching on/off
- View matching mode indicator (purple "AI" or gray "Local" badge in footer)

## Requirements

- macOS 14 (Sonoma) or later
- Xcode 15+ (for building)
- App Sandbox is **disabled** — required so `setIcon` can write extended attributes for arbitrary user-selected folders. The provided entitlements file (`Iconic/Iconic.entitlements`) declares `com.apple.security.app-sandbox = NO`.
- **Optional**: Free Google Gemini API key for AI-powered matching

## Project structure

```
Iconic/
├── IconicApp.swift          App entry, wires up env objects + Settings scene
├── ContentView.swift        Main window: header, list, footer with mode badge
├── FolderRowView.swift      Per-row preview + Apply / Restore + symbol editor
├── PreferencesView.swift    Settings: Gemini AI + custom mappings tabs
├── OnboardingView.swift     First-launch sheet for API key setup
├── IconicViewModel.swift    Coordinator: scan → AI/local match → render → apply
├── SettingsViewModel.swift  API key management + validation
├── GeminiService.swift      REST client for Gemini API (URLSession, no deps)
├── KeychainHelper.swift     Secure API key storage (Security framework)
├── FolderScanner.swift      Async recursive enumerator (off main)
├── SymbolMapper.swift       Keyword dictionary + fuzzy matching (350+ entries)
├── IconRenderer.swift       NSImage compositor (folder + SF Symbol)
├── IconApplier.swift        Thin NSWorkspace.setIcon wrapper
├── PreferencesStore.swift   BookmarkStore + CustomMappingsStore (UserDefaults)
├── Iconic.entitlements      Sandbox disabled
└── Assets.xcassets
```

## Build & run

```sh
open Iconic.xcodeproj
```

Press ⌘R. On first launch, optionally add a Gemini API key or skip to use local matching. Choose a folder, review the preview list, and hit **Apply All**.

## Notes & limitations

- **SIP-protected paths** (e.g. `/System`) and folders without write permission will fail during apply; the row shows a red warning icon with the OS error in its tooltip. The scan continues past unreadable subfolders.
- Custom icons live as extended attributes on the folder. Removing the folder, copying it across volumes that strip xattrs, or running **Restore Defaults** clears them.
- The first folder you open is remembered via a security-scoped bookmark and re-opened on next launch.
- **Gemini API**: Rate limits apply (free tier: 15 requests/minute). Large folder trees are batched in one call. Network errors gracefully fall back to local matching.
- No third-party dependencies. Pure Swift / SwiftUI / AppKit / Security framework.

## Custom mappings

Open **Iconic → Settings… → Mappings** (⌘,) to add your own keyword → SF Symbol overrides. Custom mappings take priority over both AI and built-in dictionary. Browse symbol names with Apple's [SF Symbols](https://developer.apple.com/sf-symbols/) app.
