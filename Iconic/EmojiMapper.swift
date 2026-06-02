//
// SPDX-License-Identifier: MIT
//  EmojiMapper.swift
//  Iconic
//
//  Maps a folder name to an emoji. Mirrors SymbolMapper's API and matching
//  strategy so the rest of the app can swap between SF Symbol and emoji
//  matching by routing through the right mapper.
//

import Foundation

struct EmojiMapper {

    static let fallbackEmoji = "📁"

    /// Curated keyword → emoji mappings for the highest-confidence common cases.
    /// Tag search via EmojiMetadata picks up the long tail.
    static let builtInMappings: [(keyword: String, emoji: String)] = [
        // Music & audio
        ("music", "🎵"),
        ("song", "🎵"),
        ("songs", "🎶"),
        ("audio", "🔊"),
        ("sound", "🔊"),
        ("sounds", "🔊"),
        ("podcast", "🎙️"),
        ("podcasts", "🎙️"),
        ("voice", "🎤"),
        ("recording", "🎙️"),
        ("recordings", "🎙️"),
        ("album", "💿"),
        ("albums", "💿"),
        ("playlist", "🎶"),
        ("playlists", "🎶"),
        ("guitar", "🎸"),
        ("piano", "🎹"),
        ("drum", "🥁"),
        ("drums", "🥁"),
        ("radio", "📻"),

        // Photos & images
        ("photo", "📷"),
        ("photos", "📸"),
        ("photograph", "📷"),
        ("photographs", "📸"),
        ("picture", "🖼️"),
        ("pictures", "🖼️"),
        ("image", "🖼️"),
        ("images", "🖼️"),
        ("screenshot", "📱"),
        ("screenshots", "📱"),
        ("camera", "📷"),
        ("gallery", "🖼️"),
        ("wallpaper", "🖼️"),
        ("wallpapers", "🖼️"),
        ("selfie", "🤳"),
        ("selfies", "🤳"),

        // Video & film
        ("video", "🎬"),
        ("videos", "🎬"),
        ("movie", "🎬"),
        ("movies", "🍿"),
        ("film", "🎞️"),
        ("films", "🎞️"),
        ("clip", "🎥"),
        ("clips", "🎥"),
        ("youtube", "📺"),
        ("stream", "📡"),
        ("streams", "📡"),
        ("episode", "📺"),
        ("episodes", "📺"),
        ("series", "📺"),
        ("show", "📺"),
        ("shows", "📺"),
        ("anime", "🎌"),

        // Code & dev
        ("code", "💻"),
        ("source", "💻"),
        ("src", "💻"),
        ("dev", "🛠️"),
        ("development", "🛠️"),
        ("project", "📁"),
        ("projects", "📂"),
        ("repo", "📦"),
        ("repos", "📦"),
        ("repository", "📦"),
        ("repositories", "📦"),
        ("git", "🌿"),
        ("github", "🐙"),
        ("gitlab", "🦊"),
        ("build", "🔨"),
        ("builds", "🔨"),
        ("bin", "⚙️"),
        ("scripts", "📜"),
        ("script", "📜"),
        ("shell", "🐚"),
        ("terminal", "💻"),
        ("api", "🔌"),
        ("backend", "🗄️"),
        ("frontend", "🖥️"),
        ("ui", "🖥️"),
        ("ux", "🎨"),
        ("web", "🌐"),
        ("website", "🌐"),
        ("websites", "🌐"),
        ("html", "📄"),
        ("css", "🎨"),
        ("javascript", "📜"),
        ("typescript", "📘"),
        ("python", "🐍"),
        ("swift", "🦅"),
        ("xcode", "🔨"),
        ("ios", "📱"),
        ("android", "🤖"),
        ("mobile", "📱"),
        ("app", "📱"),
        ("apps", "📱"),
        ("library", "📚"),
        ("libraries", "📚"),
        ("framework", "🧱"),
        ("frameworks", "🧱"),
        ("plugin", "🧩"),
        ("plugins", "🧩"),
        ("module", "📦"),
        ("modules", "📦"),
        ("test", "🧪"),
        ("tests", "🧪"),
        ("testing", "🧪"),
        ("debug", "🐛"),
        ("logs", "📋"),
        ("log", "📋"),

        // Finance & business
        ("finance", "💰"),
        ("financial", "💰"),
        ("money", "💵"),
        ("bank", "🏦"),
        ("banking", "🏦"),
        ("invoice", "🧾"),
        ("invoices", "🧾"),
        ("receipt", "🧾"),
        ("receipts", "🧾"),
        ("tax", "💸"),
        ("taxes", "💸"),
        ("budget", "📊"),
        ("budgets", "📊"),
        ("expense", "💳"),
        ("expenses", "💳"),
        ("invest", "📈"),
        ("investment", "📈"),
        ("investments", "📈"),
        ("crypto", "₿"),
        ("bitcoin", "₿"),
        ("wallet", "👛"),

        // Travel
        ("travel", "✈️"),
        ("trip", "🧳"),
        ("trips", "🧳"),
        ("vacation", "🏖️"),
        ("vacations", "🏖️"),
        ("holiday", "🏖️"),
        ("holidays", "🏖️"),
        ("flight", "✈️"),
        ("flights", "✈️"),
        ("hotel", "🏨"),
        ("hotels", "🏨"),
        ("map", "🗺️"),
        ("maps", "🗺️"),
        ("passport", "🛂"),
        ("car", "🚗"),
        ("cars", "🚗"),
        ("road", "🛣️"),
        ("roadtrip", "🛣️"),

        // Work & office
        ("work", "💼"),
        ("office", "🏢"),
        ("business", "🏢"),
        ("client", "🤝"),
        ("clients", "🤝"),
        ("contract", "📝"),
        ("contracts", "📝"),
        ("meeting", "👥"),
        ("meetings", "👥"),
        ("presentation", "📊"),
        ("presentations", "📊"),
        ("report", "📊"),
        ("reports", "📊"),
        ("resume", "📋"),
        ("cv", "📋"),

        // Documents
        ("doc", "📄"),
        ("docs", "📑"),
        ("document", "📄"),
        ("documents", "📑"),
        ("pdf", "📕"),
        ("pdfs", "📕"),
        ("note", "📝"),
        ("notes", "📝"),
        ("book", "📖"),
        ("books", "📚"),
        ("ebook", "📚"),
        ("ebooks", "📚"),
        ("article", "📰"),
        ("articles", "📰"),
        ("paper", "📄"),
        ("papers", "📄"),
        ("draft", "📝"),
        ("drafts", "📝"),

        // Gaming
        ("game", "🎮"),
        ("games", "🎮"),
        ("gaming", "🎮"),
        ("steam", "🎮"),
        ("nintendo", "🎮"),
        ("playstation", "🕹️"),
        ("xbox", "🎮"),
        ("mod", "🔧"),
        ("mods", "🔧"),
        ("save", "💾"),
        ("saves", "💾"),
        ("rom", "💾"),
        ("roms", "💾"),
        ("emulator", "🕹️"),

        // Education
        ("school", "🎓"),
        ("college", "🎓"),
        ("university", "🎓"),
        ("class", "📚"),
        ("classes", "📚"),
        ("course", "📚"),
        ("courses", "📚"),
        ("homework", "📝"),
        ("assignment", "📝"),
        ("assignments", "📝"),
        ("lecture", "👨‍🏫"),
        ("lectures", "👨‍🏫"),
        ("study", "📖"),
        ("studies", "📖"),
        ("exam", "📝"),
        ("exams", "📝"),
        ("research", "🔬"),
        ("thesis", "🎓"),
        ("learning", "🧠"),
        ("tutorial", "📺"),
        ("tutorials", "📺"),

        // Health & fitness
        ("health", "❤️"),
        ("fitness", "🏃"),
        ("workout", "🏋️"),
        ("workouts", "🏋️"),
        ("gym", "🏋️"),
        ("medical", "⚕️"),
        ("medicine", "💊"),
        ("doctor", "🩺"),
        ("yoga", "🧘"),
        ("running", "🏃"),
        ("nutrition", "🥗"),
        ("diet", "🥗"),
        ("recipe", "🍽️"),
        ("recipes", "🍽️"),
        ("food", "🍴"),
        ("cooking", "🍳"),
        ("candy", "🍬"),
        ("sweet", "🍭"),
        ("sweets", "🍭"),
        ("dessert", "🍰"),
        ("desserts", "🍰"),
        ("cake", "🎂"),
        ("cakes", "🎂"),
        ("cookie", "🍪"),
        ("cookies", "🍪"),
        ("chocolate", "🍫"),
        ("cupcake", "🧁"),
        ("cupcakes", "🧁"),
        ("coffee", "☕"),
        ("tea", "🍵"),
        ("wine", "🍷"),
        ("beer", "🍺"),
        ("pizza", "🍕"),

        // Data & ML
        ("dataset", "📊"),
        ("datasets", "📊"),
        ("data", "📊"),
        ("model", "🧠"),
        ("models", "🧠"),
        ("experiment", "🧪"),
        ("experiments", "🧪"),
        ("training", "📈"),
        ("notebook", "📓"),
        ("notebooks", "📓"),
        ("jupyter", "📓"),
        ("ai", "🤖"),
        ("ml", "🧠"),

        // Build & deploy
        ("dist", "📦"),
        ("release", "🏷️"),
        ("releases", "🏷️"),
        ("staging", "🚧"),
        ("production", "✅"),
        ("infra", "🗄️"),
        ("infrastructure", "🗄️"),
        ("deploy", "🚀"),
        ("deployment", "🚀"),
        ("docker", "🐳"),
        ("kubernetes", "☸️"),
        ("k8s", "☸️"),

        // Creative
        ("design", "🎨"),
        ("designs", "🎨"),
        ("art", "🎨"),
        ("artwork", "🎨"),
        ("drawing", "✏️"),
        ("drawings", "✏️"),
        ("sketch", "✏️"),
        ("sketches", "✏️"),
        ("illustration", "🖌️"),
        ("illustrations", "🖌️"),
        ("logo", "🏷️"),
        ("logos", "🏷️"),
        ("brand", "🏷️"),
        ("branding", "🏷️"),
        ("font", "🔤"),
        ("fonts", "🔤"),
        ("typography", "🔤"),
        ("icon", "⭐"),
        ("icons", "⭐"),
        ("mockup", "📐"),
        ("mockups", "📐"),
        ("animation", "🎞️"),
        ("animations", "🎞️"),
        ("blender", "🧊"),
        ("figma", "🎨"),

        // System / common folders
        ("desktop", "🖥️"),
        ("downloads", "⬇️"),
        ("download", "⬇️"),
        ("upload", "⬆️"),
        ("uploads", "⬆️"),
        ("trash", "🗑️"),
        ("archive", "🗃️"),
        ("archives", "🗃️"),
        ("backup", "💾"),
        ("backups", "💾"),
        ("temp", "⏱️"),
        ("tmp", "⏱️"),
        ("cache", "💾"),
        ("config", "⚙️"),
        ("settings", "⚙️"),
        ("preferences", "⚙️"),
        ("system", "🖥️"),
        ("applications", "📱"),
        ("util", "🔧"),
        ("utils", "🔧"),
        ("utility", "🔧"),
        ("utilities", "🔧"),
        ("public", "🌐"),
        ("private", "🔒"),
        ("shared", "👥"),
        ("personal", "👤"),

        // People & social
        ("family", "👨‍👩‍👧‍👦"),
        ("friend", "👫"),
        ("friends", "👫"),
        ("contact", "👤"),
        ("contacts", "👥"),
        ("chat", "💬"),
        ("chats", "💬"),
        ("message", "💬"),
        ("messages", "💬"),
        ("email", "📧"),
        ("emails", "📧"),
        ("mail", "📧"),
        ("inbox", "📥"),
        ("outbox", "📤"),

        // Hobbies & misc
        ("garden", "🌱"),
        ("plants", "🌿"),
        ("pets", "🐾"),
        ("pet", "🐾"),
        ("dog", "🐶"),
        ("cat", "🐱"),
        ("home", "🏠"),
        ("house", "🏠"),
        ("kids", "👶"),
        ("baby", "👶"),
        ("wedding", "💍"),
        ("birthday", "🎂"),
        ("gift", "🎁"),
        ("gifts", "🎁"),
        ("event", "📅"),
        ("events", "📅"),
        ("calendar", "📅"),
        ("schedule", "📅"),
        ("important", "⚠️"),
        ("urgent", "🚨"),
        ("favorite", "⭐"),
        ("favorites", "⭐"),
        ("starred", "⭐"),
        ("todo", "✅"),
        ("tasks", "✅"),
        ("task", "✅"),
        ("idea", "💡"),
        ("ideas", "💡"),
        ("inspiration", "✨"),
        ("misc", "📦"),
        ("other", "❓"),
        ("random", "🎲"),
    ]

    /// Fast lookup table built once from `builtInMappings`.
    private static let lookup: [String: String] = {
        var dict: [String: String] = [:]
        for entry in builtInMappings {
            dict[entry.keyword.lowercased()] = entry.emoji
        }
        return dict
    }()

    /// Inverted index: tag → emoji, built once from EmojiMetadata.searchTags.
    /// Used for tag-based lookup when the built-in dictionary doesn't match.
    private static let tagIndex: [String: [String]] = {
        var dict: [String: [String]] = [:]
        for (emoji, tags) in EmojiMetadata.searchTags {
            for tag in tags {
                dict[tag, default: []].append(emoji)
            }
        }
        return dict
    }()

    /// User folder names are often colloquial ("hen", "kitty", "pics") while
    /// Apple's emoji names are canonical ("chicken", "cat face", "camera").
    /// Expand terms before full-catalog search so emoji mode behaves like
    /// semantic search instead of only exact dictionary lookup.
    private static let semanticAliases: [String: [String]] = [
        // Animals
        "hen": ["chicken", "bird", "farm"],
        "hens": ["chicken", "bird", "farm"],
        "rooster": ["chicken", "bird", "farm"],
        "poultry": ["chicken", "bird", "farm"],
        "chick": ["baby chick", "chicken", "bird"],
        "chicks": ["baby chick", "chicken", "bird"],
        "kitty": ["cat", "cat face"],
        "kitten": ["cat", "cat face"],
        "puppy": ["dog", "dog face"],
        "pup": ["dog", "dog face"],
        "doggo": ["dog", "dog face"],
        "horseback": ["horse", "horse face"],
        "pony": ["horse", "horse face"],
        "bunny": ["rabbit", "rabbit face"],
        "hare": ["rabbit", "rabbit face"],
        "mousey": ["mouse", "mouse face"],
        "cowboy": ["cowboy face", "cow"],
        "dino": ["dinosaur", "t-rex"],

        // Media and creative shorthand
        "pic": ["photo", "camera", "picture"],
        "pics": ["photo", "camera", "pictures"],
        "img": ["image", "picture"],
        "imgs": ["images", "pictures"],
        "vid": ["video", "movie"],
        "vids": ["videos", "movies"],
        "cinema": ["movie", "film"],
        "tunes": ["music", "musical note"],
        "beats": ["music", "drum"],
        "sketchbook": ["sketch", "drawing"],

        // Work and life shorthand
        "vacay": ["vacation", "beach", "airplane"],
        "holiday": ["vacation", "beach"],
        "holidays": ["vacation", "beach"],
        "trip": ["luggage", "airplane", "map"],
        "trips": ["luggage", "airplane", "map"],
        "cash": ["money", "banknote"],
        "pay": ["money", "credit card"],
        "bills": ["receipt", "money"],
        "todos": ["check mark", "clipboard"],
        "todo": ["check mark", "clipboard"],
        "chores": ["broom", "check mark"],
        "errands": ["shopping", "check mark"],

        // Tech shorthand
        "js": ["javascript", "scroll", "laptop"],
        "ts": ["typescript", "scroll", "laptop"],
        "node": ["package", "laptop"],
        "npm": ["package", "laptop"],
        "mac": ["desktop computer", "laptop"],
        "macos": ["desktop computer", "laptop"],
        "db": ["database", "card file box"],
        "database": ["card file box", "bar chart"],
        "server": ["desktop computer", "package"],
        "servers": ["desktop computer", "package"]
    ]

    /// Resolve a folder name to an emoji. Discards confidence.
    static func emoji(for folderName: String, customMappings: [String: String] = [:]) -> String {
        return emojiWithConfidence(for: folderName, customMappings: customMappings).emoji
    }

    /// Result of a local emoji match attempt.
    struct LocalMatch {
        let emoji: String
        let confidence: Double
        let source: Source

        enum Source {
            case customMapping
            case builtInDictionary
            case tagSearch
            case substring
            case fuzzy
            case fallback
        }
    }

    static func emojiWithConfidence(for folderName: String,
                                    customMappings: [String: String] = [:]) -> LocalMatch {
        let normalized = folderName.lowercased()
        let literalWords = tokenize(normalized)
        let words = expandSemanticAliases(for: literalWords)

        // 1. Custom: exact full-name match.
        if let e = customMappings[normalized] {
            return LocalMatch(emoji: e, confidence: 1.0, source: .customMapping)
        }
        // 2. Custom: any token match.
        for w in literalWords {
            if let e = customMappings[w] {
                return LocalMatch(emoji: e, confidence: 1.0, source: .customMapping)
            }
        }
        // 3. Built-in: exact full-name match for curated high-confidence cases.
        if let e = lookup[normalized] {
            return LocalMatch(emoji: e, confidence: 1.0, source: .builtInDictionary)
        }
        // 4. Full catalog search over Apple's emoji names and generated tags.
        if let tagResult = catalogSearch(normalized: normalized, words: words) {
            return LocalMatch(emoji: tagResult.emoji,
                              confidence: tagResult.confidence,
                              source: .tagSearch)
        }
        // 5. Built-in: any token match as a curated fallback.
        for w in words {
            if let e = lookup[w] {
                return LocalMatch(emoji: e, confidence: 0.82, source: .builtInDictionary)
            }
        }
        // 6. Substring: lookup keys contained in the folder name.
        for (key, e) in lookup where key.count >= 3 && normalized.contains(key) {
            return LocalMatch(emoji: e, confidence: 0.75, source: .substring)
        }
        // 7. Fuzzy: nearest keyword to any token.
        var bestEmoji: String?
        var bestScore: Double = 0.71
        for (index, w) in words.enumerated() where w.count >= 4 {
            let positionBoost: Double = index == 0 ? 0.06 : 0.0
            let threshold: Double = w.count >= 5 ? 0.72 : 0.78
            for (key, e) in lookup where abs(key.count - w.count) <= 3 {
                let raw = similarity(w, key)
                guard raw >= threshold else { continue }
                let lenPenalty = Double(abs(key.count - w.count)) / Double(max(key.count, w.count))
                let adjusted = raw - (lenPenalty * 0.10) + positionBoost
                if adjusted > bestScore {
                    bestScore = adjusted
                    bestEmoji = e
                }
            }
        }
        if let bestEmoji {
            return LocalMatch(emoji: bestEmoji, confidence: bestScore, source: .fuzzy)
        }
        return LocalMatch(emoji: fallbackEmoji, confidence: 0.0, source: .fallback)
    }

    // MARK: - Tag search

    private struct TagResult {
        let emoji: String
        let confidence: Double
    }

    /// Full catalog search across Apple's emoji names and generated tags.
    /// This makes emoji mode behave like search first, with the curated
    /// dictionary as a fallback rather than the limiting source of truth.
    private static func catalogSearch(normalized: String, words: [String]) -> TagResult? {
        guard !words.isEmpty else { return nil }
        var scores: [String: Int] = [:]

        for emoji in EmojiMetadata.allEmoji {
            let name = EmojiMetadata.appleName[emoji]?.lowercased() ?? ""
            let tags = EmojiMetadata.searchTags[emoji] ?? []
            let tagText = tags.joined(separator: " ").lowercased()
            var score = 0

            if name == normalized { score += 140 }
            if tags.contains(normalized) { score += 120 }
            if name.hasPrefix(normalized) { score += 80 }
            if name.contains(normalized) { score += 55 }
            if tagText.contains(normalized) { score += 40 }

            for word in words where word.count >= 3 {
                if name.split(separator: " ").contains(Substring(word)) { score += 22 }
                if tags.contains(word) { score += 22 }
                if name.contains(word) { score += 8 }
                if tagText.contains(word) { score += 8 }
            }

            if score > 0 {
                scores[emoji] = score
            }
        }

        guard let best = scores.max(by: { $0.value < $1.value }) else {
            return nil
        }
        let confidence = min(0.96, 0.72 + Double(best.value) / 250.0)
        return TagResult(emoji: best.key, confidence: confidence)
    }

    private static func expandSemanticAliases(for words: [String]) -> [String] {
        var expanded: [String] = []
        var seen = Set<String>()

        func append(_ term: String) {
            let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !trimmed.isEmpty, !seen.contains(trimmed) else { return }
            seen.insert(trimmed)
            expanded.append(trimmed)
        }

        for word in words {
            append(word)
            if let aliases = semanticAliases[word] {
                aliases.forEach(append)
            }
            if word.hasSuffix("s"), word.count > 3 {
                let singular = String(word.dropLast())
                append(singular)
                semanticAliases[singular]?.forEach(append)
            }
        }

        return expanded
    }

    // MARK: - Tokenize / similarity (mirrors SymbolMapper)

    private static func tokenize(_ s: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var lastWasLower = false
        for ch in s {
            if ch.isLetter || ch.isNumber {
                if ch.isUppercase, lastWasLower, !current.isEmpty {
                    tokens.append(current.lowercased())
                    current = String(ch)
                } else {
                    current.append(ch)
                }
                lastWasLower = ch.isLowercase
            } else {
                if !current.isEmpty { tokens.append(current.lowercased()); current = "" }
                lastWasLower = false
            }
        }
        if !current.isEmpty { tokens.append(current.lowercased()) }
        return filterNoiseTokens(tokens)
    }

    private static func filterNoiseTokens(_ tokens: [String]) -> [String] {
        let noise: Set<String> = [
            "old", "new", "backup", "bak", "tmp", "temp",
            "copy", "final", "draft", "wip"
        ]
        let versionPattern = /^v\d+$/
        let yearPattern = /^(19|20)\d{2}$/
        let pureDigitPattern = /^\d+$/
        let filtered = tokens.filter { token in
            if noise.contains(token) { return false }
            if (try? versionPattern.wholeMatch(in: token)) != nil { return false }
            if (try? yearPattern.wholeMatch(in: token)) != nil { return false }
            if (try? pureDigitPattern.wholeMatch(in: token)) != nil { return false }
            return true
        }
        return filtered.isEmpty ? tokens : filtered
    }

    private static func similarity(_ a: String, _ b: String) -> Double {
        let distance = levenshtein(Array(a), Array(b))
        let maxLen = max(a.count, b.count)
        if maxLen == 0 { return 1 }
        return 1.0 - Double(distance) / Double(maxLen)
    }

    private static func levenshtein(_ a: [Character], _ b: [Character]) -> Int {
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var prev = Array(0...b.count)
        var curr = Array(repeating: 0, count: b.count + 1)
        for i in 1...a.count {
            curr[0] = i
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                curr[j] = min(prev[j] + 1, curr[j - 1] + 1, prev[j - 1] + cost)
            }
            swap(&prev, &curr)
        }
        return prev[b.count]
    }
}

// MARK: - Emoji detection helper

extension String {
    /// True if this string looks like an emoji glyph (rather than an SF Symbol
    /// name). SF Symbol names are pure ASCII (`music.note`); emoji always have
    /// at least one non-ASCII scalar with the Emoji property.
    var isEmojiGlyph: Bool {
        return unicodeScalars.contains { $0.properties.isEmoji && !$0.isASCII }
    }
}
