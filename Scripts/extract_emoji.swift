#!/usr/bin/env swift
//
//  extract_emoji.swift
//  Iconic
//
//  One-time extractor for emoji search metadata. Mirrors extract_symbols.swift.
//  Reads CoreEmoji.framework's curated emoji-to-name table, synthesizes search
//  tags from the names, and emits Iconic/Generated/EmojiMetadata.swift.
//
//  Source:
//    /System/Library/PrivateFrameworks/CoreEmoji.framework/Versions/A/Resources/
//      en.lproj/AppleName.strings  (binary plist: emoji → "musical note")
//      en.lproj/Voiceover.strings  (fallback: broader VoiceOver descriptions)
//
//  Usage (from repo root):
//    swift Scripts/extract_emoji.swift
//

import Foundation
import AppKit

let resourcesDir = "/System/Library/PrivateFrameworks/CoreEmoji.framework/Versions/A/Resources/en.lproj"
let appleNamePath = "\(resourcesDir)/AppleName.strings"
let voiceoverPath = "\(resourcesDir)/Voiceover.strings"
let outputPath = "Iconic/Generated/EmojiMetadata.swift"

// MARK: - Load source files

guard FileManager.default.fileExists(atPath: appleNamePath) else {
    FileHandle.standardError.write(Data("ERROR: \(appleNamePath) not found.\n".utf8))
    exit(1)
}

guard let appleNames = NSDictionary(contentsOfFile: appleNamePath) as? [String: String] else {
    FileHandle.standardError.write(Data("ERROR: failed to parse \(appleNamePath)\n".utf8))
    exit(1)
}

// Voiceover entries are keyed by "UnicodeHex.1f3b5" form, not raw emoji.
// We treat it as an optional secondary source for synthesizing extra tags.
let voiceoverNames = (NSDictionary(contentsOfFile: voiceoverPath) as? [String: String]) ?? [:]

print("Loaded:")
print("  \(appleNames.count) AppleName entries")
print("  \(voiceoverNames.count) Voiceover entries")

// MARK: - Tag synthesis

/// Words that are too generic on their own — drop unless they are the only tag.
let noiseTokens: Set<String> = [
    "sign", "button", "symbol", "the", "a", "of", "with", "and",
    "mark", "icon", "selector", "and", "pictograph"
]

/// Synonym expansion: e.g. "red heart" should also be findable via "love".
let synonyms: [String: [String]] = [
    "heart": ["love", "favorite", "like"],
    "musical": ["music"],
    "note": ["music"],
    "smiling": ["happy", "smile"],
    "grinning": ["happy", "smile", "laugh"],
    "crying": ["sad", "tears"],
    "running": ["run", "fitness", "exercise"],
    "person": ["people"],
    "people": ["person"],
    "money": ["finance", "cash"],
    "bag": ["shopping"],
    "shopping": ["shop", "store"],
    "house": ["home"],
    "building": ["office", "work"],
    "office": ["work", "business"],
    "briefcase": ["work", "business"],
    "computer": ["tech", "code"],
    "laptop": ["tech", "computer", "code"],
    "phone": ["mobile", "call"],
    "camera": ["photo", "picture", "pictures"],
    "film": ["movie", "video", "cinema"],
    "movie": ["film", "video"],
    "book": ["reading", "study"],
    "books": ["library", "reading", "study"],
    "graduation": ["school", "college", "university", "study"],
    "school": ["education", "study"],
    "airplane": ["flight", "travel", "trip", "vacation"],
    "car": ["drive", "vehicle"],
    "ship": ["travel"],
    "boat": ["travel"],
    "globe": ["world", "earth", "international"],
    "leaf": ["nature", "plant", "green"],
    "tree": ["nature", "forest"],
    "fire": ["hot", "flame"],
    "star": ["favorite", "important"],
    "sparkles": ["new", "magic", "shiny"],
    "gift": ["birthday", "present"],
    "cake": ["birthday", "dessert", "sweet"],
    "coffee": ["drink", "cafe"],
    "tea": ["drink"],
    "wine": ["drink", "alcohol"],
    "beer": ["drink", "alcohol"],
    "pizza": ["food"],
    "burger": ["food"],
    "hamburger": ["food", "burger"],
    "calendar": ["date", "schedule"],
    "clock": ["time"],
    "alarm": ["time", "clock"],
    "lock": ["secure", "private", "security"],
    "key": ["secure", "unlock"],
    "package": ["box", "shipping"],
    "envelope": ["mail", "email"],
    "telephone": ["phone", "call"],
    "magnifying": ["search", "find", "zoom"],
    "scissors": ["cut"],
    "pencil": ["write", "edit"],
    "pen": ["write"],
    "trash": ["delete", "garbage"],
    "wastebasket": ["trash", "delete", "garbage"],
    "folder": ["directory"],
    "memo": ["note", "notes"],
    "page": ["document", "doc"],
    "newspaper": ["news", "article", "articles"],
    "chart": ["data", "stats"],
    "graph": ["data", "stats"],
    "gear": ["settings", "config"],
    "wrench": ["tools", "fix", "repair"],
    "hammer": ["tools", "build"],
    "robot": ["ai", "automation"],
    "brain": ["mind", "ai", "smart"],
    "rocket": ["launch", "fast", "space"],
    "trophy": ["winner", "award", "achievement"],
    "medal": ["award", "achievement"],
    "fitness": ["gym", "workout", "health"],
    "muscle": ["fitness", "gym", "strength"],
    "soccer": ["sport", "ball", "football"],
    "basketball": ["sport", "ball"],
    "baseball": ["sport", "ball"],
    "football": ["sport"],
    "tennis": ["sport"],
    "guitar": ["music", "instrument"],
    "piano": ["music", "instrument"],
    "drum": ["music", "instrument"],
    "microphone": ["audio", "voice", "podcast"],
    "headphone": ["audio", "music"],
    "headphones": ["audio", "music"],
    "speaker": ["audio", "sound"],
    "controller": ["game", "gaming"],
    "joystick": ["game", "gaming"],
    "dice": ["game", "random"],
    "puzzle": ["game"],
    "paint": ["art", "design", "creative"],
    "palette": ["art", "color", "design"],
    "framed": ["art", "picture", "image"],
    "rainbow": ["color", "pride"],
    "umbrella": ["rain", "weather"],
    "sun": ["weather", "day"],
    "cloud": ["weather", "sky"],
    "snowflake": ["snow", "winter", "cold"],
    "fish": ["food", "ocean", "animal"],
    "dog": ["pet", "animal"],
    "cat": ["pet", "animal"],
    "paw": ["pet", "animal"],
    "rabbit": ["pet", "animal"],
    "bird": ["animal"],
    "lightbulb": ["idea", "inspiration"],
    "bulb": ["idea", "light"],
    "battery": ["power", "energy"],
    "plug": ["power", "energy", "electric"],
    "satellite": ["space", "tech"],
    "telescope": ["space", "science"],
    "microscope": ["science", "research"],
    "test": ["science", "lab"],
    "tube": ["science", "lab"],
    "syringe": ["medical", "health", "hospital"],
    "pill": ["medical", "health"],
    "pills": ["medical", "health"],
    "stethoscope": ["medical", "doctor"],
    "hospital": ["medical", "health"],
    "ambulance": ["medical", "emergency"],
    "police": ["emergency"],
    "fire-engine": ["emergency"],
    "warning": ["alert", "danger"],
    "exclamation": ["alert", "important", "warning"],
    "question": ["help", "unknown"],
    "checkmark": ["done", "complete", "check"],
    "cross": ["delete", "remove", "no"],
    "tag": ["label", "price"],
    "ticket": ["event"],
    "trophy-cup": ["winner"],
    "medal-sports": ["award"],
    "balloon": ["birthday", "party"],
    "party": ["celebration", "birthday"],
    "celebration": ["party"],
    "fireworks": ["celebration", "party"],
    "ring": ["wedding", "marriage"],
    "kiss": ["love", "romance"],
    "couple": ["love", "romance"],
    "anger": ["mad", "angry"],
    "sleepy": ["tired", "sleep"],
    "money-mouth": ["finance", "rich"],
    "exploding": ["mind-blown", "shocked"],
    "thinking": ["thought", "thinking"],
    "shrugging": ["dunno", "shrug"],
]

func tokenize(_ name: String) -> [String] {
    // Lowercase, split on non-alphanumerics, drop noise.
    let lower = name.lowercased()
    var tokens: [String] = []
    var current = ""
    for ch in lower {
        if ch.isLetter || ch.isNumber {
            current.append(ch)
        } else {
            if !current.isEmpty { tokens.append(current); current = "" }
        }
    }
    if !current.isEmpty { tokens.append(current) }
    return tokens
}

func synthesizeTags(forName name: String) -> Set<String> {
    var tags = Set<String>()
    let tokens = tokenize(name)
    for t in tokens where t.count >= 2 {
        if !noiseTokens.contains(t) {
            tags.insert(t)
        }
        if let syns = synonyms[t] {
            for s in syns { tags.insert(s) }
        }
    }
    // Always include the full lowercased name as a phrase tag too.
    let phrase = tokens.joined(separator: " ")
    if !phrase.isEmpty { tags.insert(phrase) }
    // Ensure we never return empty.
    if tags.isEmpty, let first = tokens.first { tags.insert(first) }
    return tags
}

// MARK: - Build emoji → tags

var merged: [(emoji: String, name: String, tags: [String])] = []
var stats = (kept: 0, dropped: 0)

for (emoji, name) in appleNames {
    // Skip entries that aren't actually emoji (just in case).
    guard !emoji.isEmpty,
          emoji.unicodeScalars.contains(where: { $0.properties.isEmoji && !$0.isASCII }) else {
        stats.dropped += 1
        continue
    }
    let tags = synthesizeTags(forName: name)
    if tags.isEmpty { stats.dropped += 1; continue }
    merged.append((emoji: emoji, name: name, tags: tags.sorted()))
    stats.kept += 1
}

merged.sort { $0.name < $1.name }

print("Built \(stats.kept) emoji entries (\(stats.dropped) dropped)")

// MARK: - Emit Swift source

var output = """
//
//  EmojiMetadata.swift
//  Iconic
//
//  GENERATED FILE — DO NOT EDIT BY HAND.
//  Regenerate with: swift Scripts/extract_emoji.swift
//
//  Source: /System/Library/PrivateFrameworks/CoreEmoji.framework/
//          .../en.lproj/AppleName.strings
//
//  Emoji: \(merged.count)
//

import Foundation

enum EmojiMetadata {
    /// Emoji → search tags. Synthesized from Apple's canonical emoji names
    /// plus a small synonym table so users can find emoji by common terms
    /// (e.g. "music" finds 🎵, "love" finds ❤️).
    static let searchTags: [String: [String]] = {
        var d: [String: [String]] = Dictionary(minimumCapacity: \(merged.count + 100))

"""

for entry in merged {
    let escaped = entry.emoji
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
    let tagList = entry.tags.map { "\"\($0)\"" }.joined(separator: ", ")
    output += "        d[\"\(escaped)\"] = [\(tagList)]\n"
}

output += """
        return d
    }()

    /// Emoji → Apple's canonical name (e.g. 🎵 → "musical note").
    /// Used for display in the emoji browser.
    static let appleName: [String: String] = {
        var d: [String: String] = Dictionary(minimumCapacity: \(merged.count + 100))

"""

for entry in merged {
    let escapedEmoji = entry.emoji
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
    let escapedName = entry.name
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
    output += "        d[\"\(escapedEmoji)\"] = \"\(escapedName)\"\n"
}

output += """
        return d
    }()

    /// Stable sorted list of all emoji, alphabetical by canonical name.
    /// Convenience for browsers and pickers.
    static let allEmoji: [String] = [
"""

let chunkSize = 20
for chunkStart in stride(from: 0, to: merged.count, by: chunkSize) {
    let chunkEnd = min(chunkStart + chunkSize, merged.count)
    let row = (chunkStart..<chunkEnd).map { i -> String in
        let escaped = merged[i].emoji
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }.joined(separator: ", ")
    output += "\n        \(row),"
}

// Strip trailing comma
if output.hasSuffix(",") { output.removeLast() }

output += """

    ]
}
"""

do {
    try output.write(toFile: outputPath, atomically: true, encoding: .utf8)
    print("Wrote \(outputPath) (\(output.count) bytes)")
} catch {
    FileHandle.standardError.write(Data("ERROR: failed to write \(outputPath): \(error)\n".utf8))
    exit(1)
}
