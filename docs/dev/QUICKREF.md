# Iconic - Quick Reference Guide

Quick reference for common development tasks and troubleshooting.

## 🚀 Quick Start

```bash
cd .
open Iconic.xcodeproj
# Press ⌘R to build and run
```

## 📁 File Organization

### Core Files (Must Read First)
1. `IconicViewModel.swift` - Main coordinator, all business logic
2. `ContentView.swift` - Main UI, search/filter, drag & drop
3. `SymbolMapper.swift` - Keyword matching logic
4. `GeminiService.swift` - AI integration

### Supporting Files
- `FolderScanner.swift` - Recursive folder enumeration
- `IconRenderer.swift` - Icon composition (folder + symbol)
- `IconApplier.swift` - NSWorkspace.setIcon wrapper
- `FolderTypeDetector.swift` - Content-based detection
- `ColorPalette.swift` - Auto-color assignment

### UI Components
- `FolderRowView.swift` - Individual folder row
- `PreferencesView.swift` - Settings (5 tabs)
- `OnboardingView.swift` - First-launch setup

### Data & Persistence
- `PreferencesStore.swift` - UserDefaults wrappers
- `PresetsStore.swift` - Preset management
- `KeychainHelper.swift` - Secure API key storage
- `ColorPreferences.swift` - Default color storage

## 🔧 Common Tasks

### Add a New Keyword Mapping

**File**: `SymbolMapper.swift`

```swift
// Find builtInMappings array (line ~18)
static let builtInMappings: [(keyword: String, symbol: String)] = [
    // Add your mapping here:
    ("mykeyword", "my.symbol.name"),
    
    // Existing mappings...
    ("music", "music.note"),
    // ...
]
```

### Add a New Color Palette

**File**: `ColorPalette.swift`

```swift
// 1. Add palette to palettes dictionary (line ~14)
static let palettes: [String: [NSColor]] = [
    "mynewcategory": [
        NSColor(red: 1.0, green: 0.5, blue: 0.3, alpha: 1.0),
        NSColor(red: 0.5, green: 0.8, blue: 0.9, alpha: 1.0),
    ],
    // ...
]

// 2. Add keywords to categoryKeywords (line ~70)
private static let categoryKeywords: [String: [String]] = [
    "mynewcategory": ["keyword1", "keyword2", "keyword3"],
    // ...
]
```

### Add a New Folder Type Detection

**File**: `FolderTypeDetector.swift`

```swift
// 1. Add detection method
private static func isMyProjectType(_ url: URL) -> Bool {
    let fm = FileManager.default
    return fm.fileExists(atPath: url.appendingPathComponent("mymarker.file").path)
}

// 2. Add to detectFolderType() switch (line ~20)
static func detectFolderType(_ url: URL) -> String? {
    if isMyProjectType(url) { return "my.symbol.name" }
    // ... existing checks
}
```

**File**: `PreferencesView.swift` (line ~280)

```swift
// 3. Add to detection list UI
("My Project Type", "my.symbol.name", "Folders with mymarker.file"),
```

### Add a New Settings Toggle

**File**: `PreferencesStore.swift`

```swift
// Add a new store enum
enum MyFeatureStore {
    private static let key = "iconic.myfeature.enabled"
    
    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}
```

**File**: `PreferencesView.swift`

```swift
// Add toggle to appropriate tab
Toggle("Enable My Feature", isOn: Binding(
    get: { MyFeatureStore.isEnabled },
    set: { MyFeatureStore.isEnabled = $0 }
))
```

### Change Gemini Model

**File**: `GeminiService.swift` (line ~93)

```swift
// Change model name in endpoint
let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=\(apiKey)"
//                                                                          ^^^^^^^^^^^^^^^^
//                                                                          Change this
```

Available models:
- `gemini-1.5-flash` (stable)
- `gemini-2.5-flash` (latest)
- `gemini-1.5-pro` (more capable, slower)

## 🐛 Troubleshooting

### Build Errors

**Error**: `Type 'X' does not conform to protocol 'ObservableObject'`
- **Fix**: Add `import Combine` to the file

**Error**: `Cannot find 'X' in scope`
- **Fix**: Check if file is added to Xcode project target

**Error**: `Static property 'folder' is not available`
- **Fix**: Add `import UniformTypeIdentifiers`

### Runtime Issues

**Icons not applying**
- Check: Sandbox disabled in `Iconic.entitlements`
- Check: `ENABLE_APP_SANDBOX = NO` in project.pbxproj
- Check: Not a SIP-protected path (e.g., `/System`)

**Gemini API 404 error**
- Check: Model name is correct in `GeminiService.swift`
- Check: API key is valid (test in Settings)

**Colors not showing**
- Check: `AutoColorStore.isEnabled` is true
- Check: Rescan folder after enabling auto-color

**Search not working**
- Check: Using `vm.filteredItems` not `vm.items` in list

**Drag & drop not working**
- Check: `.onDrop(of: [.fileURL])` modifier is on main VStack
- Check: `handleDrop()` method exists in ContentView

## 🔍 Debugging Tips

### Print Debugging

```swift
// In IconicViewModel.scan()
print("📁 Scanned \(urls.count) folders")
print("🎨 Matching mode: \(matchingMode)")
print("🤖 AI enabled: \(SettingsViewModel.getAPIKeyIfEnabled() != nil)")
```

### Check UserDefaults

```swift
// In terminal or Xcode console
defaults read com.app.Iconic
```

### Check Keychain

```swift
// In SettingsViewModel or KeychainHelper
if let key = try? KeychainHelper.loadAPIKey() {
    print("🔑 API key exists: \(key.prefix(10))...")
}
```

### Monitor API Calls

```swift
// In GeminiService.matchFolders()
print("🌐 Calling Gemini with \(folderNames.count) folders")
print("📥 Response: \(String(data: data, encoding: .utf8) ?? "nil")")
```

## 📊 Performance Tips

### Large Folder Trees (1000+ folders)

1. **Scanning**: Already optimized with `Task.detached`
2. **Rendering**: Batched in `renderPreviews()` - consider pagination if >5000 folders
3. **API calls**: Gemini batches all folders in one call (efficient)
4. **Search**: Uses computed property (instant filtering)

### Memory Usage

- Icon previews cached in `FolderItem.preview`
- Clear previews if memory constrained: `item.preview = nil`
- Rendered icons are multi-resolution (16-512pt) - ~50KB each

## 🧪 Testing Scenarios

### Test Folder Structure

```
TestFolder/
├── Music/              # Should get music.note + purple
├── Photos/             # Should get photo.stack + red
├── Code/               # Should get chevron + blue
│   ├── .git/          # Should detect as Git repo
│   └── MyProject/
├── Work/               # Should get briefcase + professional blue
└── Random123/          # Should get folder.fill + rainbow color
```

### Test Cases

1. **Empty folder**: Should show empty state
2. **Single folder**: Should scan and show 1 result
3. **Nested folders**: Should recursively scan all levels
4. **Hidden folders**: Should skip (`.git`, `.DS_Store`)
5. **SIP-protected**: Should fail gracefully with error message
6. **No API key**: Should use local matching
7. **Invalid API key**: Should show error, fall back to local
8. **Network offline**: Should timeout, fall back to local
9. **Drag file (not folder)**: Should show error
10. **Search "music"**: Should filter to matching folders
11. **Filter "Failed"**: Should show only failed applications
12. **Dry run mode**: Should disable apply buttons
13. **Color picker**: Should update preview immediately
14. **Preset save/load**: Should restore all settings

## 🔐 Security Notes

### API Key Handling

- ✅ Stored in Keychain (not UserDefaults)
- ✅ Never logged to console
- ✅ Cleared from memory after use
- ✅ Passed via query param (not header) to Gemini API

### Sandbox

- ⚠️ Disabled (required for `NSWorkspace.setIcon`)
- ⚠️ App can access any folder user selects
- ✅ Security-scoped bookmarks for persistent access
- ✅ No automatic file access without user selection

## 📝 Code Style

### Naming Conventions

- **View Models**: `XxxViewModel` (e.g., `IconicViewModel`)
- **Views**: `XxxView` (e.g., `ContentView`)
- **Stores**: `XxxStore` (e.g., `PresetsStore`)
- **Services**: `XxxService` (e.g., `GeminiService`)
- **Helpers**: `XxxHelper` (e.g., `KeychainHelper`)

### Comments

- Use `// MARK: -` for section dividers
- Minimal inline comments (code should be self-documenting)
- Doc comments for public APIs only

### SwiftUI

- Prefer computed properties over methods for views
- Use `@ViewBuilder` for conditional views
- Extract complex views into separate structs
- Use `@EnvironmentObject` for shared state

## 🚢 Release Checklist

- [ ] Update version in `project.pbxproj`
- [ ] Test all features (see Testing Scenarios)
- [ ] Verify sandbox is disabled
- [ ] Test on clean macOS install
- [ ] Update README.md with new features
- [ ] Update CLAUDE.md with architecture changes
- [ ] Archive and export for distribution
- [ ] Notarize with Apple (if distributing)

## 📚 Resources

- [SF Symbols Browser](https://developer.apple.com/sf-symbols/)
- [Gemini API Docs](https://ai.google.dev/docs)
- [NSWorkspace Documentation](https://developer.apple.com/documentation/appkit/nsworkspace)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)

---

**Need Help?** Read `CLAUDE.md` for full architecture documentation.
