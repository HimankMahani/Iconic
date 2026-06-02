# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-06-02

### Added

- **Folder scanning and matching**
  - Recursive folder enumeration with configurable maximum depth (1-20 levels) and exclude-pattern globbing
  - Drag and drop and file-picker folder selection with security-scoped bookmark persistence
  - Recent folders list (10 most recent) and starred favorites

- **Matching engines** (priority-ordered, pluggable)
  - Rules engine: per-pattern exact, contains, glob, and regex rules with per-rule colors and auto-apply
  - Smart Content Detection: recognizes `.git`, `.xcodeproj`, `package.json`, `Dockerfile`, Python projects, and photo and video folders
  - Custom mappings: user-defined keyword to symbol overrides (case-insensitive)
  - Gemini AI matching (optional): Google Gemini 2.5 Flash API for low-confidence local matches, batched and cached in UserDefaults, with learning examples derived from user corrections
  - Local `SymbolSearchEngine`: SF Symbol search over approximately 7,968 Apple-curated symbols with confidence scoring
  - Local `SymbolMapper`: approximately 350-keyword dictionary with exact, token, substring, and fuzzy matching
  - `EmojiMapper`: mirror of `SymbolMapper` for emoji-style output

- **Icon rendering**
  - Multi-resolution output (16, 32, 64, 128, 256, 512) for Finder compatibility
  - Per-folder symbol selection with up to 3 layers
  - Per-folder color (folder face and symbol tint) with 10 themed color palettes and automatic assignment
  - Per-folder adjustments: symbol scale, opacity, vertical offset, and gradient
  - Custom image and Finder icon import for individual folders
  - Quick Look preview thumbnails at multiple resolutions

- **Application**
  - One-click Apply All and Restore All with batch progress, cancellation, and undo
  - Undo and redo stack with 20-action history
  - Per-folder right-click menu and `…` button (unified)
  - Free-text search and status filter chips
  - Dry Run mode for previewing changes without writing
  - Clipboard copy and paste of icon settings between folders
  - Presets: save, load, export, and import named configurations
  - Templates: snapshot a folder's visual settings for reuse
  - Backups: named snapshots for bulk restore
  - Onboarding wizard (welcome, style, matching, AI, done)
  - 9-tab Preferences (Gemini AI, Background, Appearance, Mappings, Rules, Templates, Detection, Presets, Analytics)
  - Menu bar mode (optional `NSStatusItem`) with toggle from menu
  - Background folder monitoring (FSEvents-based) for auto-iconifying new folders
  - User notifications when background monitoring matches a new folder

- **Storage**
  - All settings stored in UserDefaults (no cloud, no telemetry)
  - Gemini API key stored in macOS Keychain under service `app.iconic.Iconic.gemini`
  - Privacy manifest (`Iconic/PrivacyInfo.xcprivacy`) declaring only UserDefaults and disk-space access reasons

- **Accessibility**
  - Tooltips on all interactive controls
  - Keyboard shortcuts, listed via the `?` button
  - Help screen with searchable shortcut list

- **Localization**
  - String catalog generation enabled (`SWIFT_EMIT_LOC_STRINGS = YES`); ready for translations

### Changed

- Nothing (initial open-source release).

### Deprecated

- Nothing.

### Removed

- Nothing.

### Fixed

- Nothing (initial open-source release).

### Security

- API key stored in macOS Keychain, never in UserDefaults or source
- No telemetry and no remote calls except the user-initiated Gemini API call
- Privacy manifest declares no tracking and no collected data types
- App Sandbox disabled (required for system-wide `NSWorkspace.setIcon`); Hardened Runtime enabled

[Unreleased]: https://github.com/HimankMahani/Iconic/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/HimankMahani/Iconic/releases/tag/v1.0.0
