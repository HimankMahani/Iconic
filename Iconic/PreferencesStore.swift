//
//  PreferencesStore.swift
//  Iconic
//
//  Persistent stores backed by UserDefaults:
//   - BookmarkStore: security-scoped bookmark for the most recently picked
//     folder, so we can re-open it on next launch with persistent access.
//   - CustomMappingsStore: user-defined keyword → SF Symbol overrides.
//

import Foundation
import Combine

// MARK: - Bookmark store

enum BookmarkStore {
    private static let key = "iconic.lastFolder.bookmark"

    /// Saves a security-scoped bookmark for the given folder URL.
    static func save(_ url: URL) {
        do {
            let data = try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            // Without sandbox security-scoped bookmarks are best-effort; fall
            // back to a plain bookmark so we still resolve a path next launch.
            if let data = try? url.bookmarkData() {
                UserDefaults.standard.set(data, forKey: key)
            }
        }
    }

    /// Resolves the saved bookmark, refreshing it if stale. Returns the URL
    /// and a flag indicating whether security-scoped access was started
    /// (callers must `stopAccessingSecurityScopedResource` when done).
    static func resolve() -> (url: URL, didStartAccessing: Bool)? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        var stale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        ) else { return nil }

        if stale { save(url) }

        let started = url.startAccessingSecurityScopedResource()
        return (url, started)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

// MARK: - Icon Style (SF Symbol vs. Emoji)

enum IconStyle: String, CaseIterable, Codable {
    case sfSymbol
    case emoji
}

/// Whether the app matches folders to SF Symbols or to emoji. Controls which
/// mapper (SymbolMapper vs. EmojiMapper) the scan path uses and which prompt
/// GeminiService sends.
enum IconStyleStore {
    private static let key = "iconic.iconStyle.v1"

    static var current: IconStyle {
        get {
            guard let raw = UserDefaults.standard.string(forKey: key),
                  let style = IconStyle(rawValue: raw) else {
                return .sfSymbol
            }
            return style
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: key) }
    }
}

// MARK: - Smart Content Detection

enum SmartContentDetectionStore {
    private static let key = "iconic.smartContentDetection.enabled"

    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

// MARK: - Auto Color Assignment

enum AutoColorStore {
    private static let key = "iconic.autoColor.enabled"

    static var isEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: key) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: key)
        }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

// MARK: - Exclude Patterns

enum ExcludePatternsStore {
    private static let patternsKey = "iconic.excludePatterns.v1"
    private static let enabledKey = "iconic.excludePatterns.enabled"

    static let defaultPatterns: [String] = [
        ".git",
        "node_modules",
        ".venv",
        "__pycache__",
        ".cache",
        "venv",
        "env",
        ".idea",
        ".vscode",
        "build",
        "dist",
        "target"
    ]

    static var isEnabled: Bool {
        get {
            // Default to true if not set
            if UserDefaults.standard.object(forKey: enabledKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: enabledKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    static var patterns: [String] {
        get {
            if let data = UserDefaults.standard.data(forKey: patternsKey),
               let decoded = try? JSONDecoder().decode([String].self, from: data) {
                return decoded
            }
            return defaultPatterns
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: patternsKey)
            }
        }
    }

    static func add(_ pattern: String) {
        let trimmed = pattern.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        var current = patterns
        if !current.contains(trimmed) {
            current.append(trimmed)
            patterns = current
        }
    }

    static func remove(_ pattern: String) {
        var current = patterns
        current.removeAll { $0 == pattern }
        patterns = current
    }

    static func resetToDefaults() {
        patterns = defaultPatterns
    }

    /// Check if a folder name matches any exclude pattern
    /// Supports wildcards: * (any chars), ? (single char)
    /// Case-insensitive matching
    static func matches(_ folderName: String, patterns: [String]) -> Bool {
        let lowerName = folderName.lowercased()
        for pattern in patterns {
            if matchesPattern(lowerName, pattern: pattern.lowercased()) {
                return true
            }
        }
        return false
    }

    private static func matchesPattern(_ name: String, pattern: String) -> Bool {
        // Exact match
        if name == pattern {
            return true
        }

        // No wildcards, no match
        if !pattern.contains("*") && !pattern.contains("?") {
            return false
        }

        // Convert glob pattern to regex
        var regexPattern = "^"
        for char in pattern {
            switch char {
            case "*":
                regexPattern += ".*"
            case "?":
                regexPattern += "."
            case ".":
                regexPattern += "\\."
            default:
                if char.isLetter || char.isNumber || char == "_" || char == "-" {
                    regexPattern += String(char)
                } else {
                    regexPattern += "\\" + String(char)
                }
            }
        }
        regexPattern += "$"

        guard let regex = try? NSRegularExpression(pattern: regexPattern, options: []) else {
            return false
        }

        let range = NSRange(name.startIndex..<name.endIndex, in: name)
        return regex.firstMatch(in: name, options: [], range: range) != nil
    }
}

// MARK: - Scan Depth Limit

enum ScanDepthStore {
    private static let key = "iconic.scanDepthLimit"
    static let defaultLimit: Int = 10
    static let minLimit: Int = 1
    static let maxLimit: Int = 20

    static var limit: Int {
        get {
            if UserDefaults.standard.object(forKey: key) == nil {
                return defaultLimit
            }
            let raw = UserDefaults.standard.integer(forKey: key)
            return min(max(raw, minLimit), maxLimit)
        }
        set { UserDefaults.standard.set(min(max(newValue, minLimit), maxLimit), forKey: key) }
    }
}

// MARK: - Recent Folders

struct RecentFolder: Identifiable, Codable, Hashable {
    var id = UUID()
    var bookmarkData: Data
    var displayName: String
    var lastAccessed: Date
}

enum RecentFoldersStore {
    private static let key = "iconic.recentFolders.v1"
    private static let maxRecent = 10

    static func load() -> [RecentFolder] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([RecentFolder].self, from: data) else {
            return []
        }
        return decoded
    }

    static func save(_ folders: [RecentFolder]) {
        let limited = Array(folders.prefix(maxRecent))
        if let data = try? JSONEncoder().encode(limited) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    /// Add or update a folder in the recent list
    static func add(_ url: URL) {
        var folders = load()

        // Remove existing entry if present
        folders.removeAll { folder in
            var stale = false
            guard let resolved = try? URL(
                resolvingBookmarkData: folder.bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            ) else { return false }
            return resolved.path == url.path
        }

        // Create bookmark data
        guard let bookmarkData = try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else { return }

        // Add to front
        let recent = RecentFolder(
            bookmarkData: bookmarkData,
            displayName: url.lastPathComponent,
            lastAccessed: Date()
        )
        folders.insert(recent, at: 0)

        save(folders)
    }

    /// Remove a folder from recent list
    static func remove(_ id: UUID) {
        var folders = load()
        folders.removeAll { $0.id == id }
        save(folders)
    }

    /// Resolve a recent folder's URL
    static func resolve(_ folder: RecentFolder) -> (url: URL, didStartAccessing: Bool)? {
        var stale = false
        guard let url = try? URL(
            resolvingBookmarkData: folder.bookmarkData,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        ) else { return nil }

        if stale {
            // Update the bookmark
            if let newData = try? url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            ) {
                var folders = load()
                if let idx = folders.firstIndex(where: { $0.id == folder.id }) {
                    folders[idx].bookmarkData = newData
                    save(folders)
                }
            }
        }

        let started = url.startAccessingSecurityScopedResource()
        return (url, started)
    }
}

// MARK: - Favorites

struct FavoriteFolder: Identifiable, Codable, Hashable {
    var id = UUID()
    var bookmarkData: Data
    var displayName: String
    var customName: String?
    var dateAdded: Date

    var effectiveName: String {
        customName ?? displayName
    }
}

enum FavoritesStore {
    private static let key = "iconic.favorites.v1"

    static func load() -> [FavoriteFolder] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([FavoriteFolder].self, from: data) else {
            return []
        }
        return decoded.sorted { $0.effectiveName.localizedCaseInsensitiveCompare($1.effectiveName) == .orderedAscending }
    }

    static func save(_ favorites: [FavoriteFolder]) {
        if let data = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    /// Add a folder to favorites
    static func add(_ url: URL, customName: String? = nil) {
        var favorites = load()

        // Check if already favorited
        let alreadyExists = favorites.contains { favorite in
            var stale = false
            guard let resolved = try? URL(
                resolvingBookmarkData: favorite.bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            ) else { return false }
            return resolved.path == url.path
        }

        guard !alreadyExists else { return }

        // Create bookmark data
        guard let bookmarkData = try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else { return }

        let favorite = FavoriteFolder(
            bookmarkData: bookmarkData,
            displayName: url.lastPathComponent,
            customName: customName,
            dateAdded: Date()
        )
        favorites.append(favorite)

        save(favorites)
    }

    /// Remove a folder from favorites
    static func remove(_ id: UUID) {
        var favorites = load()
        favorites.removeAll { $0.id == id }
        save(favorites)
    }

    /// Rename a favorite
    static func rename(_ id: UUID, customName: String?) {
        var favorites = load()
        if let idx = favorites.firstIndex(where: { $0.id == id }) {
            favorites[idx].customName = customName?.isEmpty == true ? nil : customName
            save(favorites)
        }
    }

    /// Check if a URL is favorited
    static func isFavorited(_ url: URL) -> Bool {
        let favorites = load()
        return favorites.contains { favorite in
            var stale = false
            guard let resolved = try? URL(
                resolvingBookmarkData: favorite.bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            ) else { return false }
            return resolved.path == url.path
        }
    }

    /// Resolve a favorite folder's URL
    static func resolve(_ favorite: FavoriteFolder) -> (url: URL, didStartAccessing: Bool)? {
        var stale = false
        guard let url = try? URL(
            resolvingBookmarkData: favorite.bookmarkData,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        ) else { return nil }

        if stale {
            // Update the bookmark
            if let newData = try? url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            ) {
                var favorites = load()
                if let idx = favorites.firstIndex(where: { $0.id == favorite.id }) {
                    favorites[idx].bookmarkData = newData
                    save(favorites)
                }
            }
        }

        let started = url.startAccessingSecurityScopedResource()
        return (url, started)
    }
}

// MARK: - Custom mappings

struct CustomMapping: Identifiable, Codable, Hashable {
    var id = UUID()
    var keyword: String
    var symbol: String
}

@MainActor
final class CustomMappingsStore: ObservableObject {
    @Published private(set) var mappings: [CustomMapping] = []

    private let key = "iconic.customMappings.v1"

    init() {
        load()
    }

    /// Convenience flat dictionary used by `SymbolMapper`.
    var dictionary: [String: String] {
        Dictionary(uniqueKeysWithValues: mappings.map {
            ($0.keyword.lowercased(), $0.symbol)
        })
    }

    func add(_ mapping: CustomMapping) {
        guard !mapping.keyword.trimmingCharacters(in: .whitespaces).isEmpty,
              !mapping.symbol.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        if let idx = mappings.firstIndex(where: {
            $0.keyword.caseInsensitiveCompare(mapping.keyword) == .orderedSame
        }) {
            mappings[idx].symbol = mapping.symbol
        } else {
            mappings.append(mapping)
        }
        save()
    }

    func remove(at offsets: IndexSet) {
        for index in offsets.reversed() {
            mappings.remove(at: index)
        }
        save()
    }

    func update(id: UUID, keyword: String, symbol: String) {
        guard let idx = mappings.firstIndex(where: { $0.id == id }) else { return }
        mappings[idx].keyword = keyword
        mappings[idx].symbol = symbol
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key) else { return }
        if let decoded = try? JSONDecoder().decode([CustomMapping].self, from: data) {
            mappings = decoded
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(mappings) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
