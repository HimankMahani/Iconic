# Third-Party Notices

Iconic is built entirely on Apple system frameworks and contains
**no third-party code dependencies**. The two files under
`Iconic/Generated/` are, however, **derived data** extracted from
Apple's private system plists at build time. This document records
their provenance so the project remains auditable.

---

## `Iconic/Generated/SymbolMetadata.swift`

- **Source**: `/System/Library/PrivateFrameworks/SFSymbolsExtension.framework`
  and `/System/Library/PrivateFrameworks/SF Symbols.app/...` plists
  (specifically the per-symbol `*.metadataplist` files that ship
  with the system).
- **Extracted by**: `Scripts/extract_symbols.swift` (a small
  read-only Swift script that reads the system plists and emits a
  Swift file containing the SF Symbol name + curated Apple search
  tags for ~7,968 symbols).
- **What it contains**: a generated `enum SymbolMetadata` with a
  `searchTags: [String: [String]]` lookup keyed by SF Symbol name.
  The keys are the symbol names themselves (which are not
  copyrightable in the relevant jurisdiction — they are factual
  identifiers); the values are the curated Apple search tags that
  Iconic uses to match folder names to symbols.
- **License of the source data**: the SF Symbol names and their
  associated Apple-curated search tags are made available by Apple
  Inc. for use in apps that display SF Symbols. They are not
  redistributed by Iconic; Iconic reads them from the user's own
  Mac at build time and generates a per-build Swift file.
- **Your obligations**: if you fork Iconic, your generated
  `Iconic/Generated/SymbolMetadata.swift` is regenerated from your
  own Mac's system plists; nothing in this repository is shipped as
  a copy of Apple's proprietary metadata.

## `Iconic/Generated/EmojiMetadata.swift`

- **Source**: `/System/Library/PrivateFrameworks/CoreEmoji.framework`
  and the system emoji plists.
- **Extracted by**: `Scripts/extract_emoji.swift` (analogous to the
  symbols script; reads the system plists and emits a Swift file
  containing emoji glyph + Apple name + search tags for ~1,907
  emoji).
- **What it contains**: a generated `enum EmojiMetadata` with
  `searchTags: [String: [String]]`, `allEmoji: [String]`, and
  `appleName(_:) -> String` lookups.
- **License**: same as above — derived from the user's own system
  at build time, not redistributed.

---

## How regeneration works

To regenerate both metadata files from your own system plists:

```sh
cd <repo-root>
swift Scripts/extract_symbols.swift   # writes Iconic/Generated/SymbolMetadata.swift
swift Scripts/extract_emoji.swift     # writes Iconic/Generated/EmojiMetadata.swift
```

Both scripts are **read-only** with respect to the system: they
read plists from `/System/Library/...` and emit a Swift file under
`Iconic/Generated/`. They do not write anywhere else.

The generated files are committed to the repository so that
contributors and CI do not need to run the regeneration step on
every build. A pre-release check should re-run the scripts to
pick up any new symbols or emoji that Apple added in the latest
macOS release.

---

## Other dependencies

Iconic has **zero third-party Swift Package, CocoaPods, Carthage, or
vendored dependencies**. The build links only against Apple system
frameworks:

- Foundation
- SwiftUI
- AppKit
- Security (Keychain Services)
- CoreImage
- UserNotifications
- os.log
- QuickLook
- UniformTypeIdentifiers

All are part of the macOS SDK and are governed by Apple's standard
SDK license agreement.
