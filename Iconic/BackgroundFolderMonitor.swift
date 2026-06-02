//
// SPDX-License-Identifier: MIT
//  BackgroundFolderMonitor.swift
//  Iconic
//
//  Monitors user's home directory for new folders and auto-applies icons.
//  Uses ALL matching strategies: Rules → AI → Smart Detection → Dictionary
//

import Foundation
import AppKit
import UserNotifications
import os.log

extension Notification.Name {
    static let iconicMonitoredLocationsChanged = Notification.Name("iconic.monitoredLocationsChanged")
}

@MainActor
final class BackgroundFolderMonitor {

    private let log = Logger(subsystem: "app.iconic.Iconic", category: "BackgroundFolderMonitor")
    private var watchers: [FolderWatcher] = []
    private var locationObserver: NSObjectProtocol?
    private let rulesStore: RulesStore
    private let analyticsStore: AnalyticsStore
    private let suggestionsStore: SmartSuggestionsStore
    private let customMappingsStore: CustomMappingsStore

    init() {
        self.rulesStore = RulesStore()
        self.analyticsStore = AnalyticsStore()
        self.suggestionsStore = SmartSuggestionsStore()
        self.customMappingsStore = CustomMappingsStore()
    }

    deinit {
        if let observer = locationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func start() {
        stop()

        let locations = BackgroundMonitoringStore.monitoredLocations

        for location in locations {
            let watcher = FolderWatcher()
            watcher.start(watching: location) { [weak self] newFolderURL in
                Task { @MainActor [weak self] in
                    await self?.handleNewFolder(newFolderURL)
                }
            }
            watchers.append(watcher)
        }

        // Watch for location list changes so users can add/remove without restart
        if locationObserver == nil {
            locationObserver = NotificationCenter.default.addObserver(
                forName: .iconicMonitoredLocationsChanged,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.restartWatchers()
                }
            }
        }
    }

    func stop() {
        for watcher in watchers {
            watcher.stop()
        }
        watchers.removeAll()
    }

    /// Stop existing watchers and rebuild them from the current location list.
    private func restartWatchers() {
        for watcher in watchers {
            watcher.stop()
        }
        watchers.removeAll()

        let locations = BackgroundMonitoringStore.monitoredLocations
        for location in locations {
            let watcher = FolderWatcher()
            watcher.start(watching: location) { [weak self] newFolderURL in
                Task { @MainActor [weak self] in
                    await self?.handleNewFolder(newFolderURL)
                }
            }
            watchers.append(watcher)
        }
    }

    private func handleNewFolder(_ url: URL) async {
        let name = url.lastPathComponent

        // Skip hidden folders and excluded patterns
        guard !name.hasPrefix(".") else { return }

        // Skip Finder's default "untitled folder" (and its " 2", " 3", … variants).
        // These are placeholders the user is about to rename — applying an icon now
        // would lock in a generic match and flash the wrong icon for a moment.
        if isUntitledFolderPlaceholder(name) { return }

        if ExcludePatternsStore.isEnabled,
           ExcludePatternsStore.matches(name, patterns: ExcludePatternsStore.patterns) {
            return
        }

        // Match using the same priority order as the in-app scan flow.
        let matchResult = await matchFolder(name: name, url: url)

        // Resolve final colors mirroring IconicViewModel.scanAndApplyNewFolder.
        // Rule colors take precedence. Otherwise, if auto-color is on, assign a
        // palette folder color and derive a darker symbol shade — same as in-app.
        var symbolColor = matchResult.symbolColor
        var folderColor = matchResult.folderColor

        if AutoColorStore.isEnabled && folderColor == nil && symbolColor == nil {
            let assignments = ColorPalette.assignColors(for: [name])
            if let assigned = assignments[name] {
                folderColor = assigned
                symbolColor = IconicViewModel.symbolShade(of: assigned)
            }
        }

        let finalSymbolColor = symbolColor ?? ColorPreferences.getDefaultColor()

        do {
            let icon = IconRenderer.makeIcon(
                symbolName: matchResult.symbol,
                tint: finalSymbolColor,
                folderTint: folderColor
            )
            try IconApplier.apply(icon, to: url)

            analyticsStore.recordApply(symbolName: matchResult.symbol)
            suggestionsStore.recordChoice(folderName: name, symbolName: matchResult.symbol)

            await showNotification(folderName: name, symbol: matchResult.symbol, source: matchResult.source)

        } catch {
            log.error("Failed to apply icon to \(name, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Match result with source tracking
    private struct MatchResult {
        let symbol: String
        let symbolColor: NSColor?
        let folderColor: NSColor?
        let source: MatchSource
    }

    private enum MatchSource: String {
        case rule = "Rule"
        case smartDetection = "Smart Detection"
        case customMapping = "Custom Mapping"
        case tagSearch = "Tag Search"
        case ai = "AI"
        case dictionary = "Dictionary"
    }

    /// Matches a folder using the same priority as `IconicViewModel.scanAndApplyNewFolder`.
    /// Local matching (built-in dict + SF Symbols tag search) runs first because
    /// it's instant, offline, and now covers ~3000 symbols. AI only fires when
    /// the local match is low-confidence — saving API calls and latency.
    /// 1. Rule (auto-apply only) — carries explicit colors
    /// 2. Smart content detection
    /// 3. Custom mappings (exact name)
    /// 4. Local dictionary + SF Symbols tag search
    /// 5. AI (Gemini) — only when local confidence < 0.6 and AI is enabled
    private func matchFolder(name: String, url: URL) async -> MatchResult {
        let customMappings = customMappingsStore.dictionary

        // 1. Auto-apply rule
        if let rule = rulesStore.firstMatch(for: name), rule.autoApply {
            return MatchResult(
                symbol: glyphForCurrentStyle(folderName: name, proposedGlyph: rule.symbol, customMappings: customMappings),
                symbolColor: rule.symbolColor,
                folderColor: rule.folderColor,
                source: .rule
            )
        }

        // 2. Smart content detection
        if SmartContentDetectionStore.isEnabled,
           let detectedSymbol = FolderTypeDetector.detectType(at: url) {
            return MatchResult(
                symbol: smartDetectionGlyph(for: detectedSymbol, folderName: name, customMappings: customMappings),
                symbolColor: nil,
                folderColor: nil,
                source: .smartDetection
            )
        }

        // 3. Custom mapping (exact name match)
        if let customSymbol = customMappings[name.lowercased()] {
            return MatchResult(
                symbol: glyphForCurrentStyle(folderName: name, proposedGlyph: customSymbol, customMappings: customMappings),
                symbolColor: nil,
                folderColor: nil,
                source: .customMapping
            )
        }

        // 4. Local match — dictionary + tag search, with confidence score.
        let iconStyle = IconStyleStore.current
        let localGlyph: String
        let localConfidence: Double
        let localMatchSource: MatchSource
        let weakFallbackGlyph: String

        switch iconStyle {
        case .sfSymbol:
            let m = SymbolMapper.symbolWithConfidence(for: name, customMappings: customMappings)
            localGlyph = m.symbol
            localConfidence = m.confidence
            localMatchSource = matchSource(for: m.source)
            weakFallbackGlyph = SymbolMapper.fallbackSymbol
        case .emoji:
            let m = EmojiMapper.emojiWithConfidence(for: name, customMappings: customMappings)
            localGlyph = m.emoji
            localConfidence = m.confidence
            localMatchSource = matchSource(forEmoji: m.source)
            weakFallbackGlyph = EmojiMapper.fallbackEmoji
        }

        // High confidence local match — use it. Saves an AI call.
        if localConfidence >= 0.6 {
            return MatchResult(
                symbol: localGlyph,
                symbolColor: nil,
                folderColor: nil,
                source: localMatchSource
            )
        }

        // 5. Local match was weak — ask AI if available.
        if let apiKey = SettingsViewModel.getAPIKeyIfEnabled() {
            do {
                let results = try await GeminiService.matchFolders([name], apiKey: apiKey, style: iconStyle)
                if let match = results[name], match.symbol != weakFallbackGlyph {
                    return MatchResult(
                        symbol: match.symbol,
                        symbolColor: nil,
                        folderColor: nil,
                        source: .ai
                    )
                }
            } catch {
                log.error("AI matching failed for \(name, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }

        // No AI, or AI didn't find anything — use whatever the local match gave us
        // (even if low confidence; better than nothing).
        return MatchResult(
            symbol: localGlyph,
            symbolColor: nil,
            folderColor: nil,
            source: localMatchSource
        )
    }

    private func glyphForCurrentStyle(folderName: String, proposedGlyph: String, customMappings: [String: String]) -> String {
        switch IconStyleStore.current {
        case .sfSymbol:
            if NSImage(systemSymbolName: proposedGlyph, accessibilityDescription: nil) != nil {
                return proposedGlyph
            }
            return SymbolMapper.symbol(for: folderName, customMappings: customMappings)
        case .emoji:
            if proposedGlyph.isEmojiGlyph {
                return proposedGlyph
            }
            return EmojiMapper.emoji(for: folderName, customMappings: customMappings)
        }
    }

    private func smartDetectionGlyph(for detectedSymbol: String, folderName: String, customMappings: [String: String]) -> String {
        guard IconStyleStore.current == .emoji else { return detectedSymbol }
        switch detectedSymbol {
        case "arrow.triangle.branch": return "🌿"
        case "hammer.fill": return "🛠️"
        case "cube.fill": return "📦"
        case "chevron.left.forwardslash.chevron.right": return "🐍"
        case "shippingbox.fill": return "🚢"
        case "photo.stack": return "🖼️"
        case "film.stack.fill": return "🎬"
        default:
            return EmojiMapper.emoji(for: folderName, customMappings: customMappings)
        }
    }

    private func matchSource(for localSource: SymbolMapper.LocalMatch.Source) -> MatchSource {
        switch localSource {
        case .customMapping: return .customMapping
        case .builtInDictionary, .substring, .fuzzy, .fallback: return .dictionary
        case .tagSearch: return .tagSearch
        }
    }

    private func matchSource(forEmoji localSource: EmojiMapper.LocalMatch.Source) -> MatchSource {
        switch localSource {
        case .customMapping: return .customMapping
        case .builtInDictionary, .substring, .fuzzy, .fallback: return .dictionary
        case .tagSearch: return .tagSearch
        }
    }

    /// Match Finder's default name for a freshly created folder, in any common
    /// locale, including the numeric suffix Finder appends for duplicates.
    /// Examples: "untitled folder", "untitled folder 2", "Untitled Folder 17",
    /// "New Folder", "New Folder With Items".
    private func isUntitledFolderPlaceholder(_ name: String) -> Bool {
        let trimmed = name.lowercased().trimmingCharacters(in: .whitespaces)
        let placeholders = [
            "untitled folder",
            "new folder",
            "new folder with items"
        ]
        for placeholder in placeholders {
            if trimmed == placeholder { return true }
            // Allow trailing " 2", " 17", etc.
            if trimmed.hasPrefix(placeholder + " "),
               let suffix = trimmed.split(separator: " ").last,
               Int(suffix) != nil {
                return true
            }
        }
        return false
    }

    private func showNotification(folderName: String, symbol: String, source: MatchSource) async {
        guard BackgroundMonitoringStore.notificationsEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "Icon Applied"
        content.body = "Applied \(symbol) to \"\(folderName)\" via \(source.rawValue)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        try? await UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - Background Monitoring Store

enum BackgroundMonitoringStore {
    private static let enabledKey = "iconic.backgroundMonitoring.enabled"
    private static let notificationsKey = "iconic.backgroundMonitoring.notifications"
    private static let locationsKey = "iconic.backgroundMonitoring.locations"

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: enabledKey)
    }

    static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: enabledKey)
    }

    static var notificationsEnabled: Bool {
        get {
            // Default to true if not set
            if UserDefaults.standard.object(forKey: notificationsKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: notificationsKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: notificationsKey)
        }
    }

    static var monitoredLocations: [URL] {
        get {
            guard let data = UserDefaults.standard.data(forKey: locationsKey),
                  let paths = try? JSONDecoder().decode([String].self, from: data) else {
                // Default to common locations
                return defaultLocations
            }
            return paths.map { URL(fileURLWithPath: $0) }
        }
        set {
            let paths = newValue.map { $0.path }
            if let data = try? JSONEncoder().encode(paths) {
                UserDefaults.standard.set(data, forKey: locationsKey)
            }
        }
    }

    static var defaultLocations: [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            home.appendingPathComponent("Desktop"),
            home.appendingPathComponent("Documents"),
            home.appendingPathComponent("Downloads")
        ]
    }

    static func addLocation(_ url: URL) {
        var locations = monitoredLocations
        if !locations.contains(where: { $0.path == url.path }) {
            locations.append(url)
            monitoredLocations = locations
        }
    }

    static func removeLocation(_ url: URL) {
        var locations = monitoredLocations
        locations.removeAll { $0.path == url.path }
        monitoredLocations = locations
    }
}
