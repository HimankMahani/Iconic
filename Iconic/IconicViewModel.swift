//
// SPDX-License-Identifier: MIT
//  IconicViewModel.swift
//  Iconic
//
//  Coordinator: scan folder → map names to symbols → render previews →
//  apply / restore icons. Drives the UI.
//

import AppKit
import SwiftUI
import Combine

/// Lifecycle states a single folder row moves through from initial scan to
/// apply/restore. Stored on `FolderItem.status` and rendered in the row's
/// status badge.
enum FolderItemStatus: Equatable {
    case pending
    case applying
    case applied
    case restored
    case failed(String)
}

/// Rich error context for surfacing actionable, user-friendly messages in the UI.
struct ErrorInfo {
    /// Headline shown to the user. Plain text, no markdown.
    let message: String
    /// Optional follow-up explaining how to fix the problem. Shown beneath
    /// the message in the footer.
    let suggestion: String?
    /// When true, the footer surfaces a Retry button that re-runs the last
    /// scan. Set to false for non-recoverable states (e.g. invalid API key).
    let canRetry: Bool
    /// Distinguishes recoverable warnings (true) from blocking errors
    /// (false) so the footer can pick the right visual treatment.
    let isWarning: Bool

    init(message: String, suggestion: String? = nil, canRetry: Bool = false, isWarning: Bool = false) {
        self.message = message
        self.suggestion = suggestion
        self.canRetry = canRetry
        self.isWarning = isWarning
    }
}

/// Aggregate result of a batch Apply All / Restore All. Shown briefly in a
/// summary sheet after the batch finishes; the user dismisses it manually
/// or it auto-hides after a short delay.
struct BatchSummary {
    /// Human-readable verb for the operation, e.g. "Applied" or "Restored".
    let operation: String
    /// Number of items that ended in `.applied` / `.restored`.
    let succeeded: Int
    /// Number of items that ended in `.failed`.
    let failed: Int
    /// Wall-clock time the batch took, in seconds.
    let duration: TimeInterval
    /// When the batch finished. Used for ordering and display in history.
    let timestamp: Date

    var total: Int { succeeded + failed }
    var hasFailures: Bool { failed > 0 }
}

/// How a `FolderItem`'s symbol was resolved. Drives the match-source badge
/// in the row UI and the filter chips above the list. The cases' visual
/// metadata (`displayName`, `icon`, `color`) describe how each source is
/// presented to the user.
enum MatchSource: Equatable {
    case rule(ruleName: String)
    case smartDetection(type: String)
    case customMapping
    case aiSuggestion(confidence: Double)
    case localDictionary
    case fuzzyMatch
    case userEdited
    /// No reliable symbol/emoji found — the folder stays as the plain system
    /// folder and is skipped during apply. Used for AI failures, low confidence
    /// matches, and local fallback hits.
    case unassigned

    var displayName: String {
        switch self {
        case .rule(let name): return "Rule: \(name)"
        case .smartDetection(let type): return "Detected: \(type)"
        case .customMapping: return "Custom Mapping"
        case .aiSuggestion(let conf): return "AI (\(Int(conf * 100))%)"
        case .localDictionary: return "Dictionary"
        case .fuzzyMatch: return "Fuzzy Match"
        case .userEdited: return "Manual"
        case .unassigned: return "Unassigned"
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
        case .unassigned: return "questionmark.circle"
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
        case .unassigned: return .secondary
        }
    }
}

/// One row in the folder list. Owns the URL, the resolved symbol/colors,
/// the rendered preview, and the live adjustment sliders. All mutations
/// publish via `@Published` so SwiftUI rows can observe them directly. The
/// view model (`IconicViewModel`) creates instances during scan and mutates
/// them during apply/restore; the row view binds to the `@Published`
/// properties for the adjustment sliders.
@MainActor
final class FolderItem: ObservableObject, Identifiable {

    // MARK: - Defaults (shared with FolderRowView.resetAdjustments)

    /// Default opacity for a freshly-created folder row. Mirrored by
    /// FolderRowView's resetAdjustments.
    static let defaultSymbolOpacity: Double = 1.0

    /// Default scale for a freshly-created folder row. Mirrored by
    /// FolderRowView's resetAdjustments.
    static let defaultSymbolScale: Double = 1.0

    /// Default vertical offset for a freshly-created folder row. Mirrored
    /// by FolderRowView's resetAdjustments.
    static let defaultSymbolOffsetY: Double = 0.0

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

    /// True when the matcher gave up on this folder. Unassigned items keep
    /// the plain system folder icon, never get a tint or symbol overlay, and
    /// are skipped during apply so the user can review them manually.
    var isUnassigned: Bool {
        matchSource == .unassigned
    }

    /// Backward compatibility: returns the first symbol name. Empty for
    /// unassigned items so the renderer falls back to the plain system folder.
    var symbolName: String {
        symbolNames.first ?? ""
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

    /// Creates an unassigned placeholder: no symbol, no colors, no match
    /// source badge to act on. Use this when the matcher can't pick a
    /// confident symbol for a folder.
    static func unassigned(url: URL) -> FolderItem {
        let item = FolderItem(url: url, symbolName: "", symbolColor: nil, folderColor: nil)
        item.matchSource = .unassigned
        return item
    }
}

/// Central coordinator for the app. Owns the scanned folder tree, drives
/// the scan → match → render → apply/restore pipeline, and brokers UI
/// state (selection, search/filter, toasts, batch progress) to SwiftUI
/// views. All published state is mutated on the main actor.
@MainActor
final class IconicViewModel: ObservableObject {

    // MARK: - Sentinel values

    /// "Unassigned" sentinel: passing these opacity/scale/offsetY values to
    /// IconRenderer.makeIcon tells it to render a plain folder with no
    /// symbol layer. Used by the row-init and post-edit render paths.
    private enum RendererSentinel {
        static let opacity: Double = 0
        static let scale: Double = 0
        static let offsetY: Double = 0
    }

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
    @Published var selectedItemIDs: Set<UUID> = []
    @Published var isWatching: Bool = false

    @Published var lastBatchSummary: BatchSummary?
    @Published var showBatchSummary: Bool = false
    @Published var recentlyAppliedItemIDs: Set<UUID> = []

    /// Number of SIP-protected folders found in the most recent scan. The UI
    /// can use this to surface a banner explaining why some folders cannot
    /// be modified.
    @Published var sipProtectedCount: Int = 0

    // MARK: - Toast notifications

    /// Visual style for the transient toast banner shown via `showToast`.
    /// Drives color and SF Symbol for the four supported notification kinds.
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

    /// Which matcher the most recent scan used. `.ai` means Gemini was
    /// called (or attempted and fell back to local); `.local` means the
    /// local dictionary / smart-detection path ran without AI.
    enum MatchingMode {
        case local
        case ai
    }

    /// Filter chip shown above the folder list. `.unmapped` is the
    /// user-facing name for folders the matcher couldn't resolve (see
    /// `FolderItem.isUnassigned`).
    enum StatusFilter: String, CaseIterable {
        case all = "All"
        case applied = "Applied"
        case restored = "Restored"
        case failed = "Failed"
        case pending = "Pending"
        case changed = "Changed"
        case unmapped = "Unmapped"
    }

    /// Items the list view should currently display: the result of applying
    /// `searchText` and `statusFilter` to `items`. Recomputed every render.
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
        case .unmapped:
            // Folders that the matcher couldn't confidently resolve — they
            // stay as the plain system folder until the user picks a symbol.
            result = result.filter { $0.isUnassigned }
        }

        return result
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

    /// Select every currently visible item (respecting `searchText` and
    /// `statusFilter`). Anchors the shift-selection range to the last
    /// visible row.
    func selectAllVisible() {
        selectedItemIDs = Set(filteredItems.map { $0.id })
        lastSelectedItem = filteredItems.last
    }

    /// Drop the current selection. Used by Esc and by the Clear menu item.
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

    /// Apply the current selection one folder at a time. Each apply is
    /// recorded for undo; failures stay on the per-row status badge.
    func applySelected() {
        for item in selectedItems { apply(item) }
    }

    /// Restore the current selection to the system default folder icon.
    /// Each restore is recorded for undo.
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

    /// Apply the last copied icon settings (see `copyIconSettings`) to every
    /// currently selected item. No-op if the clipboard is empty.
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

    /// Undo the most recent recorded apply/restore. Wraps
    /// `IconicUndoManager.undo` with the closures needed to re-invoke
    /// `apply` / `restore` from this view model.
    func performUndo() {
        undoManager.undo(
            items: items,
            applyIcon: { [weak self] item, _, _ in self?.apply(item) },
            restoreIcon: { [weak self] item in self?.restore(item) }
        )
    }

    /// Redo the most recently undone apply/restore. Mirrors `performUndo`.
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

    /// Show an NSOpenPanel and, on OK, hand the chosen folders to
    /// `adoptRoots(_:)`. Allows multiple selection.
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

    /// Re-open the most recently used folder from the saved security-scoped
    /// bookmark. No-op if no bookmark exists or the bookmark can't be
    /// resolved.
    func restoreLastFolderIfAvailable() {
        guard let resolved = BookmarkStore.resolve() else { return }
        if resolved.didStartAccessing {
            securityScopeURL = resolved.url
        }
        Task { await scan(resolved.url) }
        rootURLs = [resolved.url]
    }

    /// Adopt a single root URL. Equivalent to `adoptRoots([url])` and used
    /// by the single-folder flows.
    func adoptRoot(_ url: URL) {
        adoptRoots([url])
    }

    /// Adopt a set of root URLs: stops any active watcher, releases the
    /// prior security scope, saves a bookmark for the first URL, and kicks
    /// off `scanMultipleRoots` to scan and render the new tree.
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
        options.maxDepth = ScanDepthStore.limit

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

    /// Scan a single root URL, match each subfolder to a symbol (AI if a
    /// key is configured, otherwise local), and render the previews. Sets
    /// `isScanning` and updates `scanFoundCount` / `scanCurrentPath` as it
    /// progresses; auto-applies any rules that opted in.
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
        options.maxDepth = ScanDepthStore.limit

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
    private static func localGlyph(for name: String, customMappings: [String: String]) -> String? {
        switch IconStyleStore.current {
        case .sfSymbol:
            let match = SymbolMapper.symbolWithConfidence(for: name, customMappings: customMappings)
            return match.source == .fallback ? nil : match.symbol
        case .emoji:
            let match = EmojiMapper.emojiWithConfidence(for: name, customMappings: customMappings)
            return match.source == .fallback ? nil : match.emoji
        }
    }

    /// True if the glyph returned by the local matcher is a generic folder
    /// fallback (i.e. not a real match). Used to decide whether to mark the
    /// folder as unassigned.
    private static func isFallbackGlyph(_ glyph: String) -> Bool {
        if glyph.isEmpty { return true }
        if IconStyleStore.current == .sfSymbol, glyph == "folder" || glyph == "folder.fill" {
            return true
        }
        if IconStyleStore.current == .emoji, glyph == "📁" {
            return true
        }
        return false
    }

    /// Constructs a matched `FolderItem` from a resolved glyph. If the glyph
    /// is a generic fallback, the item is returned as unassigned instead.
    private static func makeItem(
        url: URL,
        glyph: String,
        ruleSymbolColor: NSColor?,
        ruleFolderColor: NSColor?,
        source: MatchSource,
        trackAISuggestion: Bool,
        aiSymbol: String?
    ) -> FolderItem {
        // Suppress rule / smart-detection / custom / AI glyphs that collapse
        // back to the generic folder/emoji — treat them as unassigned.
        if isFallbackGlyph(glyph), source != .userEdited {
            let item = FolderItem.unassigned(url: url)
            // Honor rule colors even on unassigned items so the folder still
            // gets the requested tint without a symbol overlay.
            item.folderColor = ruleFolderColor
            item.symbolColor = ruleSymbolColor
            return item
        }
        let item = FolderItem(
            url: url,
            symbolName: glyph,
            symbolColor: ruleSymbolColor,
            folderColor: ruleFolderColor
        )
        item.matchSource = source
        return item
    }

    /// Keeps older rule/custom values and smart-detection results from leaking
    /// SF Symbol names into emoji mode, or emoji glyphs into SF Symbol mode.
    /// Returns nil if the resolved glyph is a generic folder/emoji fallback —
    /// the caller should treat that as "no real match" and leave the folder
    /// unassigned.
    private static func glyphForCurrentStyle(folderName: String, proposedGlyph: String, customMappings: [String: String]) -> String? {
        if isValidAIGlyph(proposedGlyph), !isFallbackGlyph(proposedGlyph) {
            return proposedGlyph
        }
        return localGlyph(for: folderName, customMappings: customMappings)
    }

    /// Maps a `FolderTypeDetector` result to the current icon style. In
    /// SF Symbol mode the detected symbol is returned as-is. In emoji mode
    /// the well-known dev-tool symbols are rewritten to their emoji
    /// equivalents and anything unknown falls back to `localGlyph`.
    private static func smartDetectionGlyph(for detectedSymbol: String, folderName: String, customMappings: [String: String]) -> String? {
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
            return localGlyph(for: folderName, customMappings: customMappings)
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

                // Highest priority: user-defined rules
                if let rule = rulesStore?.firstMatch(for: name),
                   let glyph = Self.glyphForCurrentStyle(folderName: name, proposedGlyph: rule.symbol, customMappings: customMappings) {
                    return Self.makeItem(
                        url: url,
                        glyph: glyph,
                        ruleSymbolColor: rule.symbolColor,
                        ruleFolderColor: rule.folderColor,
                        source: .rule(ruleName: rule.name),
                        trackAISuggestion: false,
                        aiSymbol: nil
                    )
                } else if SmartContentDetectionStore.isEnabled, let detectedSym = FolderTypeDetector.detectType(at: url),
                          let glyph = Self.smartDetectionGlyph(for: detectedSym, folderName: name, customMappings: customMappings) {
                    return Self.makeItem(
                        url: url,
                        glyph: glyph,
                        ruleSymbolColor: nil,
                        ruleFolderColor: nil,
                        source: .smartDetection(type: Self.smartDetectionTypeDescription(for: detectedSym)),
                        trackAISuggestion: false,
                        aiSymbol: nil
                    )
                } else if let customSym = customMappings[name.lowercased()],
                          let glyph = Self.glyphForCurrentStyle(folderName: name, proposedGlyph: customSym, customMappings: customMappings) {
                    return Self.makeItem(
                        url: url,
                        glyph: glyph,
                        ruleSymbolColor: nil,
                        ruleFolderColor: nil,
                        source: .customMapping,
                        trackAISuggestion: false,
                        aiSymbol: nil
                    )
                } else if let matchResult = geminiMatches[name] {
                    // Use Gemini match only when the model is confident AND the
                    // glyph is renderable for the current style. Below 0.7 we
                    // treat the folder as unassigned so the user can pick a
                    // symbol manually instead of getting a generic "folder.fill".
                    if matchResult.confidence >= SymbolSearchEngine.minimumConfidence, Self.isValidAIGlyph(matchResult.symbol) {
                        return Self.makeItem(
                            url: url,
                            glyph: matchResult.symbol,
                            ruleSymbolColor: nil,
                            ruleFolderColor: nil,
                            source: .aiSuggestion(confidence: matchResult.confidence),
                            trackAISuggestion: true,
                            aiSymbol: matchResult.symbol
                        )
                    } else {
                        return FolderItem.unassigned(url: url)
                    }
                } else {
                    // AI didn't return a result for this folder — leave it
                    // unassigned rather than papering over with a fallback.
                    return FolderItem.unassigned(url: url)
                }
            }
            items = newItems

        } catch let error as GeminiService.GeminiError {
            errorInfo = ErrorInfo(
                message: "Gemini AI unavailable: \(error.localizedDescription)",
                suggestion: error.recoverySuggestion ?? "Falling back to local matching.",
                canRetry: error != .missingAPIKey && error != .invalidAPIKeyFormat,
                isWarning: true
            )
            lastError = "Gemini AI unavailable: \(error.localizedDescription). Folders without a confident match will be left unassigned."
            // The batch call failed entirely — fall back to local matching,
            // which will mark unassigned folders as such instead of giving
            // them a generic fallback symbol.
            matchingMode = .local
            await scanWithLocalMatcher(urls: urls, customMappings: customMappings)
        } catch {
            errorInfo = ErrorInfo(
                message: "AI matching failed: \(error.localizedDescription)",
                suggestion: "Falling back to local matching. Folders without a confident match will be left unassigned.",
                canRetry: true,
                isWarning: true
            )
            lastError = "Gemini AI failed: \(error.localizedDescription). Folders without a confident match will be left unassigned."
            matchingMode = .local
            await scanWithLocalMatcher(urls: urls, customMappings: customMappings)
        }
    }

    private func scanWithLocalMatcher(urls: [URL], customMappings: [String: String]) async {
        let newItems: [FolderItem] = urls.map { u in
            let name = u.lastPathComponent

            // Highest priority: user-defined rules
            if let rule = rulesStore?.firstMatch(for: name),
               let glyph = Self.glyphForCurrentStyle(folderName: name, proposedGlyph: rule.symbol, customMappings: customMappings) {
                return Self.makeItem(
                    url: u,
                    glyph: glyph,
                    ruleSymbolColor: rule.symbolColor,
                    ruleFolderColor: rule.folderColor,
                    source: .rule(ruleName: rule.name),
                    trackAISuggestion: false,
                    aiSymbol: nil
                )
            } else if SmartContentDetectionStore.isEnabled, let detectedSym = FolderTypeDetector.detectType(at: u),
                      let glyph = Self.smartDetectionGlyph(for: detectedSym, folderName: name, customMappings: customMappings) {
                return Self.makeItem(
                    url: u,
                    glyph: glyph,
                    ruleSymbolColor: nil,
                    ruleFolderColor: nil,
                    source: .smartDetection(type: Self.smartDetectionTypeDescription(for: detectedSym)),
                    trackAISuggestion: false,
                    aiSymbol: nil
                )
            } else if let customSym = customMappings[name.lowercased()],
                      let glyph = Self.glyphForCurrentStyle(folderName: name, proposedGlyph: customSym, customMappings: customMappings) {
                return Self.makeItem(
                    url: u,
                    glyph: glyph,
                    ruleSymbolColor: nil,
                    ruleFolderColor: nil,
                    source: .customMapping,
                    trackAISuggestion: false,
                    aiSymbol: nil
                )
            } else if let glyph = Self.localGlyph(for: name, customMappings: customMappings) {
                return Self.makeItem(
                    url: u,
                    glyph: glyph,
                    ruleSymbolColor: nil,
                    ruleFolderColor: nil,
                    source: .localDictionary,
                    trackAISuggestion: false,
                    aiSymbol: nil
                )
            } else {
                return FolderItem.unassigned(url: u)
            }
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
            let isUnassigned: Bool
        }
        let pairs = items.map { item in
            RenderPair(
                id: item.id,
                symbol: item.symbolName,
                // Unassigned items get the default symbol tint only when the
                // user has explicitly set a custom color; otherwise we leave
                // the symbol color nil so the renderer keeps the plain folder.
                color: item.symbolColor ?? defaultColor,
                folderTint: item.folderColor,
                path: item.url.path,
                opacity: item.symbolOpacity,
                scale: item.symbolScale,
                offsetY: item.symbolOffsetY,
                gradientEnd: item.symbolGradientEnd,
                customImage: item.customImage,
                isUnassigned: item.isUnassigned
            )
        }
        let rendered = await Task.detached(priority: .userInitiated) {
            pairs.map { p -> (UUID, NSImage?, NSImage) in
                let preview: NSImage?
                if p.isUnassigned {
                    // Unassigned → no symbol, no tint, no folder recolor. The
                    // row just shows the plain system folder.
                    preview = IconRenderer.makeIcon(
                        symbolNames: [],
                        tint: p.color,
                        folderTint: nil,
                        opacity: RendererSentinel.opacity,
                        scale: RendererSentinel.scale,
                        offsetY: RendererSentinel.offsetY,
                        gradientEnd: nil,
                        customImage: nil
                    )
                } else {
                    preview = IconRenderer.makeIcon(
                        symbolNames: [p.symbol],
                        tint: p.color,
                        folderTint: p.folderTint,
                        opacity: p.opacity,
                        scale: p.scale,
                        offsetY: p.offsetY,
                        gradientEnd: p.gradientEnd,
                        customImage: p.customImage
                    )
                }
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

    /// Re-attempts matching for a single failed/unmapped item using the current
    /// matching mode (AI or local). Used by the row-level retry button.
    func retryItem(_ item: FolderItem) {
        let name = item.url.lastPathComponent
        let custom = mappings.dictionary
        let url = item.url

        Task { @MainActor in
            var newSymbol: String?
            var newSource: MatchSource = .localDictionary
            var errorMessage: String?
            var ruleSymbolColor: NSColor?
            var ruleFolderColor: NSColor?

            // Mirror the scan-time priority: rules → smart detection → custom mappings → AI/local.
            if let rule = rulesStore?.firstMatch(for: name) {
                newSymbol = Self.glyphForCurrentStyle(folderName: name, proposedGlyph: rule.symbol, customMappings: custom)
                newSource = .rule(ruleName: rule.name)
                ruleSymbolColor = rule.symbolColor
                ruleFolderColor = rule.folderColor
            } else if SmartContentDetectionStore.isEnabled, let detectedSym = FolderTypeDetector.detectType(at: url) {
                newSymbol = Self.smartDetectionGlyph(for: detectedSym, folderName: name, customMappings: custom)
                newSource = .smartDetection(type: Self.smartDetectionTypeDescription(for: detectedSym))
            } else if let customSym = custom[name.lowercased()] {
                newSymbol = Self.glyphForCurrentStyle(folderName: name, proposedGlyph: customSym, customMappings: custom)
                newSource = .customMapping
            } else if matchingMode == .ai, let apiKey = SettingsViewModel.getAPIKeyIfEnabled() {
                do {
                    let learningExamples = learningStore?.getAllExamples(limit: 20)
                    let matches = try await GeminiService.matchFolders(
                        [name],
                        apiKey: apiKey,
                        style: IconStyleStore.current,
                        learningExamples: learningExamples,
                        contentAnalysis: nil
                    )
                    if let match = matches[name], match.confidence >= SymbolSearchEngine.minimumConfidence, Self.isValidAIGlyph(match.symbol) {
                        newSymbol = match.symbol
                        newSource = .aiSuggestion(confidence: match.confidence)
                    } else {
                        newSymbol = Self.localGlyph(for: name, customMappings: custom)
                        newSource = .localDictionary
                    }
                } catch {
                    errorMessage = "Retry failed: \(error.localizedDescription)"
                }
            } else {
                newSymbol = Self.localGlyph(for: name, customMappings: custom)
                newSource = .localDictionary
            }

            // If retry produced a real glyph, adopt it. Otherwise mark the
            // item as unassigned so the row makes the state obvious.
            if let sym = newSymbol, !Self.isFallbackGlyph(sym) {
                item.symbolNames = [sym]
                item.matchSource = newSource
                item.status = .pending
                rerenderPreservingMatchSource(item)
            } else {
                let rebuilt = FolderItem.unassigned(url: url)
                rebuilt.folderColor = ruleFolderColor ?? item.folderColor
                rebuilt.symbolColor = ruleSymbolColor ?? item.symbolColor
                rebuilt.status = item.status
                item.symbolNames = rebuilt.symbolNames
                item.matchSource = .unassigned
                item.status = .pending
                rerenderPreservingMatchSource(item)
            }
            if let msg = errorMessage {
                item.status = .failed(msg)
            }
        }
    }

    /// Like `rerender` but doesn't flip matchSource to .userEdited — used after
    /// programmatic re-matching where the source should reflect the matcher used.
    private func rerenderPreservingMatchSource(_ item: FolderItem) {
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

    /// Re-resolve a single item's symbol from the mapping rules and re-render.
    /// Use after custom mappings change.
    func refreshSymbol(for item: FolderItem) {
        let custom = mappings.dictionary
        let name = item.url.lastPathComponent
        if let glyph = Self.localGlyph(for: name, customMappings: custom) {
            item.symbolNames = [glyph]
            rerender(item)
        } else {
            // No real match → mark unassigned instead of forcing a fallback.
            item.symbolNames = []
            item.matchSource = .unassigned
            rerender(item)
        }
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

        // Mark as user-edited since rerender is called after manual edits —
        // unless the user has explicitly cleared the symbol, in which case
        // we drop the row back to the unassigned state.
        if item.symbolNames.isEmpty {
            item.matchSource = .unassigned
        } else if item.matchSource != .userEdited {
            item.matchSource = .userEdited
        }
        let syms = item.symbolNames
        let isUnassigned = item.isUnassigned
        let color = item.symbolColor ?? ColorPreferences.getDefaultColor()
        let folderTint = item.folderColor
        let opacity = item.symbolOpacity
        let scale = item.symbolScale
        let offsetY = item.symbolOffsetY
        let gradientEnd = item.symbolGradientEnd
        let customImage = item.customImage
        Task.detached(priority: .userInitiated) {
            let img: NSImage?
            if isUnassigned {
                img = IconRenderer.makeIcon(
                    symbolNames: [],
                    tint: color,
                    folderTint: nil,
                    opacity: RendererSentinel.opacity,
                    scale: RendererSentinel.scale,
                    offsetY: RendererSentinel.offsetY,
                    gradientEnd: nil,
                    customImage: nil
                )
            } else {
                img = IconRenderer.makeIcon(
                    symbolNames: syms,
                    tint: color,
                    folderTint: folderTint,
                    opacity: opacity,
                    scale: scale,
                    offsetY: offsetY,
                    gradientEnd: gradientEnd,
                    customImage: customImage
                )
            }
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
            // Unassigned items stay plain — no folder recolor, no symbol tint.
            if item.isUnassigned { continue }
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

    /// Render `item` to a real folder icon and write it to disk via
    /// `IconApplier`. Unassigned items are skipped (status set back to
    /// `.pending`). On success the action is recorded for undo and the
    /// item is briefly flagged in `recentlyAppliedItemIDs` for the row
    /// success animation.
    func apply(_ item: FolderItem) {
        // Unassigned items have no symbol to apply. Leave the folder alone
        // (no custom icon gets written) and surface the state in the status
        // badge so the user knows the click was a no-op.
        if item.isUnassigned || item.symbolNames.isEmpty {
            item.status = .pending
            return
        }

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

    /// Apply every item in `batchTargets` (filtered if the user has
    /// narrowed the list, otherwise all items). Skips unassigned items and
    /// surfaces SIP-protected folders up front. Drives progress, ETA, and
    /// the post-batch `BatchSummary`.
    func applyAll() {
        // Drop unassigned items up front — they have no symbol, so applying
        // would write a plain folder (or nothing) and there's no point
        // running them through the per-item render path.
        let original = batchTargets
        let skipped = original.filter { $0.isUnassigned || $0.symbolNames.isEmpty }.count
        let snapshot = original.filter { !$0.isUnassigned && !$0.symbolNames.isEmpty }
        guard !snapshot.isEmpty else {
            if skipped > 0 {
                showToast(
                    "Skipping \(skipped) folder(s) with no symbol match",
                    icon: "questionmark.circle",
                    type: .info
                )
            }
            return
        }
        if skipped > 0 {
            showToast(
                "Skipping \(skipped) folder(s) with no symbol match",
                icon: "questionmark.circle",
                type: .info
            )
        }

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

    /// Restore every item in `batchTargets` back to the system default
    /// folder icon. Skips SIP-protected folders; surfaces a `BatchSummary`
    /// when the batch finishes. Cancellable via `cancelBatch`.
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

    /// Count of items whose folders already have a custom icon that applying would overwrite.
    var conflictCount: Int {
        foldersWithExistingIcons.count
    }

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

        var ruleSymbolColor: NSColor?
        var ruleFolderColor: NSColor?
        var shouldAutoApply = false

        // Check if any auto-apply rule matches
        let item: FolderItem
        if let rule = rulesStore?.firstMatch(for: name), rule.autoApply,
           let glyph = Self.glyphForCurrentStyle(folderName: name, proposedGlyph: rule.symbol, customMappings: custom) {
            item = Self.makeItem(
                url: url,
                glyph: glyph,
                ruleSymbolColor: rule.symbolColor,
                ruleFolderColor: rule.folderColor,
                source: .rule(ruleName: rule.name),
                trackAISuggestion: false,
                aiSymbol: nil
            )
            ruleSymbolColor = rule.symbolColor
            ruleFolderColor = rule.folderColor
            shouldAutoApply = true
        } else if SmartContentDetectionStore.isEnabled, let detectedSym = FolderTypeDetector.detectType(at: url),
                  let glyph = Self.smartDetectionGlyph(for: detectedSym, folderName: name, customMappings: custom) {
            item = Self.makeItem(
                url: url,
                glyph: glyph,
                ruleSymbolColor: nil,
                ruleFolderColor: nil,
                source: .smartDetection(type: Self.smartDetectionTypeDescription(for: detectedSym)),
                trackAISuggestion: false,
                aiSymbol: nil
            )
        } else if let customSym = custom[name.lowercased()],
                  let glyph = Self.glyphForCurrentStyle(folderName: name, proposedGlyph: customSym, customMappings: custom) {
            item = Self.makeItem(
                url: url,
                glyph: glyph,
                ruleSymbolColor: nil,
                ruleFolderColor: nil,
                source: .customMapping,
                trackAISuggestion: false,
                aiSymbol: nil
            )
        } else if let glyph = Self.localGlyph(for: name, customMappings: custom) {
            item = Self.makeItem(
                url: url,
                glyph: glyph,
                ruleSymbolColor: nil,
                ruleFolderColor: nil,
                source: .localDictionary,
                trackAISuggestion: false,
                aiSymbol: nil
            )
        } else {
            // No real match for a folder the watcher just spotted — leave it
            // unassigned so the user can resolve it in-app. We never want to
            // stamp a generic folder.fill on a brand new folder.
            item = FolderItem.unassigned(url: url)
        }

        // Assign color if enabled — unassigned items stay plain (no folder recolor).
        if AutoColorStore.isEnabled, !item.isUnassigned {
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

        if shouldAutoApply {
            apply(item)
            showToast("Auto-applied icon to '\(name)'", icon: "folder.badge.plus", type: .success)
        }
    }
}
