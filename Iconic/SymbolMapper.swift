//
//  SymbolMapper.swift
//  Iconic
//
//  Maps a folder name to an SF Symbol using a keyword dictionary,
//  fuzzy/substring matching, and user-defined overrides.
//

import Foundation

struct SymbolMapper {

    static let fallbackSymbol = "folder.fill"

    /// Built-in keyword → SF Symbol mappings. ~220 entries spanning
    /// music, photos, code, finance, travel, work, gaming, education,
    /// health, creative, system folders, and common project names.
    static let builtInMappings: [(keyword: String, symbol: String)] = [
        // Music & audio
        ("music", "music.note"),
        ("song", "music.note"),
        ("songs", "music.note.list"),
        ("audio", "waveform"),
        ("sound", "speaker.wave.2.fill"),
        ("sounds", "speaker.wave.2.fill"),
        ("podcast", "mic.fill"),
        ("podcasts", "mic.fill"),
        ("voice", "mic.circle.fill"),
        ("recording", "record.circle"),
        ("recordings", "record.circle"),
        ("album", "opticaldisc"),
        ("albums", "opticaldisc"),
        ("playlist", "music.note.list"),
        ("playlists", "music.note.list"),
        ("track", "music.quarternote.3"),
        ("tracks", "music.quarternote.3"),
        ("beat", "metronome"),
        ("beats", "metronome"),
        ("guitar", "guitars"),
        ("piano", "pianokeys"),
        ("radio", "antenna.radiowaves.left.and.right"),

        // Photos & images
        ("photo", "photo"),
        ("photos", "photo.stack"),
        ("photograph", "photo"),
        ("photographs", "photo.stack"),
        ("picture", "photo"),
        ("pictures", "photo.stack"),
        ("image", "photo"),
        ("images", "photo.stack"),
        ("screenshot", "rectangle.dashed"),
        ("screenshots", "rectangle.dashed"),
        ("camera", "camera.fill"),
        ("gallery", "photo.on.rectangle.angled"),
        ("portrait", "person.crop.rectangle"),
        ("portraits", "person.crop.rectangle"),
        ("wallpaper", "photo.fill.on.rectangle.fill"),
        ("wallpapers", "photo.fill.on.rectangle.fill"),
        ("selfie", "person.fill.viewfinder"),
        ("selfies", "person.fill.viewfinder"),

        // Video & film
        ("video", "video.fill"),
        ("videos", "video.fill"),
        ("movie", "film.fill"),
        ("movies", "film.stack.fill"),
        ("film", "film.fill"),
        ("films", "film.stack.fill"),
        ("clip", "play.rectangle.fill"),
        ("clips", "play.rectangle.fill"),
        ("youtube", "play.tv"),
        ("stream", "dot.radiowaves.right"),
        ("streams", "dot.radiowaves.right"),
        ("episode", "tv"),
        ("episodes", "tv"),
        ("series", "tv"),
        ("show", "tv.fill"),
        ("shows", "tv.fill"),
        ("anime", "tv.fill"),

        // Code & dev
        ("code", "chevron.left.forwardslash.chevron.right"),
        ("source", "chevron.left.forwardslash.chevron.right"),
        ("src", "chevron.left.forwardslash.chevron.right"),
        ("dev", "hammer.fill"),
        ("development", "hammer.fill"),
        ("project", "folder.badge.gearshape"),
        ("projects", "folder.badge.gearshape"),
        ("repo", "shippingbox.fill"),
        ("repos", "shippingbox.fill"),
        ("repository", "shippingbox.fill"),
        ("repositories", "shippingbox.fill"),
        ("git", "arrow.triangle.branch"),
        ("github", "arrow.triangle.branch"),
        ("gitlab", "arrow.triangle.branch"),
        ("build", "hammer.circle"),
        ("builds", "hammer.circle"),
        ("bin", "terminal.fill"),
        ("scripts", "terminal.fill"),
        ("script", "terminal.fill"),
        ("shell", "terminal.fill"),
        ("terminal", "terminal.fill"),
        ("api", "network"),
        ("apis", "network"),
        ("backend", "server.rack"),
        ("frontend", "macwindow"),
        ("ui", "macwindow"),
        ("ux", "macwindow"),
        ("web", "globe"),
        ("website", "globe"),
        ("websites", "globe"),
        ("html", "doc.richtext"),
        ("css", "paintbrush.fill"),
        ("javascript", "curlybraces"),
        ("typescript", "curlybraces"),
        ("python", "chevron.left.forwardslash.chevron.right"),
        ("swift", "swift"),
        ("xcode", "hammer.fill"),
        ("ios", "apps.iphone"),
        ("android", "apps.iphone"),
        ("mobile", "apps.iphone"),
        ("app", "app.fill"),
        ("apps", "app.badge.fill"),
        ("library", "books.vertical.fill"),
        ("libraries", "books.vertical.fill"),
        ("framework", "cube.transparent"),
        ("frameworks", "cube.transparent"),
        ("plugin", "puzzlepiece.extension.fill"),
        ("plugins", "puzzlepiece.extension.fill"),
        ("module", "cube.fill"),
        ("modules", "cube.fill"),
        ("test", "checkmark.shield.fill"),
        ("tests", "checkmark.shield.fill"),
        ("testing", "checkmark.shield.fill"),
        ("debug", "ladybug.fill"),
        ("logs", "doc.text.magnifyingglass"),
        ("log", "doc.text.magnifyingglass"),

        // Finance & business
        ("finance", "dollarsign.circle.fill"),
        ("financial", "dollarsign.circle.fill"),
        ("money", "banknote.fill"),
        ("bank", "building.columns.fill"),
        ("banking", "building.columns.fill"),
        ("invoice", "doc.text.fill"),
        ("invoices", "doc.text.fill"),
        ("receipt", "scroll.fill"),
        ("receipts", "scroll.fill"),
        ("tax", "percent"),
        ("taxes", "percent"),
        ("budget", "chart.pie.fill"),
        ("budgets", "chart.pie.fill"),
        ("expense", "creditcard.fill"),
        ("expenses", "creditcard.fill"),
        ("invest", "chart.line.uptrend.xyaxis"),
        ("investment", "chart.line.uptrend.xyaxis"),
        ("investments", "chart.line.uptrend.xyaxis"),
        ("crypto", "bitcoinsign.circle.fill"),
        ("bitcoin", "bitcoinsign.circle.fill"),
        ("wallet", "wallet.pass.fill"),
        ("payroll", "person.text.rectangle"),
        ("accounting", "books.vertical.fill"),

        // Travel
        ("travel", "airplane"),
        ("trip", "airplane.departure"),
        ("trips", "airplane.departure"),
        ("vacation", "beach.umbrella.fill"),
        ("vacations", "beach.umbrella.fill"),
        ("holiday", "beach.umbrella.fill"),
        ("holidays", "beach.umbrella.fill"),
        ("flight", "airplane"),
        ("flights", "airplane"),
        ("hotel", "bed.double.fill"),
        ("hotels", "bed.double.fill"),
        ("map", "map.fill"),
        ("maps", "map.fill"),
        ("passport", "doc.badge.plus"),
        ("itinerary", "list.clipboard.fill"),
        ("itineraries", "list.clipboard.fill"),
        ("car", "car.fill"),
        ("cars", "car.fill"),
        ("road", "road.lanes"),
        ("roadtrip", "road.lanes"),

        // Work & office
        ("work", "briefcase.fill"),
        ("office", "building.2.fill"),
        ("business", "building.2.fill"),
        ("client", "person.crop.rectangle.fill"),
        ("clients", "person.2.crop.square.stack.fill"),
        ("contract", "doc.plaintext.fill"),
        ("contracts", "doc.plaintext.fill"),
        ("meeting", "person.3.fill"),
        ("meetings", "person.3.fill"),
        ("presentation", "rectangle.on.rectangle.angled"),
        ("presentations", "rectangle.on.rectangle.angled"),
        ("report", "chart.bar.doc.horizontal"),
        ("reports", "chart.bar.doc.horizontal"),
        ("resume", "person.text.rectangle.fill"),
        ("cv", "person.text.rectangle.fill"),
        ("hr", "person.2.badge.gearshape.fill"),
        ("admin", "gearshape.2.fill"),

        // Documents
        ("doc", "doc.fill"),
        ("docs", "doc.on.doc.fill"),
        ("document", "doc.fill"),
        ("documents", "doc.on.doc.fill"),
        ("pdf", "doc.richtext.fill"),
        ("pdfs", "doc.richtext.fill"),
        ("note", "note.text"),
        ("notes", "note.text"),
        ("book", "book.fill"),
        ("books", "books.vertical.fill"),
        ("ebook", "book.closed.fill"),
        ("ebooks", "books.vertical.fill"),
        ("article", "newspaper.fill"),
        ("articles", "newspaper.fill"),
        ("paper", "doc.text.fill"),
        ("papers", "doc.text.fill"),
        ("draft", "pencil.and.outline"),
        ("drafts", "pencil.and.outline"),
        ("manuscript", "text.book.closed.fill"),

        // Gaming
        ("game", "gamecontroller.fill"),
        ("games", "gamecontroller.fill"),
        ("gaming", "gamecontroller.fill"),
        ("steam", "flame.fill"),
        ("nintendo", "gamecontroller.fill"),
        ("playstation", "playstation.logo"),
        ("xbox", "xbox.logo"),
        ("mod", "wrench.and.screwdriver.fill"),
        ("mods", "wrench.and.screwdriver.fill"),
        ("save", "externaldrive.fill.badge.checkmark"),
        ("saves", "externaldrive.fill.badge.checkmark"),
        ("rom", "memorychip.fill"),
        ("roms", "memorychip.fill"),
        ("emulator", "gamecontroller"),
        ("emulators", "gamecontroller"),

        // Education
        ("school", "graduationcap.fill"),
        ("college", "building.columns.fill"),
        ("university", "building.columns.fill"),
        ("class", "studentdesk"),
        ("classes", "studentdesk"),
        ("course", "book.closed.fill"),
        ("courses", "book.closed.fill"),
        ("homework", "pencil.and.list.clipboard"),
        ("assignment", "pencil.and.list.clipboard"),
        ("assignments", "pencil.and.list.clipboard"),
        ("lecture", "person.wave.2.fill"),
        ("lectures", "person.wave.2.fill"),
        ("study", "book.fill"),
        ("studies", "book.fill"),
        ("exam", "checklist"),
        ("exams", "checklist"),
        ("research", "magnifyingglass"),
        ("thesis", "graduationcap.fill"),
        ("dissertation", "graduationcap.fill"),
        ("learning", "brain.head.profile"),
        ("tutorial", "play.rectangle.on.rectangle.fill"),
        ("tutorials", "play.rectangle.on.rectangle.fill"),

        // Health & fitness
        ("health", "heart.fill"),
        ("fitness", "figure.run"),
        ("workout", "dumbbell.fill"),
        ("workouts", "dumbbell.fill"),
        ("gym", "dumbbell.fill"),
        ("medical", "cross.case.fill"),
        ("medicine", "pills.fill"),
        ("doctor", "stethoscope"),
        ("yoga", "figure.mind.and.body"),
        ("running", "figure.run"),
        ("nutrition", "leaf.fill"),
        ("diet", "fork.knife"),
        ("recipe", "fork.knife.circle.fill"),
        ("recipes", "fork.knife.circle.fill"),
        ("food", "fork.knife"),
        ("cooking", "frying.pan.fill"),

        // Creative
        ("design", "paintpalette.fill"),
        ("designs", "paintpalette.fill"),
        ("art", "paintbrush.pointed.fill"),
        ("arts", "paintbrush.pointed.fill"),
        ("artwork", "paintbrush.pointed.fill"),
        ("drawing", "pencil.tip"),
        ("drawings", "pencil.tip"),
        ("sketch", "scribble.variable"),
        ("sketches", "scribble.variable"),
        ("illustration", "paintbrush.fill"),
        ("illustrations", "paintbrush.fill"),
        ("logo", "seal.fill"),
        ("logos", "seal.fill"),
        ("brand", "rosette"),
        ("branding", "rosette"),
        ("font", "textformat"),
        ("fonts", "textformat"),
        ("typography", "textformat"),
        ("icon", "star.circle.fill"),
        ("icons", "star.circle.fill"),
        ("vector", "scribble"),
        ("vectors", "scribble"),
        ("mockup", "rectangle.3.group.fill"),
        ("mockups", "rectangle.3.group.fill"),
        ("animation", "play.circle.fill"),
        ("animations", "play.circle.fill"),
        ("3d", "cube.fill"),
        ("model", "cube.transparent.fill"),
        ("models", "cube.transparent.fill"),
        ("blender", "cube.transparent.fill"),
        ("figma", "paintpalette.fill"),

        // System / common folders
        ("desktop", "macbook"),
        ("downloads", "arrow.down.circle.fill"),
        ("download", "arrow.down.circle.fill"),
        ("upload", "arrow.up.circle.fill"),
        ("uploads", "arrow.up.circle.fill"),
        ("trash", "trash.fill"),
        ("archive", "archivebox.fill"),
        ("archives", "archivebox.fill"),
        ("backup", "externaldrive.fill.badge.timemachine"),
        ("backups", "externaldrive.fill.badge.timemachine"),
        ("temp", "clock.arrow.circlepath"),
        ("tmp", "clock.arrow.circlepath"),
        ("cache", "internaldrive.fill"),
        ("config", "gearshape.fill"),
        ("settings", "gearshape.fill"),
        ("preferences", "slider.horizontal.3"),
        ("system", "desktopcomputer"),
        ("applications", "app.badge.fill"),
        ("util", "wrench.adjustable.fill"),
        ("utils", "wrench.adjustable.fill"),
        ("utility", "wrench.adjustable.fill"),
        ("utilities", "wrench.adjustable.fill"),
        ("public", "person.2.fill"),
        ("private", "lock.fill"),
        ("shared", "person.2.fill"),
        ("personal", "person.fill"),

        // People & social
        ("family", "person.3.fill"),
        ("friend", "person.2.fill"),
        ("friends", "person.2.fill"),
        ("contact", "person.crop.circle.fill"),
        ("contacts", "person.crop.circle.fill"),
        ("chat", "bubble.left.and.bubble.right.fill"),
        ("chats", "bubble.left.and.bubble.right.fill"),
        ("message", "message.fill"),
        ("messages", "message.fill"),
        ("email", "envelope.fill"),
        ("emails", "envelope.fill"),
        ("mail", "envelope.fill"),
        ("inbox", "tray.fill"),
        ("outbox", "tray.and.arrow.up.fill"),
        ("social", "person.2.wave.2.fill"),

        // Hobbies & misc
        ("recipe", "fork.knife.circle.fill"),
        ("garden", "leaf.fill"),
        ("plants", "leaf.fill"),
        ("pets", "pawprint.fill"),
        ("pet", "pawprint.fill"),
        ("dog", "pawprint.fill"),
        ("cat", "pawprint.fill"),
        ("car", "car.fill"),
        ("home", "house.fill"),
        ("house", "house.fill"),
        ("kids", "figure.and.child.holdinghands"),
        ("baby", "figure.2.and.child.holdinghands"),
        ("wedding", "heart.fill"),
        ("birthday", "gift.fill"),
        ("gift", "gift.fill"),
        ("gifts", "gift.fill"),
        ("event", "calendar"),
        ("events", "calendar"),
        ("calendar", "calendar"),
        ("schedule", "calendar.badge.clock"),
        ("important", "exclamationmark.triangle.fill"),
        ("urgent", "exclamationmark.octagon.fill"),
        ("favorite", "star.fill"),
        ("favorites", "star.fill"),
        ("starred", "star.fill"),
        ("todo", "checklist"),
        ("tasks", "checklist"),
        ("task", "checklist"),
        ("idea", "lightbulb.fill"),
        ("ideas", "lightbulb.fill"),
        ("inspiration", "sparkles"),
        ("misc", "tray.full.fill"),
        ("other", "questionmark.folder.fill"),
        ("random", "shuffle")
    ]

    /// Builds a fast lookup table once.
    private static let lookup: [String: String] = {
        var dict: [String: String] = [:]
        for entry in builtInMappings {
            dict[entry.keyword.lowercased()] = entry.symbol
        }
        return dict
    }()

    /// Resolve a folder name to an SF Symbol.
    /// Custom mappings take priority, then exact word match, substring,
    /// and finally fuzzy similarity. Returns `fallbackSymbol` if nothing matches.
    static func symbol(for folderName: String, customMappings: [String: String] = [:]) -> String {
        let normalized = folderName.lowercased()
        let words = tokenize(normalized)

        // 1. Custom: exact full-name match.
        if let s = customMappings[normalized] { return s }
        // 2. Custom: any token match.
        for w in words {
            if let s = customMappings[w] { return s }
        }
        // 3. Built-in: exact full-name match.
        if let s = lookup[normalized] { return s }
        // 4. Built-in: any token match.
        for w in words {
            if let s = lookup[w] { return s }
        }
        // 5. Substring match (handles "photographs" → "photo", "myMusic" → "music").
        for (key, symbol) in lookup where key.count >= 3 && normalized.contains(key) {
            return symbol
        }
        // 6. Fuzzy: find the closest keyword for any token (Jaro-Winkler-ish via Levenshtein ratio).
        var bestSymbol: String?
        var bestScore: Double = 0.78  // threshold; below this we give up
        for w in words where w.count >= 4 {
            for (key, symbol) in lookup where abs(key.count - w.count) <= 3 {
                let score = similarity(w, key)
                if score > bestScore {
                    bestScore = score
                    bestSymbol = symbol
                }
            }
        }
        return bestSymbol ?? fallbackSymbol
    }

    // MARK: - Helpers

    private static func tokenize(_ s: String) -> [String] {
        // Split on non-letter/digit boundaries and camelCase.
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
        return tokens
    }

    /// Normalized Levenshtein similarity in [0,1].
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
                curr[j] = min(
                    prev[j] + 1,
                    curr[j - 1] + 1,
                    prev[j - 1] + cost
                )
            }
            swap(&prev, &curr)
        }
        return prev[b.count]
    }
}
