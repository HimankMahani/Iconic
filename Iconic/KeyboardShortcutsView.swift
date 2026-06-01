//
//  KeyboardShortcutsView.swift
//  Iconic
//
//  Displays a searchable overlay of all keyboard shortcuts

import SwiftUI

struct KeyboardShortcut: Identifiable {
    let id = UUID()
    let category: String
    let action: String
    let keys: String
    let description: String
}

struct KeyboardShortcutsView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private let shortcuts: [KeyboardShortcut] = [
        // Navigation
        KeyboardShortcut(category: "Navigation", action: "Navigate Up", keys: "↑", description: "Select previous folder in list"),
        KeyboardShortcut(category: "Navigation", action: "Navigate Down", keys: "↓", description: "Select next folder in list"),
        KeyboardShortcut(category: "Navigation", action: "Jump to Top", keys: "⌘↑", description: "Select first folder"),
        KeyboardShortcut(category: "Navigation", action: "Jump to Bottom", keys: "⌘↓", description: "Select last folder"),
        KeyboardShortcut(category: "Navigation", action: "Focus Search", keys: "⌘F", description: "Move focus to search field"),

        // Actions
        KeyboardShortcut(category: "Actions", action: "Apply", keys: "Return", description: "Apply icon to selected folder(s)"),
        KeyboardShortcut(category: "Actions", action: "Restore", keys: "Delete", description: "Restore default icon for selected folder(s)"),
        KeyboardShortcut(category: "Actions", action: "Select All", keys: "⌘A", description: "Select all visible folders"),
        KeyboardShortcut(category: "Actions", action: "Deselect All", keys: "⌘D", description: "Clear selection"),
        KeyboardShortcut(category: "Actions", action: "Clear Search", keys: "Esc", description: "Clear search field or selection"),

        // Filters
        KeyboardShortcut(category: "Filters", action: "Show All", keys: "⌘1", description: "Show all folders"),
        KeyboardShortcut(category: "Filters", action: "Show Applied", keys: "⌘2", description: "Show only applied folders"),
        KeyboardShortcut(category: "Filters", action: "Show Restored", keys: "⌘3", description: "Show only restored folders"),
        KeyboardShortcut(category: "Filters", action: "Show Failed", keys: "⌘4", description: "Show only failed folders"),
        KeyboardShortcut(category: "Filters", action: "Show Pending", keys: "⌘5", description: "Show only pending folders"),

        // Batch
        KeyboardShortcut(category: "Batch", action: "Apply All", keys: "⌘⇧A", description: "Apply icons to all folders"),
        KeyboardShortcut(category: "Batch", action: "Restore All", keys: "⌘⇧R", description: "Restore all folders to default"),

        // General
        KeyboardShortcut(category: "General", action: "Choose Folder", keys: "⌘O", description: "Open folder picker"),
        KeyboardShortcut(category: "General", action: "Settings", keys: "⌘,", description: "Open settings window"),
        KeyboardShortcut(category: "General", action: "Keyboard Shortcuts", keys: "⌘/", description: "Show this help window"),
    ]

    private var filteredShortcuts: [KeyboardShortcut] {
        if searchText.isEmpty {
            return shortcuts
        }
        return shortcuts.filter { shortcut in
            shortcut.action.localizedCaseInsensitiveContains(searchText) ||
            shortcut.keys.localizedCaseInsensitiveContains(searchText) ||
            shortcut.description.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var groupedShortcuts: [(String, [KeyboardShortcut])] {
        let categories = ["Navigation", "Actions", "Filters", "Batch", "General"]
        return categories.compactMap { category in
            let items = filteredShortcuts.filter { $0.category == category }
            return items.isEmpty ? nil : (category, items)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "keyboard")
                    .font(.title2)
                    .foregroundStyle(.tint)
                Text("Keyboard Shortcuts")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
            }
            .padding(20)

            Divider()

            // Search
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search shortcuts...", text: $searchText)
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
            .padding(16)

            // Shortcuts list
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(groupedShortcuts, id: \.0) { category, items in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(category)
                                .font(.headline)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 16)

                            VStack(spacing: 0) {
                                ForEach(items) { shortcut in
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(shortcut.action)
                                                .font(.body)
                                            Text(shortcut.description)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Text(shortcut.keys)
                                            .font(.system(.body, design: .monospaced))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background(Color(nsColor: .controlBackgroundColor))
                                            .cornerRadius(6)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)

                                    if shortcut.id != items.last?.id {
                                        Divider()
                                            .padding(.leading, 16)
                                    }
                                }
                            }
                            .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
                            .cornerRadius(8)
                            .padding(.horizontal, 16)
                        }
                    }

                    if filteredShortcuts.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("No shortcuts found")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(40)
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .frame(width: 600, height: 500)
    }
}

#Preview {
    KeyboardShortcutsView()
}
