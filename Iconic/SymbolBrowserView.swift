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
        case code = "Code"
        case work = "Work"
        case travel = "Travel"
        case creative = "Creative"
        case gaming = "Gaming"
        case education = "Education"
        case health = "Health"
    }

    private var allSymbols: [(name: String, category: SymbolCategory)] {
        // Extract unique symbols from SymbolMapper.builtInMappings and categorize them
        var symbols: [(name: String, category: SymbolCategory)] = []
        var seen = Set<String>()

        for (keyword, symbol) in SymbolMapper.builtInMappings {
            guard !seen.contains(symbol) else { continue }
            seen.insert(symbol)

            let category = categorize(keyword: keyword)
            symbols.append((name: symbol, category: category))
        }

        return symbols.sorted { $0.name < $1.name }
    }

    private func categorize(keyword: String) -> SymbolCategory {
        let communicationKeywords = ["email", "mail", "message", "chat", "contact", "inbox", "outbox", "social"]
        let weatherKeywords = ["weather", "cloud", "rain", "snow", "sun"]
        let objectsKeywords = ["car", "house", "home", "gift", "calendar", "clock", "trash", "archive"]
        let natureKeywords = ["leaf", "garden", "plants", "pet", "dog", "cat", "beach"]
        let symbolsKeywords = ["star", "heart", "important", "urgent", "favorite", "idea", "inspiration"]
        let mediaKeywords = ["music", "photo", "video", "movie", "film", "audio", "sound", "camera", "album"]
        let codeKeywords = ["code", "dev", "git", "api", "web", "html", "css", "javascript", "python", "swift", "test"]
        let workKeywords = ["work", "office", "business", "client", "meeting", "report", "finance", "invoice", "budget"]
        let travelKeywords = ["travel", "trip", "vacation", "flight", "hotel", "map", "passport", "car", "road"]
        let creativeKeywords = ["design", "art", "drawing", "sketch", "logo", "brand", "font", "icon", "animation", "3d"]
        let gamingKeywords = ["game", "gaming", "steam", "nintendo", "playstation", "xbox", "mod", "emulator"]
        let educationKeywords = ["school", "college", "university", "class", "course", "homework", "lecture", "study", "exam"]
        let healthKeywords = ["health", "fitness", "workout", "gym", "medical", "doctor", "yoga", "recipe", "food"]

        if communicationKeywords.contains(keyword) { return .communication }
        if weatherKeywords.contains(keyword) { return .weather }
        if objectsKeywords.contains(keyword) { return .objects }
        if natureKeywords.contains(keyword) { return .nature }
        if symbolsKeywords.contains(keyword) { return .symbols }
        if mediaKeywords.contains(keyword) { return .media }
        if codeKeywords.contains(keyword) { return .code }
        if workKeywords.contains(keyword) { return .work }
        if travelKeywords.contains(keyword) { return .travel }
        if creativeKeywords.contains(keyword) { return .creative }
        if gamingKeywords.contains(keyword) { return .gaming }
        if educationKeywords.contains(keyword) { return .education }
        if healthKeywords.contains(keyword) { return .health }

        return .all
    }

    private var filteredSymbols: [(name: String, category: SymbolCategory)] {
        var symbols = allSymbols

        // Filter by category
        if selectedCategory != .all {
            symbols = symbols.filter { $0.category == selectedCategory }
        }

        // Filter by search text
        if !searchText.isEmpty {
            let search = searchText.lowercased()
            symbols = symbols.filter { $0.name.lowercased().contains(search) }
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

#Preview {
    SymbolBrowserView { symbol in
        print("Selected: \(symbol)")
    }
}
