//
//  StoreIntegrationTests.swift
//  IconicTests
//
//  Integration tests for persistent stores: PreferencesStore helpers,
//  RulesStore, PresetsStore, and BackupStore.
//

import XCTest
import AppKit
@testable import Iconic

@MainActor
final class StoreIntegrationTests: XCTestCase {

    private let prefsKeys = [
        "iconic.iconStyle.v1",
        "iconic.smartContentDetection.enabled",
        "iconic.autoColor.enabled",
        "iconic.excludePatterns.v1",
        "iconic.excludePatterns.enabled",
        "iconic.scanDepthLimit"
    ]
    private let rulesKey = "iconic.rules.v1"
    private let presetsKey = "iconic.presets.v1"
    private let backupsKey = "iconic.backups.v1"

    override func setUp() {
        super.setUp()
        for key in prefsKeys { UserDefaults.standard.removeObject(forKey: key) }
        UserDefaults.standard.removeObject(forKey: rulesKey)
        UserDefaults.standard.removeObject(forKey: presetsKey)
        UserDefaults.standard.removeObject(forKey: backupsKey)
    }

    override func tearDown() {
        for key in prefsKeys { UserDefaults.standard.removeObject(forKey: key) }
        UserDefaults.standard.removeObject(forKey: rulesKey)
        UserDefaults.standard.removeObject(forKey: presetsKey)
        UserDefaults.standard.removeObject(forKey: backupsKey)
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeFolderItem(name: String) -> FolderItem {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(name)
        return FolderItem(url: url, symbolName: "folder", symbolColor: .systemBlue)
    }

    // ============================================================
    // MARK: - 1. PreferencesStore (static helpers in PreferencesStore.swift)
    // ============================================================

    // MARK: ExcludePatternsStore

    func testExcludePatterns_defaultsContainGit() {
        let defaults = ExcludePatternsStore.defaultPatterns
        XCTAssertTrue(defaults.contains(".git"))
    }

    func testExcludePatterns_defaultsContainNodeModules() {
        XCTAssertTrue(ExcludePatternsStore.defaultPatterns.contains("node_modules"))
    }

    func testExcludePatterns_addAndRemove() {
        let before = ExcludePatternsStore.patterns
        ExcludePatternsStore.add("test_pattern_xyz")
        XCTAssertTrue(ExcludePatternsStore.patterns.contains("test_pattern_xyz"))
        ExcludePatternsStore.remove("test_pattern_xyz")
        XCTAssertFalse(ExcludePatternsStore.patterns.contains("test_pattern_xyz"))
        XCTAssertEqual(ExcludePatternsStore.patterns, before)
    }

    func testExcludePatterns_resetToDefaults() {
        ExcludePatternsStore.add("zzz_extra_pattern")
        ExcludePatternsStore.resetToDefaults()
        XCTAssertEqual(ExcludePatternsStore.patterns, ExcludePatternsStore.defaultPatterns)
    }

    func testExcludePatterns_matchesExact() {
        XCTAssertTrue(ExcludePatternsStore.matches("node_modules", patterns: ["node_modules"]))
    }

    func testExcludePatterns_matchesWildcard() {
        XCTAssertTrue(ExcludePatternsStore.matches("test_cache", patterns: ["test_*"]))
    }

    func testExcludePatterns_noMatch() {
        XCTAssertFalse(ExcludePatternsStore.matches("MyProject", patterns: [".git", "node_modules"]))
    }

    // MARK: ScanDepthStore

    func testScanDepth_default() {
        XCTAssertEqual(ScanDepthStore.limit, ScanDepthStore.defaultLimit)
    }

    func testScanDepth_setAndGet() {
        ScanDepthStore.limit = 5
        XCTAssertEqual(ScanDepthStore.limit, 5)
    }

    func testScanDepth_clampsBelowMinimum() {
        ScanDepthStore.limit = -10
        XCTAssertEqual(ScanDepthStore.limit, ScanDepthStore.minLimit)
    }

    func testScanDepth_clampsAboveMaximum() {
        ScanDepthStore.limit = 100
        XCTAssertEqual(ScanDepthStore.limit, ScanDepthStore.maxLimit)
    }

    // MARK: IconStyleStore

    func testIconStyle_defaultIsSFSymbol() {
        XCTAssertEqual(IconStyleStore.current, .sfSymbol)
    }

    // MARK: SmartContentDetectionStore

    func testSmartContentDetection_defaultIsFalse() {
        XCTAssertFalse(SmartContentDetectionStore.isEnabled)
    }

    func testSmartContentDetection_setTrue() {
        SmartContentDetectionStore.isEnabled = true
        XCTAssertTrue(SmartContentDetectionStore.isEnabled)
    }

    // MARK: AutoColorStore

    func testAutoColor_defaultIsTrue() {
        XCTAssertTrue(AutoColorStore.isEnabled)
    }

    func testAutoColor_setFalse() {
        AutoColorStore.isEnabled = false
        XCTAssertFalse(AutoColorStore.isEnabled)
    }

    // ============================================================
    // MARK: - 2. RulesStore
    // ============================================================

    func testRulesStore_initiallyEmpty() async {
        let store = RulesStore()
        XCTAssertTrue(store.rules.isEmpty)
    }

    func testRulesStore_addRule() async {
        let store = RulesStore()
        var rule = IconRule(name: "TestRule", pattern: "*.swift", matchType: .glob, symbol: "doc")
        rule.enabled = true
        store.add(rule)
        XCTAssertEqual(store.rules.count, 1)
        XCTAssertEqual(store.rules.first?.name, "TestRule")
    }

    func testRulesStore_addMultipleRules() async {
        let store = RulesStore()
        store.add(IconRule(name: "R1", pattern: "a", matchType: .contains, symbol: "a.circle"))
        store.add(IconRule(name: "R2", pattern: "b", matchType: .contains, symbol: "b.circle"))
        store.add(IconRule(name: "R3", pattern: "c", matchType: .contains, symbol: "c.circle"))
        XCTAssertEqual(store.rules.count, 3)
    }

    func testRulesStore_toggleEnabled() async {
        let store = RulesStore()
        var rule = IconRule(name: "ToggleMe", pattern: "x", matchType: .exact, symbol: "xmark")
        rule.enabled = true
        store.add(rule)
        var updated = store.rules[0]
        updated.enabled = false
        store.update(updated)
        XCTAssertFalse(store.rules[0].enabled)
    }

    func testRulesStore_deleteRule() async {
        let store = RulesStore()
        let rule = IconRule(name: "DeleteMe", pattern: "z", matchType: .exact, symbol: "trash")
        store.add(rule)
        let id = store.rules[0].id
        store.remove(id: id)
        XCTAssertTrue(store.rules.isEmpty)
    }

    func testRulesStore_updateRule() async {
        let store = RulesStore()
        var rule = IconRule(name: "Original", pattern: "o", matchType: .exact, symbol: "circle")
        store.add(rule)
        var updated = store.rules[0]
        updated.name = "Updated"
        updated.symbol = "star"
        store.update(updated)
        XCTAssertEqual(store.rules[0].name, "Updated")
        XCTAssertEqual(store.rules[0].symbol, "star")
    }

    func testRulesStore_moveRule() async {
        let store = RulesStore()
        store.add(IconRule(name: "First", pattern: "1", matchType: .exact, symbol: "1.circle"))
        store.add(IconRule(name: "Second", pattern: "2", matchType: .exact, symbol: "2.circle"))
        store.move(from: IndexSet(integer: 0), to: 2)
        XCTAssertEqual(store.rules[0].name, "Second")
        XCTAssertEqual(store.rules[1].name, "First")
    }

    func testRulesStore_firstMatch() async {
        let store = RulesStore()
        store.add(IconRule(name: "MusicRule", pattern: "Music", matchType: .exact, symbol: "music.note"))
        store.add(IconRule(name: "GenericRule", pattern: "", matchType: .contains, symbol: "folder"))
        let match = store.firstMatch(for: "Music")
        XCTAssertNotNil(match)
        XCTAssertEqual(match?.symbol, "music.note")
    }

    func testRulesStore_firstMatchSkipsDisabled() async {
        let store = RulesStore()
        var rule = IconRule(name: "Disabled", pattern: "Music", matchType: .exact, symbol: "music.note")
        rule.enabled = false
        store.add(rule)
        XCTAssertNil(store.firstMatch(for: "Music"))
    }

    func testRulesStore_globPatternMatch() async {
        let store = RulesStore()
        store.add(IconRule(name: "SwiftRule", pattern: "*.swift", matchType: .glob, symbol: "swift"))
        XCTAssertNotNil(store.firstMatch(for: "main.swift"))
    }

    func testRulesStore_regexPatternMatch() async {
        let store = RulesStore()
        store.add(IconRule(name: "YearRule", pattern: "^\\d{4}$", matchType: .regex, symbol: "calendar"))
        XCTAssertNotNil(store.firstMatch(for: "2024"))
        XCTAssertNil(store.firstMatch(for: "abc"))
    }

    func testRulesStore_priorityOrdering() async {
        let store = RulesStore()
        var lowPriority = IconRule(name: "Low", pattern: "Music", matchType: .exact, symbol: "music.note")
        lowPriority.priority = 1
        var highPriority = IconRule(name: "High", pattern: "Music", matchType: .exact, symbol: "star.fill")
        highPriority.priority = 10
        store.add(lowPriority)
        store.add(highPriority)
        let match = store.firstMatch(for: "Music")
        XCTAssertEqual(match?.symbol, "star.fill")
    }

    // ============================================================
    // MARK: - 3. PresetsStore
    // ============================================================

    func testPresetsStore_initiallyEmpty() async {
        let store = PresetsStore()
        XCTAssertTrue(store.presets.isEmpty)
    }

    func testPresetsStore_addPreset() async throws {
        let store = PresetsStore()
        try store.saveCurrentAsPreset(
            name: "MyPreset",
            mappings: [CustomMapping(keyword: "test", symbol: "star")],
            aiEnabled: false
        )
        XCTAssertEqual(store.presets.count, 1)
        XCTAssertEqual(store.presets.first?.name, "MyPreset")
    }

    func testPresetsStore_addPresetEmptyNameThrows() async {
        let store = PresetsStore()
        XCTAssertThrowsError(
            try store.saveCurrentAsPreset(name: "", mappings: [], aiEnabled: false)
        ) { error in
            XCTAssertTrue(error is PresetError)
        }
    }

    func testPresetsStore_addPresetDuplicateNameThrows() async {
        let store = PresetsStore()
        try? store.saveCurrentAsPreset(name: "Dupe", mappings: [], aiEnabled: false)
        XCTAssertThrowsError(
            try store.saveCurrentAsPreset(name: "Dupe", mappings: [], aiEnabled: false)
        ) { error in
            XCTAssertEqual(error as? PresetError, .duplicateName)
        }
    }

    func testPresetsStore_deletePreset() async {
        let store = PresetsStore()
        try? store.saveCurrentAsPreset(name: "ToDelete", mappings: [], aiEnabled: false)
        let id = store.presets[0].id
        store.delete(id: id)
        XCTAssertTrue(store.presets.isEmpty)
    }

    func testPresetsStore_renamePreset() async throws {
        let store = PresetsStore()
        try store.saveCurrentAsPreset(name: "OldName", mappings: [], aiEnabled: false)
        let id = store.presets[0].id
        try store.rename(id: id, newName: "NewName")
        XCTAssertEqual(store.presets[0].name, "NewName")
    }

    func testPresetsStore_renameToEmptyThrows() async throws {
        let store = PresetsStore()
        try store.saveCurrentAsPreset(name: "SomeName", mappings: [], aiEnabled: false)
        let id = store.presets[0].id
        XCTAssertThrowsError(try store.rename(id: id, newName: "")) { error in
            XCTAssertEqual(error as? PresetError, .emptyName)
        }
    }

    func testPresetsStore_loadPresetConfiguration() async {
        let store = PresetsStore()
        let mappings = [
            CustomMapping(keyword: "design", symbol: "paintpalette"),
            CustomMapping(keyword: "code", symbol: "chevron.left.forwardslash.chevron.right")
        ]
        try? store.saveCurrentAsPreset(name: "ConfigTest", mappings: mappings, aiEnabled: true)
        let config = store.loadPreset(store.presets[0])
        XCTAssertEqual(config.customMappings.count, 2)
        XCTAssertTrue(config.aiEnabled)
    }

    func testPresetsStore_saveLoadRoundTrip() async throws {
        let store = PresetsStore()
        try store.saveCurrentAsPreset(
            name: "RoundTrip",
            mappings: [CustomMapping(keyword: "k", symbol: "s")],
            aiEnabled: true
        )
        // Re-create store to verify UserDefaults persistence
        let store2 = PresetsStore()
        XCTAssertEqual(store2.presets.count, 1)
        XCTAssertEqual(store2.presets[0].name, "RoundTrip")
        XCTAssertTrue(store2.presets[0].aiEnabled)
    }

    func testPresetsStore_exportAndImport() async throws {
        let store = PresetsStore()
        try store.saveCurrentAsPreset(
            name: "ExportMe",
            mappings: [CustomMapping(keyword: "x", symbol: "y")],
            aiEnabled: false
        )
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("preset_export.json")
        try store.exportPreset(store.presets[0], to: fileURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))

        // Clear and re-import
        store.delete(id: store.presets[0].id)
        XCTAssertTrue(store.presets.isEmpty)
        try store.importPreset(from: fileURL)
        XCTAssertEqual(store.presets.count, 1)
        XCTAssertEqual(store.presets[0].name, "ExportMe")
        try? FileManager.default.removeItem(at: fileURL)
    }

    func testPresetsStore_importHandlesDuplicateName() async throws {
        let store = PresetsStore()
        try store.saveCurrentAsPreset(
            name: "Existing",
            mappings: [],
            aiEnabled: false
        )
        // Create file with same name
        let preset = Preset(name: "Existing", customMappings: [], aiEnabled: false)
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("preset_dupe.json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(preset)
        try data.write(to: fileURL)

        try store.importPreset(from: fileURL)
        XCTAssertEqual(store.presets.count, 2)
        XCTAssertTrue(store.presets[1].name.hasPrefix("Existing"))
        try? FileManager.default.removeItem(at: fileURL)
    }

    // ============================================================
    // MARK: - 4. BackupStore
    // ============================================================

    func testBackupStore_initiallyEmpty() async {
        let store = BackupStore()
        XCTAssertTrue(store.snapshots.isEmpty)
    }

    func testBackupStore_captureSnapshot() async {
        let store = BackupStore()
        let item = makeFolderItem(name: "TestFolder")
        let snapshot = store.capture(name: "TestBackup", items: [item], rootURL: nil)
        XCTAssertEqual(store.snapshots.count, 1)
        XCTAssertEqual(snapshot.name, "TestBackup")
        XCTAssertEqual(snapshot.entries.count, 1)
    }

    func testBackupStore_captureMultipleItems() async {
        let store = BackupStore()
        let items = (1...5).map { makeFolderItem(name: "Folder\($0)") }
        let snapshot = store.capture(name: "MultiBackup", items: items, rootURL: nil)
        XCTAssertEqual(snapshot.entries.count, 5)
    }

    func testBackupStore_listSnapshots() async {
        let store = BackupStore()
        store.capture(name: "Backup1", items: [makeFolderItem(name: "A")], rootURL: nil)
        store.capture(name: "Backup2", items: [makeFolderItem(name: "B")], rootURL: nil)
        XCTAssertEqual(store.snapshots.count, 2)
        XCTAssertEqual(store.snapshots[0].name, "Backup2")
        XCTAssertEqual(store.snapshots[1].name, "Backup1")
    }

    func testBackupStore_deleteSnapshot() async {
        let store = BackupStore()
        let snap = store.capture(name: "ToDelete", items: [makeFolderItem(name: "X")], rootURL: nil)
        store.remove(id: snap.id)
        XCTAssertTrue(store.snapshots.isEmpty)
    }

    func testBackupStore_deleteByOffset() async {
        let store = BackupStore()
        _ = store.capture(name: "A", items: [makeFolderItem(name: "A")], rootURL: nil)
        _ = store.capture(name: "B", items: [makeFolderItem(name: "B")], rootURL: nil)
        store.remove(at: IndexSet(integer: 0))
        XCTAssertEqual(store.snapshots.count, 1)
        XCTAssertEqual(store.snapshots[0].name, "A")
    }

    func testBackupStore_restoreSnapshot() async {
        let store = BackupStore()
        let original = makeFolderItem(name: "RestoreTarget")
        original.symbolOpacity = 0.5
        original.symbolScale = 0.8

        let snapshot = store.capture(name: "RestoreTest", items: [original], rootURL: nil)

        // Modify original
        original.symbolOpacity = 1.0
        original.symbolScale = 1.0

        // Create fresh item with same path and restore
        let fresh = makeFolderItem(name: "RestoreTarget")
        fresh.symbolOpacity = 1.0
        fresh.symbolScale = 1.0

        store.restore(snapshot, into: [fresh])
        XCTAssertEqual(fresh.symbolOpacity, 0.5, accuracy: 0.001)
        XCTAssertEqual(fresh.symbolScale, 0.8, accuracy: 0.001)
    }

    func testBackupStore_restoreSkipsUnmatchedItems() async {
        let store = BackupStore()
        let original = makeFolderItem(name: "Matched")
        original.symbolOpacity = 0.3
        let snapshot = store.capture(name: "Partial", items: [original], rootURL: nil)

        let unmatched = makeFolderItem(name: "Unmatched")
        unmatched.symbolOpacity = 1.0

        store.restore(snapshot, into: [unmatched])
        XCTAssertEqual(unmatched.symbolOpacity, 1.0, "Unmatched item should be untouched")
    }

    func testBackupStore_persistenceRoundTrip() async {
        let store = BackupStore()
        _ = store.capture(name: "Persist", items: [makeFolderItem(name: "P")], rootURL: nil)
        let store2 = BackupStore()
        XCTAssertEqual(store2.snapshots.count, 1)
        XCTAssertEqual(store2.snapshots[0].name, "Persist")
    }

    func testBackupStore_restorePreservesColor() async {
        let store = BackupStore()
        let item = makeFolderItem(name: "ColorItem")
        item.symbolColor = .systemRed
        item.folderColor = .systemGreen

        let snapshot = store.capture(name: "ColorTest", items: [item], rootURL: nil)

        let fresh = makeFolderItem(name: "ColorItem")
        fresh.symbolColor = .blue
        fresh.folderColor = .yellow

        store.restore(snapshot, into: [fresh])
        XCTAssertEqual(fresh.symbolColor?.hexString, NSColor.systemRed.hexString)
        XCTAssertEqual(fresh.folderColor?.hexString, NSColor.systemGreen.hexString)
    }
}
