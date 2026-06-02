//
//  SymbolBrowserView.swift
//  Iconic
//

import SwiftUI
import AppKit

struct SymbolBrowserView: View {

    let onSelect: (String) -> Void

    @State private var searchText = ""
    @State private var selectedCategory: SymbolCategory = .all
    @Environment(\.dismiss) private var dismiss

    enum SymbolCategory: String, CaseIterable {
        case all = "All"
        case communication = "Communication"
        case weather = "Weather"
        case objects = "Objects"
        case nature = "Nature"
        case symbols = "Symbols"
        case media = "Media"
        case music = "Music"
        case camera = "Camera"
        case home = "Home"
        case transportation = "Transportation"
        case people = "People"
        case code = "Code"
        case work = "Work"
        case travel = "Travel"
        case creative = "Creative"
        case gaming = "Gaming"
        case education = "Education"
        case health = "Health"
    }

    /// One row in the symbol grid. We pre-compute a lowercase searchable
    /// string (name + tags joined) so the search bar can filter thousands of
    /// symbols on every keystroke without rebuilding the haystack.
    private struct SymbolEntry: Identifiable {
        let name: String
        let category: SymbolCategory
        let searchKey: String
        var id: String { name }
    }

    /// Lazy flat list derived from `SymbolMetadata` (Apple's full symbol
    /// catalog, ~7968 entries). Built once per category selection so the
    /// full list never has to be filtered twice for the same query.
    private var allSymbols: [SymbolEntry] {
        let raw = SymbolMetadata.searchTags
        return raw.keys.sorted().map { name in
            let tags = raw[name] ?? []
            let category = categorize(tags: tags)
            let searchKey = (name + " " + tags.joined(separator: " ")).lowercased()
            return SymbolEntry(name: name, category: category, searchKey: searchKey)
        }
    }

    /// Map Apple's category tags (the ones in `symbol_categories.plist`) to
    /// our `SymbolCategory`. Apple ships ~20 high-level categories; we map
    /// the closest one and fall back to `.all` for un-categorized symbols.
    private func categorize(tags: [String]) -> SymbolCategory {
        let set = Set(tags)
        if set.contains("communication") || set.contains("connectivity") { return .communication }
        if set.contains("weather") { return .weather }
        if set.contains("objectsandtools") { return .objects }
        if set.contains("nature") { return .nature }
        if set.contains("symbols") || set.contains("shapes") { return .symbols }
        if set.contains("media") { return .media }
        if set.contains("music") { return .music }
        if set.contains("camera") { return .camera }
        if set.contains("home") { return .home }
        if set.contains("transportation") { return .transportation }
        if set.contains("people") { return .people }
        if set.contains("editing") { return .creative }
        if set.contains("gaming") { return .gaming }
        if set.contains("education") { return .education }
        if set.contains("health") || set.contains("fitness") { return .health }
        if set.contains("places") || set.contains("industries") || set.contains("business") { return .work }
        if set.contains("food") { return .home }
        return .all
    }

    private var filteredSymbols: [SymbolEntry] {
        var symbols = allSymbols

        // Filter by category
        if selectedCategory != .all {
            symbols = symbols.filter { $0.category == selectedCategory }
        }

        // Filter by search text — matches both the symbol name and any of
        // Apple's curated tags so "music" finds headphones, equalizer, etc.
        // even when "music" isn't in the symbol's name.
        let query = searchText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            symbols = symbols.filter { $0.searchKey.contains(query) }
        }

        return symbols
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("SF Symbols Browser")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(16)

            Divider()

            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search symbols...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // Category picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SymbolCategory.allCases, id: \.self) { category in
                        Button {
                            selectedCategory = category
                        } label: {
                            Text(category.rawValue)
                                .font(.caption)
                                .fontWeight(selectedCategory == category ? .semibold : .regular)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(selectedCategory == category ? Color.accentColor.opacity(0.15) : Color.clear)
                        .foregroundStyle(selectedCategory == category ? .primary : .secondary)
                        .cornerRadius(6)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 12)

            Divider()

            // Symbol grid
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                    ForEach(filteredSymbols, id: \.name) { symbol in
                        SymbolCell(symbolName: symbol.name) {
                            onSelect(symbol.name)
                            dismiss()
                        }
                    }
                }
                .padding(16)
            }

            Divider()

            // Footer
            HStack {
                Text("\(filteredSymbols.count) symbol\(filteredSymbols.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(12)
        }
        .frame(width: 640, height: 520)
    }
}

struct SymbolCell: View {
    let symbolName: String
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(spacing: 4) {
                if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                        .foregroundStyle(isHovered ? Color.accentColor : .primary)
                } else {
                    Image(systemName: "questionmark.square.dashed")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                        .foregroundStyle(.secondary)
                }

                if isHovered {
                    Text(symbolName)
                        .font(.system(size: 9))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .frame(height: 20)
                }
            }
            .frame(width: 70, height: 70)
            .background(isHovered ? Color.accentColor.opacity(0.1) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .help(symbolName)
    }
}

struct EmojiBrowserView: View {
    let onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    /// One emoji + pre-computed lowercase searchable text + Apple name.
    /// We build this once so live filtering over 1907 entries stays snappy
    /// and the "no query" list is alphabetically sorted by Apple name.
    private struct EmojiEntry: Identifiable {
        let emoji: String
        let name: String
        let searchKey: String
        var id: String { emoji }
    }

    /// All emojis from Apple's catalog, with name + tags pre-joined into a
    /// lowercase searchKey for fast live filtering. Sorted alphabetically
    /// by Apple name so the no-query list is predictable.
    private var allEmoji: [EmojiEntry] {
        EmojiMetadata.allEmoji.map { emoji in
            let name = EmojiMetadata.appleName[emoji] ?? emoji
            let tags = EmojiMetadata.searchTags[emoji] ?? []
            let searchKey = (name + " " + tags.joined(separator: " ")).lowercased()
            return EmojiEntry(emoji: emoji, name: name, searchKey: searchKey)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var filteredEmoji: [EmojiEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let all = allEmoji
        guard !query.isEmpty else {
            return all
        }

        // Direct paste of an actual emoji → return any emoji that contains
        // the graphemes (covers multi-char sequences like 🇺🇸).
        if query.isEmojiGlyph {
            return all.filter { $0.emoji.contains(query) }
        }

        let tokens = query
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)

        let ranked = all.compactMap { entry -> (entry: EmojiEntry, score: Int)? in
            let name = entry.name.lowercased()
            let tags = EmojiMetadata.searchTags[entry.emoji] ?? []
            let tagText = tags.joined(separator: " ").lowercased()
            var score = 0

            if name == query { score += 120 }
            if tags.contains(where: { $0.lowercased() == query }) { score += 100 }
            if name.hasPrefix(query) { score += 80 }
            if name.contains(query) { score += 55 }
            if tagText.contains(query) { score += 40 }

            for token in tokens {
                if name.split(separator: " ").contains(Substring(token)) { score += 18 }
                if tags.contains(where: { $0.lowercased() == token }) { score += 18 }
                if name.contains(token) { score += 8 }
                if tagText.contains(token) { score += 8 }
            }

            return score > 0 ? (entry, score) : nil
        }

        return ranked
            .sorted {
                if $0.score == $1.score {
                    return $0.entry.name.localizedCaseInsensitiveCompare($1.entry.name) == .orderedAscending
                }
                return $0.score > $1.score
            }
            .map(\.entry)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Emoji Browser")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(16)

            Divider()

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search emoji by name or tag...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal, 16)
            .padding(.top, 12)

            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8), spacing: 8) {
                    ForEach(filteredEmoji) { entry in
                        EmojiCell(emoji: entry.emoji, name: entry.name) {
                            onSelect(entry.emoji)
                            dismiss()
                        }
                    }
                }
                .padding(16)
            }

            Divider()

            HStack {
                Text("\(filteredEmoji.count) emoji")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(12)
        }
        .frame(width: 640, height: 520)
    }
}

private struct EmojiCell: View {
    let emoji: String
    let name: String
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(spacing: 4) {
                Text(emoji)
                    .font(.system(size: 30))
                    .frame(width: 36, height: 36)

                if isHovered {
                    Text(name)
                        .font(.system(size: 9))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .frame(height: 22)
                }
            }
            .frame(width: 70, height: 70)
            .background(isHovered ? Color.accentColor.opacity(0.1) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .help(name)
    }
}

#Preview {
    SymbolBrowserView { symbol in
        print("Selected: \(symbol)")
    }
}
