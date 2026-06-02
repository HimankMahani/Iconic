# Contributing to Iconic

Thanks for your interest in making Iconic better. Iconic is a small,
all-Swift macOS app with a deliberately tight surface area: SwiftUI views,
a single coordinator, and a handful of pure helpers. Most contributions
are small, scoped, and easy to review. We'd love your help.

This document covers everything you need to send a clean pull request.
For deeper architectural context, see [`docs/architecture.md`](docs/architecture.md).
For project history and high-level documentation, see [`README.md`](README.md).

---

## Code of Conduct

We follow the standards in [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md).
By participating, you agree to uphold them.

## Reporting security issues

Please do **not** open a public issue for security bugs. Follow the
private disclosure process in [`SECURITY.md`](SECURITY.md).

---

## Before you start

- **Search existing issues and pull requests.** Someone may already be
  working on what you have in mind, or there may be context that changes
  the approach.
- **For big changes, open an issue first.** New features, refactors that
  touch `IconicViewModel.swift`, or anything that changes the icon-render
  pipeline should be discussed before code is written. Small fixes and
  documentation tweaks are fine to send straight as a PR.

---

## Development setup

- macOS 14 (Sonoma) or later
- Xcode 16 or later
- No additional tooling. Iconic has zero third-party Swift dependencies.

To run the app:

```sh
open Iconic.xcodeproj
```

Then press `Cmd-R` in Xcode. The first launch will offer optional
Gemini API key setup; you can skip it to use the built-in keyword
dictionary.

---

## Build and test

Build (Release):

```sh
xcodebuild -project Iconic.xcodeproj -scheme Iconic -configuration Release -destination 'platform=macOS' build
```

Test:

```sh
xcodebuild -project Iconic.xcodeproj -scheme Iconic -destination 'platform=macOS' test
```

The **first cold build takes roughly 30 minutes**. This is normal and
unavoidable: `Iconic/Generated/SymbolMetadata.swift` is about 711 KB
of case data covering every SF Symbol Apple ships, and
`Iconic/Generated/EmojiMetadata.swift` adds another ~215 KB on top.
The Swift type-checker chews on this for a while. Subsequent
incremental builds are fast (seconds).

If you ever need to regenerate the metadata, see the scripts in
`Scripts/` and the notes in [`docs/architecture.md`](docs/architecture.md).

---

## Project layout

Iconic is a single Xcode project. All production code lives under
`Iconic/`, with a flat structure organized by responsibility rather
than by feature. Tests live under `IconicTests/`. Long-form project
documentation lives in `docs/`.

```
Iconic/
  IconicApp.swift            # App entry, environment setup, onboarding
  ContentView.swift          # Main window
  PreferencesView.swift      # Settings (9 tabs)
  IconicViewModel.swift      # Coordinator: scan, match, render, apply
  SymbolMapper.swift         # 350+ keyword dictionary + fuzzy matching
  GeminiService.swift        # REST client for the Gemini API
  KeychainHelper.swift       # Secure API key storage
  IconRenderer.swift         # NSImage compositor
  IconApplier.swift          # NSWorkspace.setIcon wrapper
  ...
  Generated/
    SymbolMetadata.swift     # auto-generated; do not edit
    EmojiMetadata.swift      # auto-generated; do not edit

IconicTests/                 # XCTest target

docs/
  architecture.md            # full architectural tour
  dev/AGENTS.md              # AI-coding-agent project tour

Scripts/                     # metadata regeneration scripts
```

For the full table of which file owns which concern, see
[`docs/architecture.md`](docs/architecture.md). For an explanation of
the layered data flow (user picks a folder → scanner → matcher →
renderer → applier), it is worth the read before making non-trivial
changes.

---

## Where to add things

Compact version; the long version with file/line references is in
[`docs/architecture.md`](docs/architecture.md).

| You want to... | Edit |
| --- | --- |
| Add a new keyword to symbol mapping | `Iconic/SymbolMapper.swift` |
| Add a new themed color palette | `Iconic/ColorPalette.swift` |
| Add a new folder content detector (e.g. Rust) | `Iconic/FolderTypeDetector.swift` |
| Add a new settings tab | `Iconic/PreferencesView.swift` |
| Add a new persistent preference | `Iconic/PreferencesStore.swift` |
| Add a new Gemini prompt variant | `Iconic/GeminiService.swift` |
| Change matching priority or coordinator state | `Iconic/IconicViewModel.swift` |

Files dropped into the `Iconic/` directory are picked up automatically
by Xcode's `PBXFileSystemSynchronizedRootGroup`; you usually do not
need to edit `project.pbxproj` to add a source file.

---

## Code style

- **Indentation:** 4 spaces, LF line endings, no tabs.
- **No `try!`, no `fatalError`, no `print(` in shipped code.** Surface
  failures through the typed error system and the UI; use `os.Logger`
  for diagnostics.
- **Actor isolation:** all UI-touched types are `@MainActor`. The
  project has `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` set, so the
  default isolation is the main actor unless explicitly opted out.
  Heavy work (scanning, rendering, network calls) hops to
  `Task.detached`.
- **Errors** are typed `LocalizedError` enums. Reference implementations
  to mimic: `KeychainError`, `IconApplyError`, `GeminiError`. The UI
  reads `errorDescription` for display, so make sure yours is
  human-friendly.
- **Logging** uses `os.Logger` with `privacy: .public` annotations on
  every interpolated value. **Never log the Gemini API key.** Treat
  any string the user supplies as `.private`.
- **Documentation:** every public type and method gets a `///` doc
  comment explaining its purpose, its parameters, and any non-obvious
  behavior. The rendered DocC is part of the project's documentation.
- **File header:** new Swift files get the SPDX line as the second
  line of the file, immediately under the file-level import block:

  ```swift
  // Copyright (c) 2026 Iconic contributors
  // SPDX-License-Identifier: MIT

  import Foundation
  ```

---

## Tests

Run the full suite with:

```sh
xcodebuild -project Iconic.xcodeproj -scheme Iconic -destination 'platform=macOS' test
```

Guidelines:

- **Add a test for any new code path.** The existing target covers
  `SymbolMapper`, `ColorPalette`, `IconRenderer`, `IconApplier`,
  `KeychainHelper`, `FolderScanner`, and `QuickLookPreviewRenderer`.
  Match the style of the file you are extending.
- **Keychain tests must use a UUID-suffixed service name.** The real
  service name is `app.iconic.Iconic.gemini`; tests that touch that
  service can clobber the developer's real API key. Generate a
  per-test service like `app.iconic.Iconic.test.<UUID>` and clean up
  in `tearDown`.
- **URL-based dependencies** (e.g. `GeminiService`) are stubbed with
  a custom `URLProtocol` subclass registered on a private
  `URLSessionConfiguration.ephemeral`. See the existing
  `GeminiService` test patterns for a reference; prefer extending
  those over introducing a new mocking framework.
- **Avoid hitting the network in tests.** The CI machine has no
  Gemini key and no outbound network guarantees.

---

## Commit messages

We use [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` new user-facing capability
- `fix:` bug fix
- `refactor:` code change that neither fixes a bug nor adds a feature
- `test:` add or fix tests
- `docs:` documentation only
- `chore:` build, tooling, or maintenance
- `ci:` CI configuration

Reference the issue you are closing when relevant:

```
fix: handle nil customImage (closes #42)
```

Keep the subject line under 72 characters. The body, when present,
should explain *why* the change is needed, not just *what* it does.

---

## Pull request process

1. **Open a draft PR early.** A draft is a great place to get early
   feedback on approach, naming, and tests, before the implementation
   is final.
2. **Fill in the PR template.** GitHub will auto-populate a checklist
   when you open the PR against `main`; please walk through it.
   Linking the issue, summarizing the change, and noting any
   screenshots or recordings for UI changes are the bits reviewers
   need most.
3. **CI must be green.** Build, test, and (if added) lint must pass.
4. **At least one review is required before merge.** A second review
   is appreciated for changes to `IconicViewModel.swift`, the icon
   rendering pipeline, or anything that touches the Keychain.
5. **Squash-merge** is the default. Keep the final commit message
   clean and conventional-commit-shaped.

---

## Recognizing contributions

Every merged pull request is credited in the Contributors section of
the [README](README.md). If you contribute and would like to be
listed under a different name or handle, just say so in the PR
description and we will update it.
