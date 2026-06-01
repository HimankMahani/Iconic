#!/usr/bin/env swift
//
//  extract_symbols.swift
//  Iconic
//
//  One-time extractor for SF Symbols search metadata. Merges three Apple
//  data files so we get every symbol the runtime can render:
//
//    1. symbol_search.plist     — explicit search tags ("camera" → ["camera"])
//    2. symbol_categories.plist — semantic categories ("medal" → ["objectsandtools"])
//    3. name_availability.plist — the authoritative list of every symbol name
//
//  For symbols missing from #1, we synthesize tags from the symbol name
//  components and category labels. That's how `medal`, `trophy`, `unicorn`,
//  etc. become discoverable.
//
//  Run after bumping the macOS target or when Apple ships new SF Symbols.
//  The generated file is checked in.
//
//  Usage (from repo root):
//    swift Scripts/extract_symbols.swift
//

import Foundation
import AppKit

let resourcesDir = "/System/Library/PrivateFrameworks/SFSymbols.framework/Versions/Current/Resources/CoreGlyphs.bundle/Contents/Resources"
let searchPath       = "\(resourcesDir)/symbol_search.plist"
let categoriesPath   = "\(resourcesDir)/symbol_categories.plist"
let availabilityPath = "\(resourcesDir)/name_availability.plist"
let outputPath = "Iconic/Generated/SymbolMetadata.swift"

// Locale suffixes Apple uses for non-Latin script variants. We only want the
// base symbols — the SF Symbols app surfaces these for English search too.
let localeSuffixes: Set<String> = [
    "ar", "hi", "he", "th", "zh", "ja", "ko", "ru",
    "my", "km", "bn", "gu", "kn", "ml", "mr", "or",
    "pa", "si", "ta", "te", "ur"
]

func hasLocaleSuffix(_ name: String) -> Bool {
    let parts = name.split(separator: ".")
    guard let last = parts.last else { return false }
    return localeSuffixes.contains(String(last))
}

// MARK: - Load source files

guard FileManager.default.fileExists(atPath: searchPath),
      FileManager.default.fileExists(atPath: categoriesPath),
      FileManager.default.fileExists(atPath: availabilityPath) else {
    FileHandle.standardError.write(Data("ERROR: one or more SFSymbols plist files not found.\n".utf8))
    exit(1)
}

guard let searchRaw = NSDictionary(contentsOfFile: searchPath) as? [String: [String]] else {
    FileHandle.standardError.write(Data("ERROR: failed to parse \(searchPath)\n".utf8))
    exit(1)
}

guard let categoriesRaw = NSDictionary(contentsOfFile: categoriesPath) as? [String: [String]] else {
    FileHandle.standardError.write(Data("ERROR: failed to parse \(categoriesPath)\n".utf8))
    exit(1)
}

// name_availability.plist nests symbol names under a top-level "symbols" key.
guard let availabilityRoot = NSDictionary(contentsOfFile: availabilityPath) as? [String: Any],
      let allSymbols = availabilityRoot["symbols"] as? [String: String] else {
    FileHandle.standardError.write(Data("ERROR: failed to parse \(availabilityPath)\n".utf8))
    exit(1)
}

print("Loaded:")
print("  \(searchRaw.count) search-tag entries")
print("  \(categoriesRaw.count) category entries")
print("  \(allSymbols.count) total symbol-availability entries")

// MARK: - Categories worth keeping as tags

// Most category names are useful search terms ("nature", "transportation").
// Skip a few that are pure rendering hints with no semantic value.
let categoryBlocklist: Set<String> = [
    "multicolor", "variable", "indices", "whatsnew",
    "monochrome", "hierarchical", "palette"
]

// MARK: - Merge

var merged: [String: Set<String>] = [:]  // symbol → tag set
var stats = (withSearchTags: 0, categoriesOnly: 0, nameOnly: 0, dropped: 0)

for (symbol, _) in allSymbols {
    if hasLocaleSuffix(symbol) { stats.dropped += 1; continue }

    // Verify the symbol actually renders on this OS — drops phantom names.
    guard NSImage(systemSymbolName: symbol, accessibilityDescription: nil) != nil else {
        stats.dropped += 1
        continue
    }

    var tags = Set<String>()

    // Source 1: explicit search tags (best signal).
    if let searchTags = searchRaw[symbol] {
        for t in searchTags { tags.insert(t.lowercased()) }
    }

    // Source 2: semantic categories.
    if let categories = categoriesRaw[symbol] {
        for c in categories {
            let clean = c.lowercased()
            if !categoryBlocklist.contains(clean) {
                tags.insert(clean)
            }
        }
    }

    // Source 3: synthesize from the symbol name itself. Always do this —
    // `medal.fill` becomes searchable as `medal` even when Apple's tag
    // metadata is missing.
    for piece in symbol.split(separator: ".") {
        let token = piece.lowercased()
        // Skip pure modifiers that aren't useful search terms.
        if !["fill", "circle", "square", "rectangle"].contains(token) {
            tags.insert(token)
        }
    }

    if tags.isEmpty { stats.dropped += 1; continue }

    merged[symbol] = tags

    if searchRaw[symbol] != nil {
        stats.withSearchTags += 1
    } else if categoriesRaw[symbol] != nil {
        stats.categoriesOnly += 1
    } else {
        stats.nameOnly += 1
    }
}

print("Merged \(merged.count) symbols")
print("  \(stats.withSearchTags) with explicit search tags")
print("  \(stats.categoriesOnly) with categories only")
print("  \(stats.nameOnly) by name synthesis only")
print("  \(stats.dropped) dropped (locale variants, missing on this OS, or untaggable)")

// MARK: - Emit Swift source

var sortedEntries = merged.map { (symbol: $0.key, tags: Array($0.value).sorted()) }
sortedEntries.sort { $0.symbol < $1.symbol }

// IMPORTANT: emit per-line `d["key"] = [...]` assignments inside a closure,
// NOT a single `[String: [String]]` dictionary literal. With ~8000 entries the
// dictionary-literal form triggers Swift type-checker combinatorial inference
// and consumes tens of GB of RAM during compile (observed 36 GB on macOS).
// Per-statement assignments are type-checked independently and compile fast.

var output = """
//
//  SymbolMetadata.swift
//  Iconic
//
//  GENERATED FILE — DO NOT EDIT BY HAND.
//  Regenerate with: swift Scripts/extract_symbols.swift
//
//  Source: /System/Library/PrivateFrameworks/SFSymbols.framework/
//          .../CoreGlyphs.bundle/.../symbol_search.plist
//                                     + symbol_categories.plist
//                                     + name_availability.plist
//
//  Symbols: \(sortedEntries.count)
//

import Foundation

enum SymbolMetadata {
    /// SF Symbol name → search tags. Combines Apple's curated search tags,
    /// semantic categories, and tokens from the symbol name itself.
    static let searchTags: [String: [String]] = {
        var d: [String: [String]] = Dictionary(minimumCapacity: \(sortedEntries.count + 100))

"""

for entry in sortedEntries {
    let tagList = entry.tags.map { "\"\($0)\"" }.joined(separator: ", ")
    output += "        d[\"\(entry.symbol)\"] = [\(tagList)]\n"
}

output += """
        return d
    }()
}
"""

do {
    try output.write(toFile: outputPath, atomically: true, encoding: .utf8)
    print("Wrote \(outputPath) (\(output.count) bytes)")
} catch {
    FileHandle.standardError.write(Data("ERROR: failed to write \(outputPath): \(error)\n".utf8))
    exit(1)
}
