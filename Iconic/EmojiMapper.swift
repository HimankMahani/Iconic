//
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
        let words = tokenize(normalized)

        // 1. Custom: exact full-name match.
        if let e = customMappings[normalized] {
            return LocalMatch(emoji: e, confidence: 1.0, source: .customMapping)
        }
        // 2. Custom: any token match.
        for w in words {
            if let e = customMappings[w] {
                return LocalMatch(emoji: e, confidence: 1.0, source: .customMapping)
            }
        }
        // 3. Built-in: exact full-name match.
        if let e = lookup[normalized] {
            return LocalMatch(emoji: e, confidence: 1.0, source: .builtInDictionary)
        }
        // 4. Built-in: any token match.
        for w in words {
            if let e = lookup[w] {
                return LocalMatch(emoji: e, confidence: 0.95, source: .builtInDictionary)
            }
        }
        // 5. Tag-based search over EmojiMetadata.searchTags.
        if let tagResult = tagSearch(words: words) {
            return LocalMatch(emoji: tagResult.emoji,
                              confidence: tagResult.confidence,
                              source: .tagSearch)
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

    /// Tag-based search: counts how many tokens hit the same emoji's tag set.
    /// Returns the emoji with the highest token-overlap, scored 0.78–0.88.
    private static func tagSearch(words: [String]) -> TagResult? {
        guard !words.isEmpty else { return nil }
        var scores: [String: Int] = [:]
        for w in words where w.count >= 3 {
            if let candidates = tagIndex[w] {
                // Each tag match increments score. Common tags (e.g. "person")
                // hit many emoji but we still let count decide the winner so
                // a multi-word folder ("running shoes") finds the right one.
                for emoji in candidates {
                    scores[emoji, default: 0] += 1
                }
            }
        }
        guard let best = scores.max(by: { $0.value < $1.value }), best.value > 0 else {
            return nil
        }
        // Confidence: 1 hit = 0.78, 2 hits = 0.83, 3+ hits = 0.88.
        let confidence: Double
        switch best.value {
        case 1: confidence = 0.78
        case 2: confidence = 0.83
        default: confidence = 0.88
        }
        return TagResult(emoji: best.key, confidence: confidence)
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
