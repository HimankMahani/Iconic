//
//  IconicViewModel.swift
//  Iconic
//
//  Coordinator: scan folder → map names to symbols → render previews →
//  apply / restore icons. Drives the UI.
//

import AppKit
import SwiftUI
import Combine

enum FolderItemStatus: Equatable {
    case pending
    case applying
    case applied
    case restored
    case failed(String)
}

/// Rich error context for surfacing actionable, user-friendly messages in the UI.
struct ErrorInfo {
    let message: String
    let suggestion: String?
    let canRetry: Bool
    let isWarning: Bool

    init(message: String, suggestion: String? = nil, canRetry: Bool = false, isWarning: Bool = false) {
        self.message = message
        self.suggestion = suggestion
        self.canRetry = canRetry
        self.isWarning = isWarning
    }
}

struct BatchSummary {
    let operation: String // "Applied" or "Restored"
    let succeeded: Int
    let failed: Int
    let duration: TimeInterval
    let timestamp: Date

    var total: Int { succeeded + failed }
    var hasFailures: Bool { failed > 0 }
}

enum MatchSource: Equatable {
    case rule(ruleName: String)
    case smartDetection(type: String)
    case customMapping
    case aiSuggestion(confidence: Double)
    case localDictionary
    case fuzzyMatch
    case userEdited

    var displayName: String {
        switch self {
        case .rule(let name): return "Rule: \(name)"
        case .smartDetection(let type): return "Detected: \(type)"
        case .customMapping: return "Custom Mapping"
        case .aiSuggestion(let conf): return "AI (\(Int(conf * 100))%)"
        case .localDictionary: return "Dictionary"
        case .fuzzyMatch: return "Fuzzy Match"
        case .userEdited: return "Manual"
        }
    }

    var icon: String {
        switch self {
        case .rule: return "wand.and.stars"
        case .smartDetection: return "brain"
        case .customMapping: return "list.bullet"
        case .aiSuggestion: return "sparkles"
        case .localDictionary: return "book.closed"
        case .fuzzyMatch: return "textformat.abc"
        case .userEdited: return "pencil"
        }
    }

    var color: Color {
        switch self {
        case .rule: return .purple
        case .smartDetection: return .blue
        case .customMapping: return .orange
        case .aiSuggestion: return .pink
        case .localDictionary: return .gray
        case .fuzzyMatch: return .gray
        case .userEdited: return .green
        }
    }
}

@MainActor
final class FolderItem: ObservableObject, Identifiable {
    let id = UUID()
    let url: URL
    @Published var symbolNames: [String] = []
    @Published var symbolColor: NSColor?
    @Published var folderColor: NSColor?
    @Published var preview: NSImage?
    @Published var originalIcon: NSImage?
    @Published var status: FolderItemStatus = .pending
    @Published var symbolOpacity: Double = 1.0
    @Published var symbolScale: Double = 1.0
    @Published var symbolOffsetY: Double = 0.0
    @Published var customImage: NSImage?
    @Published var symbolGradientEnd: NSColor?
    @Published var matchSource: MatchSource = .localDictionary

    /// Backward compatibility: returns the first symbol name or default
    var symbolName: String {
        symbolNames.first ?? "folder.fill"
    }

    var displayName: String { url.lastPathComponent }

    /// Returns true if the new icon differs from the original
    var hasChanges: Bool {
        guard let original = originalIcon, let new = preview else { return false }
        return !areImagesEqual(original, new)
    }

    private func areImagesEqual(_ img1: NSImage, _ img2: NSImage) -> Bool {
        guard let tiff1 = img1.tiffRepresentation,
              let tiff2 = img2.tiffRepresentation else { return false }
        return tiff1 == tiff2
    }

    init(url: URL, symbolName: String, symbolColor: NSColor? = nil, folderColor: NSColor? = nil) {
        self.url = url
        self.symbolNames = [symbolName]
        self.symbolColor = symbolColor
        self.folderColor = folderColor
    }

    init(url: URL, symbolNames: [String], symbolColor: NSColor? = nil, folderColor: NSColor? = nil) {
        self.url = url
        self.symbolNames = symbolNames
        self.symbolColor = symbolColor
        self.folderColor = folderColor
    }
}

@MainActor
final class IconicViewModel: ObservableObject {

    @Published var rootURLs: [URL] = []
    @Published var items: [FolderItem] = []

    /// Backward compatibility: returns the first root URL if available
    var rootURL: URL? { rootURLs.first }
    @Published var isScanning: Bool = false
    @Published var scanFoundCount: Int = 0
    @Published var scanCurrentPath: String = ""
    @Published var isApplying: Bool = false
    @Published var progress: Double = 0  // 0...1
    @Published var currentProcessingPath: String = ""
    @Published var currentProcessingIndex: Int = 0
    @Published var totalProcessingCount: Int = 0
    @Published var batchStartTime: Date?
    @Published var lastError: String?
    /// Rich error context shown in the footer with optional recovery suggestion and retry affordance.
    /// Preferred over `lastError` when set.
    @Published var errorInfo: ErrorInfo?
    @Published var matchingMode: MatchingMode = .local
    @Published var searchText: String = ""
    @Published var statusFilter: StatusFilter = .all
    @Published var isDryRunMode: Bool = false {
        didSet {
            // Leaving dry run mode clears any pending auto-apply previews so the
            // visual indicator doesn't stick around outside preview workflows.
            if !isDryRunMode {
                autoApplyMatchedIDs.removeAll()
            }
        }
    }
    @Published var selectedItemIDs: Set<UUID> = []
    @Published var isWatching: Bool = false

    /// IDs of items that matched an auto-apply rule during the last scan while
    /// dry run mode was active. The UI can use this to flag rows that *would*
    /// be auto-applied if the user exits preview mode.
    @Published var autoApplyMatchedIDs: Set<UUID> = []

    @Published var lastBatchSummary: BatchSummary?
    @Published var showBatchSummary: Bool = false
    @Published var recentlyAppliedItemIDs: Set<UUID> = []

    /// Number of SIP-protected folders found in the most recent scan. The UI
    /// can use this to surface a banner explaining why some folders cannot
    /// be modified.
    @Published var sipProtectedCount: Int = 0

    // MARK: - Toast notifications

    enum ToastType {
        case info, success, warning, learning
    }

    @Published var toastMessage: String?
    @Published var toastIcon: String?
    @Published var toastType: ToastType = .info

    /// Shows a transient toast notification that auto-dismisses after 3 seconds.
    /// - Parameters:
    ///   - message: Text to display.
    ///   - icon: SF Symbol name to show alongside the message.
    ///   - type: Visual style for the toast.
    func showToast(_ message: String, icon: String, type: ToastType = .info) {
        toastMessage = message
        toastIcon = icon
        toastType = type
        Task {
            try? await Task.sleep(for: .seconds(3))
            await MainActor.run {
                if self.toastMessage == message {
                    self.toastMessage = nil
                }
            }
        }
    }

    // MARK: - Cache feedback

    /// Tracks how many folder lookups in the most recent AI scan were served
    /// from the persistent cache vs. requiring a fresh API call.
    struct CacheInfo {
        let hitCount: Int
        let totalCount: Int
        var hitRate: Double { totalCount > 0 ? Double(hitCount) / Double(totalCount) : 0 }
    }

    @Published var lastCacheInfo: CacheInfo?

    private var folderWatcher: FolderWatcher?

    /// Estimated remaining seconds for the current batch operation, or nil if unavailable.
    var estimatedRemainingSeconds: TimeInterval? {
        guard let start = batchStartTime,
              currentProcessingIndex > 0,
              totalProcessingCount > currentProcessingIndex else { return nil }
        let elapsed = Date().timeIntervalSince(start)
        let perItem = elapsed / Double(currentProcessingIndex)
        let remaining = Double(totalProcessingCount - currentProcessingIndex) * perItem
        return remaining
    }

    let undoManager = IconicUndoManager()
    private var lastSelectedItem: FolderItem?

    enum MatchingMode {
        case local
        case ai
    }

    enum StatusFilter: String, CaseIterable {
        case all = "All"
        case applied = "Applied"
        case restored = "Restored"
        case failed = "Failed"
        case pending = "Pending"
        case changed = "Changed"
    }

    var filteredItems: [FolderItem] {
        var result = items

        // Filter by search text
        if !searchText.isEmpty {
            result = result.filter { item in
                item.displayName.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Filter by status
        switch statusFilter {
        case .all:
            break
        case .applied:
            result = result.filter { $0.status == .applied }
        case .restored:
            result = result.filter { $0.status == .restored }
        case .failed:
            result = result.filter {
                if case .failed = $0.status { return true }
                return false
            }
        case .pending:
            result = result.filter { $0.status == .pending }
        case .changed:
            result = result.filter { $0.hasChanges }
        }

        return result
    }

    // MARK: - Dry Run Helpers

    var pendingItemsCount: Int {
        items.filter { $0.status == .pending }.count
    }

    var alreadyAppliedCount: Int {
        items.filter { $0.status == .applied || $0.status == .restored }.count
    }

    var selectedItems: [FolderItem] {
        items.filter { selectedItemIDs.contains($0.id) }
    }

    // MARK: - Selection

    /// Single-click selection: replaces the selection with just this item.
    func selectOnly(_ item: FolderItem) {
        selectedItemIDs = [item.id]
        lastSelectedItem = item
    }

    /// Cmd-click selection: toggles the item in the current selection.
    func toggleSelection(_ item: FolderItem) {
        if selectedItemIDs.contains(item.id) {
            selectedItemIDs.remove(item.id)
        } else {
            selectedItemIDs.insert(item.id)
            lastSelectedItem = item
        }
    }

    /// Shift-click selection: select the range from the last selected item to this one.
    func extendSelection(to item: FolderItem) {
        let visible = filteredItems
        guard let anchor = lastSelectedItem,
              let anchorIdx = visible.firstIndex(where: { $0.id == anchor.id }),
              let targetIdx = visible.firstIndex(where: { $0.id == item.id }) else {
            selectOnly(item)
            return
        }
        let range = anchorIdx <= targetIdx ? anchorIdx...targetIdx : targetIdx...anchorIdx
        for i in range { selectedItemIDs.insert(visible[i].id) }
    }

    func selectAllVisible() {
        selectedItemIDs = Set(filteredItems.map { $0.id })
        lastSelectedItem = filteredItems.last
    }

    func clearSelection() {
        selectedItemIDs.removeAll()
        lastSelectedItem = nil
    }

    /// Move the selection up or down one row in the currently visible list.
    /// Returns true if it moved (so the caller can scroll into view).
    @discardableResult
    func moveSelection(by delta: Int) -> FolderItem? {
        let visible = filteredItems
        guard !visible.isEmpty else { return nil }
        let nextIdx: Int
        if let current = lastSelectedItem,
           let idx = visible.firstIndex(where: { $0.id == current.id }) {
            nextIdx = max(0, min(visible.count - 1, idx + delta))
        } else {
            nextIdx = delta >= 0 ? 0 : visible.count - 1
        }
        let target = visible[nextIdx]
        selectOnly(target)
        return target
    }

    /// First selected item, or the last navigation anchor, or first visible.
    var focusedItem: FolderItem? {
        selectedItems.first ?? lastSelectedItem ?? filteredItems.first
    }

    // MARK: - Batch actions on selection

    func applySelected() {
        for item in selectedItems { apply(item) }
    }

    func restoreSelected() {
        for item in selectedItems { restore(item) }
    }

    // MARK: - Copy / Paste icon settings

    func copyIconSettings(from item: FolderItem) {
        let settings = IconSettings(
            symbolName: item.symbolName,
            symbolColor: item.symbolColor,
            folderColor: item.folderColor
        )
        IconClipboard.copy(settings)
    }

    func pasteIconSettings(to item: FolderItem) {
        guard let settings = IconClipboard.paste() else { return }
        item.symbolNames = [settings.symbolName]
        item.symbolColor = settings.symbolColor
        item.folderColor = settings.folderColor
        rerender(item)
    }

    func pasteIconSettingsToSelected() {
        guard let settings = IconClipboard.paste() else { return }
        for item in selectedItems {
            item.symbolNames = [settings.symbolName]
            item.symbolColor = settings.symbolColor
            item.folderColor = settings.folderColor
            rerender(item)
        }
    }

    // MARK: - Undo / Redo

    func performUndo() {
        undoManager.undo(
            items: items,
            applyIcon: { [weak self] item, _, _ in self?.apply(item) },
            restoreIcon: { [weak self] item in self?.restore(item) }
        )
    }

    func performRedo() {
        undoManager.redo(
            items: items,
            applyIcon: { [weak self] item, _, _ in self?.apply(item) },
            restoreIcon: { [weak self] item in self?.restore(item) }
        )
    }

    private let mappings: CustomMappingsStore
    private let rulesStore: RulesStore?
    private let analyticsStore: AnalyticsStore?
    private let suggestionsStore: SmartSuggestionsStore?
    private let learningStore: AILearningStore?
    private var securityScopeURL: URL?
    private var batchTask: Task<Void, Never>?

    // Track AI suggestions so we can detect corrections
    private var aiSuggestions: [UUID: String] = [:]

    init(mappings: CustomMappingsStore, rulesStore: RulesStore? = nil, analyticsStore: AnalyticsStore? = nil, suggestionsStore: SmartSuggestionsStore? = nil, learningStore: AILearningStore? = nil) {
        self.mappings = mappings
        self.rulesStore = rulesStore
        self.analyticsStore = analyticsStore
        self.suggestionsStore = suggestionsStore
        self.learningStore = learningStore
    }

    // MARK: - Folder selection

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "Choose Folders"
        panel.message = "Pick one or more folders. Iconic will scan them recursively."
        if panel.runModal() == .OK, !panel.urls.isEmpty {
            adoptRoots(panel.urls)
        }
    }

    func restoreLastFolderIfAvailable() {
        guard let resolved = BookmarkStore.resolve() else { return }
        if resolved.didStartAccessing {
            securityScopeURL = resolved.url
        }
        Task { await scan(resolved.url) }
        rootURLs = [resolved.url]
    }

    func adoptRoot(_ url: URL) {
        adoptRoots([url])
    }

    func adoptRoots(_ urls: [URL]) {
        guard !urls.isEmpty else { return }

        // Stop watching when switching folders
        stopWatching()

        // Release prior scope if any.
        securityScopeURL?.stopAccessingSecurityScopedResource()
        securityScopeURL = nil

        // Save first URL as bookmark and add all to recents
        BookmarkStore.save(urls[0])
        for url in urls {
            RecentFoldersStore.add(url)
        }

        rootURLs = urls
        items.removeAll()

        Task {
            await scanMultipleRoots(urls)
        }
    }

    // MARK: - Scan + map + render

    private func scanMultipleRoots(_ roots: [URL]) async {
        isScanning = true
        scanFoundCount = 0
        scanCurrentPath = roots.first?.path ?? ""
        defer {
            isScanning = false
            scanFoundCount = 0
            scanCurrentPath = ""
        }

        items.removeAll()
        progress = 0
        lastError = nil
        errorInfo = nil

        var options = FolderScanner.Options()
        if ExcludePatternsStore.isEnabled {
            options.excludePatterns = ExcludePatternsStore.patterns
        }

        // Scan all roots in parallel and merge results
        let allURLs = await withTaskGroup(of: [URL].self) { group in
            for root in roots {
                group.addTask {
                    await FolderScanner.scan(root, options: options) { [weak self] count, url in
                        Task { @MainActor in
                            guard let self else { return }
                            self.scanFoundCount = count
                            self.scanCurrentPath = url.path
                        }
                    }
                }
            }

            var merged: [URL] = []
            for await urls in group {
                merged.append(contentsOf: urls)
            }
            return merged
        }

        let custom = mappings.dictionary

        // Try Gemini AI if enabled and key exists
        if let apiKey = SettingsViewModel.getAPIKeyIfEnabled() {
            matchingMode = .ai
            await scanWithGemini(urls: allURLs, apiKey: apiKey, customMappings: custom)
        } else {
            matchingMode = .local
            await scanWithLocalMatcher(urls: allURLs, customMappings: custom)
        }

        // Assign beautiful colors if enabled
        if AutoColorStore.isEnabled {
            assignBeautifulColors()
        }

        // Render previews off the main thread
        await renderPreviews(for: items)

        // Flag SIP-protected folders so the user understands why some rows
        // will fail to apply.
        sipProtectedCount = items.filter { IconApplier.isSIPProtected($0.url) }.count
        if sipProtectedCount > 0 {
            showToast(
                "\(sipProtectedCount) SIP-protected folder(s) found - they cannot be modified",
                icon: "lock.shield.fill",
                type: .warning
            )
        }

        // Auto-apply rules that opted in
        autoApplyMatchingRules()
    }

    /// Re-runs the most recent scan. Used by the footer retry affordance after an error.
    func retryScan() {
        let roots = rootURLs
        guard !roots.isEmpty else { return }
        errorInfo = nil
        lastError = nil
        Task {
            if roots.count == 1, let only = roots.first {
                await scan(only)
            } else {
                await scanMultipleRoots(roots)
            }
        }
    }

    func scan(_ root: URL) async {
        isScanning = true
        scanFoundCount = 0
        scanCurrentPath = root.path
        defer {
            isScanning = false
            scanFoundCount = 0
            scanCurrentPath = ""
        }

        items.removeAll()
        progress = 0
        lastError = nil
        errorInfo = nil

        var options = FolderScanner.Options()
        if ExcludePatternsStore.isEnabled {
            options.excludePatterns = ExcludePatternsStore.patterns
        }

        let urls = await FolderScanner.scan(root, options: options) { [weak self] count, url in
            // Called on background queue; hop to main for UI state.
            Task { @MainActor in
                guard let self else { return }
                self.scanFoundCount = count
                self.scanCurrentPath = url.path
            }
        }
        let custom = mappings.dictionary

        // Try Gemini AI if enabled and key exists
        if let apiKey = SettingsViewModel.getAPIKeyIfEnabled() {
            matchingMode = .ai
            await scanWithGemini(urls: urls, apiKey: apiKey, customMappings: custom)
        } else {
            matchingMode = .local
            await scanWithLocalMatcher(urls: urls, customMappings: custom)
        }

        // Assign beautiful colors if enabled
        if AutoColorStore.isEnabled {
            assignBeautifulColors()
        }

        // Render previews off the main thread
        await renderPreviews(for: items)

        // Flag SIP-protected folders so the user understands why some rows
        // will fail to apply.
        sipProtectedCount = items.filter { IconApplier.isSIPProtected($0.url) }.count
        if sipProtectedCount > 0 {
            showToast(
                "\(sipProtectedCount) SIP-protected folder(s) found - they cannot be modified",
                icon: "lock.shield.fill",
                type: .warning
            )
        }

        // Auto-apply rules that opted in
        autoApplyMatchingRules()
    }

    private func autoApplyMatchingRules() {
        // Reset the dry-run preview set; it'll be repopulated below if needed.
        autoApplyMatchedIDs.removeAll()

        guard let rulesStore else { return }
        let autoApplyRules = rulesStore.rules.filter { $0.enabled && $0.autoApply }
        guard !autoApplyRules.isEmpty else { return }

        var matchedItems: [FolderItem] = []
        var conflictItems: [FolderItem] = []

        for item in items where item.status == .pending {
            if autoApplyRules.contains(where: { $0.matches(item.url.lastPathComponent) }) {
                // Flag folders that already carry a custom icon so we don't
                // silently overwrite icons set elsewhere.
                if IconApplier.hasCustomIcon(item.url) {
                    conflictItems.append(item)
                } else {
                    matchedItems.append(item)
                }
            }
        }

        // Dry run mode: don't apply, just record IDs the UI can flag and tell
        // the user how many would have been auto-applied.
        if isDryRunMode {
            autoApplyMatchedIDs = Set(matchedItems.map { $0.id })
            if !matchedItems.isEmpty {
                showToast("\(matchedItems.count) folder(s) matched auto-apply rules (preview mode)", icon: "wand.and.stars", type: .info)
            }
            if !conflictItems.isEmpty {
                errorInfo = ErrorInfo(
                    message: "\(conflictItems.count) folder(s) have existing icons",
                    suggestion: "Review and apply manually if needed",
                    canRetry: false,
                    isWarning: true
                )
            }
            return
        }

        // Not in dry run mode — actually apply rule matches.
        for item in matchedItems {
            apply(item)
        }

        if !matchedItems.isEmpty {
            showToast("Auto-applied \(matchedItems.count) folder(s) via rules", icon: "wand.and.stars", type: .success)
        }

        // Warn about conflicts so they aren't silently skipped.
        if !conflictItems.isEmpty {
            errorInfo = ErrorInfo(
                message: "\(conflictItems.count) folder(s) have existing icons",
                suggestion: "Review and apply manually if needed",
                canRetry: false,
                isWarning: true
            )
        }
    }

    /// Resolves a folder name to a glyph (SF Symbol name OR emoji) using the
    /// local matcher matching the current icon style. Lets the rest of the
    /// scan code branch on style in one place.
    private static func localGlyph(for name: String, customMappings: [String: String]) -> String {
        switch IconStyleStore.current {
        case .sfSymbol:
            return SymbolMapper.symbol(for: name, customMappings: customMappings)
        case .emoji:
            return EmojiMapper.emoji(for: name, customMappings: customMappings)
        }
    }

    /// Validates that a glyph returned by AI is renderable for the current
    /// icon style. For SF Symbols this checks `NSImage(systemSymbolName:)`;
    /// for emoji we accept any string with at least one emoji scalar.
    private static func isValidAIGlyph(_ glyph: String) -> Bool {
        switch IconStyleStore.current {
        case .sfSymbol:
            return NSImage(systemSymbolName: glyph, accessibilityDescription: nil) != nil
        case .emoji:
            return glyph.isEmojiGlyph
        }
    }

    private func scanWithGemini(urls: [URL], apiKey: String, customMappings: [String: String]) async {
        let folderNames = urls.map { $0.lastPathComponent }
        let iconStyle = IconStyleStore.current

        // Get learning examples from AILearningStore for few-shot learning
        let learningExamples = learningStore?.getAllExamples(limit: 20)

        // Analyze folder contents if AI Content Analysis is enabled
        // This provides additional context to improve AI matching accuracy
        var contentAnalysis: [FolderContentAnalyzer.ContentAnalysis]? = nil
        if AIContentAnalysisStore.isEnabled {
            contentAnalysis = await Task.detached(priority: .userInitiated) {
                urls.compactMap { url in
                    FolderContentAnalyzer.analyze(url)
                }
            }.value
        }

        // Snapshot cache size before the call so we can compute how many
        // folders were served from the cache vs. fetched from the API.
        let cacheEntriesBefore = GeminiService.getCacheStats().totalEntries

        do {
            let geminiMatches = try await GeminiService.matchFolders(folderNames, apiKey: apiKey, style: iconStyle, learningExamples: learningExamples, contentAnalysis: contentAnalysis)

            // Compute per-scan cache info: any folder that did NOT add a new
            // cache entry was a hit (already cached). New entries equal misses.
            let cacheEntriesAfter = GeminiService.getCacheStats().totalEntries
            let newEntries = max(0, cacheEntriesAfter - cacheEntriesBefore)
            let totalCount = folderNames.count
            let hitCount = max(0, totalCount - newEntries)
            lastCacheInfo = CacheInfo(hitCount: hitCount, totalCount: totalCount)

            let newItems: [FolderItem] = urls.map { url in
                let name = url.lastPathComponent
                var symbol: String
                var ruleSymbolColor: NSColor?
                var ruleFolderColor: NSColor?
                var wasAISuggestion = false
                var source: MatchSource = .localDictionary
                var aiConfidence: Double = 0

                // Highest priority: user-defined rules
                if let rule = rulesStore?.firstMatch(for: name) {
                    symbol = rule.symbol
                    ruleSymbolColor = rule.symbolColor
                    ruleFolderColor = rule.folderColor
                    source = .rule(ruleName: rule.name)
                } else if SmartContentDetectionStore.isEnabled, let detectedSym = FolderTypeDetector.detectType(at: url) {
                    symbol = detectedSym
                    source = .smartDetection(type: Self.smartDetectionTypeDescription(for: detectedSym))
                } else if let customSym = customMappings[name.lowercased()] {
                    symbol = customSym
                    source = .customMapping
                } else if let matchResult = geminiMatches[name] {
                    // Use Gemini match if confidence is acceptable (>= 0.6)
                    if matchResult.confidence >= 0.6 {
                        // Validate the glyph renders for the current icon style;
                        // fall back to the local matcher (style-aware) if not.
                        if Self.isValidAIGlyph(matchResult.symbol) {
                            symbol = matchResult.symbol
                            wasAISuggestion = true
                            aiConfidence = matchResult.confidence
                            source = .aiSuggestion(confidence: matchResult.confidence)
                        } else {
                            symbol = Self.localGlyph(for: name, customMappings: [:])
                            source = .localDictionary
                        }
                    } else {
                        // Low confidence, use local matcher
                        symbol = Self.localGlyph(for: name, customMappings: [:])
                        source = .localDictionary
                    }
                } else {
                    symbol = Self.localGlyph(for: name, customMappings: [:])
                    source = .localDictionary
                }

                let item = FolderItem(url: url, symbolName: symbol, symbolColor: ruleSymbolColor, folderColor: ruleFolderColor)
                item.matchSource = source
                _ = aiConfidence  // confidence already captured in source

                // Track AI suggestions so we can detect corrections later
                if wasAISuggestion {
                    aiSuggestions[item.id] = symbol
                }

                return item
            }
            items = newItems

        } catch let error as GeminiService.GeminiError {
            errorInfo = ErrorInfo(
                message: error.localizedDescription,
                suggestion: error.recoverySuggestion,
                canRetry: error != .missingAPIKey && error != .invalidAPIKeyFormat,
                isWarning: true
            )
            lastError = error.localizedDescription
            matchingMode = .local
            await scanWithLocalMatcher(urls: urls, customMappings: customMappings)
        } catch {
            errorInfo = ErrorInfo(
                message: "AI matching failed: \(error.localizedDescription)",
                suggestion: "Using local matching instead",
                canRetry: true,
                isWarning: true
            )
            lastError = "Gemini AI failed: \(error.localizedDescription). Using local matching."
            matchingMode = .local
            await scanWithLocalMatcher(urls: urls, customMappings: customMappings)
        }
    }

    private func scanWithLocalMatcher(urls: [URL], customMappings: [String: String]) async {
        let newItems: [FolderItem] = urls.map { u in
            let name = u.lastPathComponent
            var sym: String
            var ruleSymbolColor: NSColor?
            var ruleFolderColor: NSColor?
            var source: MatchSource = .localDictionary

            // Highest priority: user-defined rules
            if let rule = rulesStore?.firstMatch(for: name) {
                sym = rule.symbol
                ruleSymbolColor = rule.symbolColor
                ruleFolderColor = rule.folderColor
                source = .rule(ruleName: rule.name)
            } else if SmartContentDetectionStore.isEnabled, let detectedSym = FolderTypeDetector.detectType(at: u) {
                sym = detectedSym
                source = .smartDetection(type: Self.smartDetectionTypeDescription(for: detectedSym))
            } else if let customSym = customMappings[name.lowercased()] {
                sym = customSym
                source = .customMapping
            } else {
                sym = Self.localGlyph(for: name, customMappings: customMappings)
                source = .localDictionary
            }
            let item = FolderItem(url: u, symbolName: sym, symbolColor: ruleSymbolColor, folderColor: ruleFolderColor)
            item.matchSource = source
            return item
        }
        items = newItems
    }

    /// Maps a smart-detection result symbol to a human-readable type description
    /// shown in the match-source badge.
    static func smartDetectionTypeDescription(for symbol: String) -> String {
        switch symbol {
        case "arrow.triangle.branch": return "Git"
        case "hammer.fill": return "Xcode"
        case "cube.fill": return "Node.js"
        case "chevron.left.forwardslash.chevron.right": return "Python"
        case "shippingbox.fill": return "Docker"
        case "photo.stack": return "Photos"
        case "film.stack.fill": return "Videos"
        default: return "Content"
        }
    }

    private func renderPreviews(for items: [FolderItem]) async {
        let defaultColor = ColorPreferences.getDefaultColor()
        struct RenderPair {
            let id: UUID
            let symbol: String
            let color: NSColor
            let folderTint: NSColor?
            let path: String
            let opacity: Double
            let scale: Double
            let offsetY: Double
            let gradientEnd: NSColor?
            let customImage: NSImage?
        }
        let pairs = items.map {
            RenderPair(
                id: $0.id,
                symbol: $0.symbolName,
                color: $0.symbolColor ?? defaultColor,
                folderTint: $0.folderColor,
                path: $0.url.path,
                opacity: $0.symbolOpacity,
                scale: $0.symbolScale,
                offsetY: $0.symbolOffsetY,
                gradientEnd: $0.symbolGradientEnd,
                customImage: $0.customImage
            )
        }
        let rendered = await Task.detached(priority: .userInitiated) {
            pairs.map { p -> (UUID, NSImage?, NSImage) in
                let preview = IconRenderer.makeIcon(
                    symbolNames: [p.symbol],
                    tint: p.color,
                    folderTint: p.folderTint,
                    opacity: p.opacity,
                    scale: p.scale,
                    offsetY: p.offsetY,
                    gradientEnd: p.gradientEnd,
                    customImage: p.customImage
                )
                let current = NSWorkspace.shared.icon(forFile: p.path)
                return (p.id, preview, current)
            }
        }.value
        var previewLookup: [UUID: NSImage?] = [:]
        var originalLookup: [UUID: NSImage] = [:]
        for (id, preview, original) in rendered {
            previewLookup[id] = preview
            originalLookup[id] = original
        }
        for item in items {
            item.preview = previewLookup[item.id] ?? nil
            if item.originalIcon == nil {
                item.originalIcon = originalLookup[item.id]
            }
        }
    }

    /// Re-resolve a single item's symbol from the mapping rules and re-render.
    /// Use after custom mappings change.
    func refreshSymbol(for item: FolderItem) {
        let custom = mappings.dictionary
        item.symbolNames = [Self.localGlyph(for: item.url.lastPathComponent, customMappings: custom)]
        rerender(item)
    }

    /// Re-render the preview using the item's current `symbolNames`.
    /// Use after the user manually edits the symbol.
    func rerender(_ item: FolderItem) {
        // Check if this was an AI suggestion that the user is now correcting
        if let aiSuggestion = aiSuggestions[item.id],
           aiSuggestion != item.symbolName,
           matchingMode == .ai {
            // Record the correction for future learning
            learningStore?.recordCorrection(
                folderName: item.displayName,
                aiSuggestion: aiSuggestion,
                userChoice: item.symbolName
            )
            // Surface the learning event to the user via a toast.
            showToast(
                "AI learned: '\(item.displayName)' → \(item.symbolName)",
                icon: "brain.head.profile",
                type: .learning
            )
            // Clear the tracked suggestion since we've recorded it
            aiSuggestions.removeValue(forKey: item.id)
        }

        // Mark as user-edited since rerender is called after manual edits.
        if item.matchSource != .userEdited {
            item.matchSource = .userEdited
        }
        let syms = item.symbolNames
        let color = item.symbolColor ?? ColorPreferences.getDefaultColor()
        let folderTint = item.folderColor
        let opacity = item.symbolOpacity
        let scale = item.symbolScale
        let offsetY = item.symbolOffsetY
        let gradientEnd = item.symbolGradientEnd
        let customImage = item.customImage
        Task.detached(priority: .userInitiated) {
            let img = IconRenderer.makeIcon(
                symbolNames: syms,
                tint: color,
                folderTint: folderTint,
                opacity: opacity,
                scale: scale,
                offsetY: offsetY,
                gradientEnd: gradientEnd,
                customImage: customImage
            )
            await MainActor.run { item.preview = img }
        }
    }

    /// Assigns beautiful folder colors based on folder names and categories,
    /// and a derived darker shade for the symbol so it sits on the folder
    /// like a tinted etching (matching the macOS Customize Folder look).
    private func assignBeautifulColors() {
        let folderNames = items.map { $0.url.lastPathComponent }
        let colorAssignments = ColorPalette.assignColors(for: folderNames)

        for item in items {
            if item.folderColor == nil {
                item.folderColor = colorAssignments[item.url.lastPathComponent]
            }
            if item.symbolColor == nil, let folder = item.folderColor {
                item.symbolColor = Self.symbolShade(of: folder)
            }
        }
    }

    /// Darker, slightly translucent version of `color` — used as the SF
    /// Symbol color so it reads as a tinted etching of the folder body.
    static func symbolShade(of color: NSColor) -> NSColor {
        guard let rgb = color.usingColorSpace(.sRGB) else { return color }
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        rgb.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return NSColor(
            hue: h,
            saturation: min(1, s * 1.10),
            brightness: max(0, b * 0.55),
            alpha: 0.85
        )
    }

    // MARK: - Apply / restore

    func apply(_ item: FolderItem) {
        // Record previous state for undo
        let previousState = IconicUndoManager.FolderState(
            status: item.status,
            symbolName: item.symbolName,
            symbolColor: item.symbolColor
        )

        item.status = .applying
        let symbol = item.symbolName
        let color = item.symbolColor ?? ColorPreferences.getDefaultColor()
        let folderTint = item.folderColor
        let opacity = item.symbolOpacity
        let scale = item.symbolScale
        let offsetY = item.symbolOffsetY
        let gradientEnd = item.symbolGradientEnd
        let customImage = item.customImage
        let url = item.url
        Task.detached(priority: .userInitiated) {
            do {
                let icon = IconRenderer.makeIcon(
                    symbolName: symbol,
                    tint: color,
                    folderTint: folderTint,
                    opacity: opacity,
                    scale: scale,
                    offsetY: offsetY,
                    gradientEnd: gradientEnd,
                    customImage: customImage
                )
                try IconApplier.apply(icon, to: url)
                await MainActor.run {
                    item.status = .applied
                    self.analyticsStore?.recordApply(symbolName: symbol)
                    self.suggestionsStore?.recordChoice(folderName: item.displayName, symbolName: symbol)
                    // Record action for undo
                    self.undoManager.recordAction(.applySingle(url: url, previousState: previousState))

                    // Briefly mark this item for a success animation in the row.
                    let id = item.id
                    self.recentlyAppliedItemIDs.insert(id)
                    Task { [weak self] in
                        try? await Task.sleep(for: .seconds(1.5))
                        await MainActor.run {
                            self?.recentlyAppliedItemIDs.remove(id)
                        }
                    }
                }
            } catch {
                await MainActor.run { item.status = .failed(error.localizedDescription) }
            }
        }
    }

    /// Whether the user has actively narrowed the visible list. Used to scope
    /// "Apply All" / "Restore All" to the filtered subset.
    var hasActiveFilter: Bool {
        !searchText.isEmpty || statusFilter != .all
    }

    /// The set of items a batch action should operate on: filtered when the
    /// user has narrowed the list, otherwise all items.
    var batchTargets: [FolderItem] {
        hasActiveFilter ? filteredItems : items
    }

    func applyAll() {
        let snapshot = batchTargets
        guard !snapshot.isEmpty else { return }

        // Surface SIP-protected folders before kicking off the batch so the
        // user knows they'll be skipped (or the whole batch is unworkable).
        let sipFolders = snapshot.filter { IconApplier.isSIPProtected($0.url) }
        if !sipFolders.isEmpty {
            let regularFolders = snapshot.filter { !IconApplier.isSIPProtected($0.url) }

            if regularFolders.isEmpty {
                errorInfo = ErrorInfo(
                    message: "All selected folders are SIP-protected",
                    suggestion: "macOS protects these folders. Choose folders in your home directory.",
                    canRetry: false,
                    isWarning: true
                )
                return
            }

            // Some folders will be skipped — let the user know but continue.
            showToast(
                "Skipping \(sipFolders.count) SIP-protected folder(s)",
                icon: "lock.shield.fill",
                type: .warning
            )
        }

        isApplying = true
        progress = 0
        currentProcessingIndex = 0
        totalProcessingCount = snapshot.count
        batchStartTime = Date()
        let total = max(snapshot.count, 1)
        let defaultColor = ColorPreferences.getDefaultColor()
        batchTask = Task.detached(priority: .userInitiated) { [weak self] in
            var done = 0
            for item in snapshot {
                if Task.isCancelled { break }
                let sym = await MainActor.run { item.symbolName }
                let color = await MainActor.run { item.symbolColor ?? defaultColor }
                let folderTint = await MainActor.run { item.folderColor }
                let opacity = await MainActor.run { item.symbolOpacity }
                let scale = await MainActor.run { item.symbolScale }
                let offsetY = await MainActor.run { item.symbolOffsetY }
                let gradientEnd = await MainActor.run { item.symbolGradientEnd }
                let customImage = await MainActor.run { item.customImage }
                let url = await MainActor.run { item.url }
                await MainActor.run {
                    item.status = .applying
                    self?.currentProcessingPath = url.path
                    self?.currentProcessingIndex = done
                }
                do {
                    let icon = IconRenderer.makeIcon(
                        symbolName: sym,
                        tint: color,
                        folderTint: folderTint,
                        opacity: opacity,
                        scale: scale,
                        offsetY: offsetY,
                        gradientEnd: gradientEnd,
                        customImage: customImage
                    )
                    try IconApplier.apply(icon, to: url)
                    await MainActor.run {
                        item.status = .applied
                        self?.analyticsStore?.recordApply(symbolName: sym)
                    }
                } catch {
                    await MainActor.run {
                        item.status = .failed(error.localizedDescription)
                    }
                }
                done += 1
                let p = Double(done) / Double(total)
                await MainActor.run { self?.progress = p }
            }
            await MainActor.run {
                self?.isApplying = false
                self?.progress = 1
                self?.currentProcessingPath = ""
                self?.currentProcessingIndex = 0
                self?.totalProcessingCount = 0
                self?.batchTask = nil

                guard let strongSelf = self else { return }
                let succeeded = snapshot.filter { $0.status == .applied }.count
                let failed = snapshot.filter {
                    if case .failed = $0.status { return true }
                    return false
                }.count
                let duration = Date().timeIntervalSince(strongSelf.batchStartTime ?? Date())
                strongSelf.batchStartTime = nil

                strongSelf.lastBatchSummary = BatchSummary(
                    operation: "Applied",
                    succeeded: succeeded,
                    failed: failed,
                    duration: duration,
                    timestamp: Date()
                )
                strongSelf.showBatchSummary = true

                // Briefly highlight successfully applied items
                let appliedIDs = Set(snapshot.filter { $0.status == .applied }.map { $0.id })
                strongSelf.recentlyAppliedItemIDs.formUnion(appliedIDs)

                // Auto-hide summary after 5 seconds
                Task { [weak strongSelf] in
                    try? await Task.sleep(for: .seconds(5))
                    await MainActor.run {
                        strongSelf?.showBatchSummary = false
                    }
                }

                // Clear the highlight after a short window
                Task { [weak strongSelf] in
                    try? await Task.sleep(for: .seconds(1.5))
                    await MainActor.run {
                        strongSelf?.recentlyAppliedItemIDs.subtract(appliedIDs)
                    }
                }
            }
        }
    }

    func restore(_ item: FolderItem) {
        item.status = .applying
        let url = item.url
        Task.detached(priority: .userInitiated) {
            do {
                try IconApplier.restoreDefault(url)
                await MainActor.run {
                    item.status = .restored
                    self.analyticsStore?.recordRestore()
                }
            } catch {
                await MainActor.run { item.status = .failed(error.localizedDescription) }
            }
        }
    }

    func restoreAll() {
        let snapshot = batchTargets
        guard !snapshot.isEmpty else { return }
        isApplying = true
        progress = 0
        currentProcessingIndex = 0
        totalProcessingCount = snapshot.count
        batchStartTime = Date()
        let total = max(snapshot.count, 1)
        batchTask = Task.detached(priority: .userInitiated) { [weak self] in
            var done = 0
            for item in snapshot {
                if Task.isCancelled { break }
                let url = await MainActor.run { item.url }
                await MainActor.run {
                    item.status = .applying
                    self?.currentProcessingPath = url.path
                    self?.currentProcessingIndex = done
                }
                do {
                    try IconApplier.restoreDefault(url)
                    await MainActor.run {
                        item.status = .restored
                        self?.analyticsStore?.recordRestore()
                    }
                } catch {
                    await MainActor.run {
                        item.status = .failed(error.localizedDescription)
                    }
                }
                done += 1
                let p = Double(done) / Double(total)
                await MainActor.run { self?.progress = p }
            }
            await MainActor.run {
                self?.isApplying = false
                self?.progress = 1
                self?.currentProcessingPath = ""
                self?.currentProcessingIndex = 0
                self?.totalProcessingCount = 0
                self?.batchTask = nil

                guard let strongSelf = self else { return }
                let succeeded = snapshot.filter { $0.status == .restored }.count
                let failed = snapshot.filter {
                    if case .failed = $0.status { return true }
                    return false
                }.count
                let duration = Date().timeIntervalSince(strongSelf.batchStartTime ?? Date())
                strongSelf.batchStartTime = nil

                strongSelf.lastBatchSummary = BatchSummary(
                    operation: "Restored",
                    succeeded: succeeded,
                    failed: failed,
                    duration: duration,
                    timestamp: Date()
                )
                strongSelf.showBatchSummary = true

                Task { [weak strongSelf] in
                    try? await Task.sleep(for: .seconds(5))
                    await MainActor.run {
                        strongSelf?.showBatchSummary = false
                    }
                }
            }
        }
    }

    /// Cancel the in-flight Apply All / Restore All. Already-processed items
    /// keep their new status; pending items remain pending.
    func cancelBatch() {
        batchTask?.cancel()
    }

    // MARK: - Conflict detection

    /// Returns folders in `batchTargets` that already have a custom icon set
    /// (and weren't applied/restored by Iconic in this session).
    var foldersWithExistingIcons: [FolderItem] {
        batchTargets.filter { item in
            // Skip ones we know about — only flag truly external custom icons
            switch item.status {
            case .applied, .restored:
                return false
            default:
                return IconApplier.hasCustomIcon(item.url)
            }
        }
    }

    // MARK: - Auto-Watch Mode

    /// Start watching the root folder for new subdirectories.
    /// Only works when a single folder is selected.
    func startWatching() {
        guard rootURLs.count == 1, let root = rootURLs.first else {
            lastError = "Auto-watch only works with a single folder"
            return
        }

        stopWatching()

        folderWatcher = FolderWatcher()
        folderWatcher?.start(watching: root) { [weak self] newFolderURL in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                await self.scanAndApplyNewFolder(newFolderURL)
            }
        }

        isWatching = true
    }

    /// Stop watching for new folders.
    func stopWatching() {
        folderWatcher?.stop()
        folderWatcher = nil
        isWatching = false
    }

    /// Scan a newly detected folder, match it to a symbol, and auto-apply if rules match.
    private func scanAndApplyNewFolder(_ url: URL) async {
        let name = url.lastPathComponent
        let custom = mappings.dictionary

        var symbol: String
        var ruleSymbolColor: NSColor?
        var ruleFolderColor: NSColor?
        var shouldAutoApply = false
        var source: MatchSource = .localDictionary

        // Check if any auto-apply rule matches
        if let rule = rulesStore?.firstMatch(for: name), rule.autoApply {
            symbol = rule.symbol
            ruleSymbolColor = rule.symbolColor
            ruleFolderColor = rule.folderColor
            shouldAutoApply = true
            source = .rule(ruleName: rule.name)
        } else if SmartContentDetectionStore.isEnabled, let detectedSym = FolderTypeDetector.detectType(at: url) {
            symbol = detectedSym
            source = .smartDetection(type: Self.smartDetectionTypeDescription(for: detectedSym))
        } else if let customSym = custom[name.lowercased()] {
            symbol = customSym
            source = .customMapping
        } else {
            symbol = Self.localGlyph(for: name, customMappings: custom)
            source = .localDictionary
        }

        let item = FolderItem(url: url, symbolName: symbol, symbolColor: ruleSymbolColor, folderColor: ruleFolderColor)
        item.matchSource = source

        // Assign color if enabled
        if AutoColorStore.isEnabled {
            let colorAssignments = ColorPalette.assignColors(for: [name])
            if let folderColor = colorAssignments[name] {
                item.folderColor = folderColor
                item.symbolColor = Self.symbolShade(of: folderColor)
            }
        }

        // Render preview
        await renderPreviews(for: [item])

        // Add to items list
        items.append(item)

        // Auto-apply if rule matched — but respect dry run mode so the user's
        // preview workflow isn't broken by background folder monitoring.
        if shouldAutoApply {
            if isDryRunMode {
                autoApplyMatchedIDs.insert(item.id)
                showToast("New folder '\(name)' matched rules (preview mode)", icon: "folder.badge.plus", type: .info)
            } else {
                apply(item)
                showToast("Auto-applied icon to '\(name)'", icon: "folder.badge.plus", type: .success)
            }
        }
    }
}
