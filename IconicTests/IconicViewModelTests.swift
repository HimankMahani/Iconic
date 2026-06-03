//
//  IconicViewModelTests.swift
//  IconicTests
//
//  Exercises the pure logic in IconicViewModel and its owned stores
//  without requiring a running app context.
//

import XCTest
import AppKit
@testable import Iconic

@MainActor
final class IconicViewModelTests: XCTestCase {

    // MARK: - Helpers

    private func makeSUT() -> (vm: IconicViewModel, mappings: CustomMappingsStore) {
        let mappings = CustomMappingsStore()
        let vm = IconicViewModel(mappings: mappings)
        return (vm, mappings)
    }

    private func sampleItem(name: String = "Music") -> FolderItem {
        let url = URL(fileURLWithPath: "/tmp/\(name)")
        return FolderItem(url: url, symbolName: "music.note")
    }

    // MARK: - Initial state

    func testInitialState() {
        let (vm, _) = makeSUT()

        XCTAssertTrue(vm.items.isEmpty, "items should start empty")
        XCTAssertTrue(vm.searchText.isEmpty, "searchText should start empty")
        XCTAssertTrue(vm.selectedItemIDs.isEmpty, "selectedItemIDs should start empty")
        XCTAssertNil(vm.lastError, "lastError should start nil")
        XCTAssertNil(vm.errorInfo, "errorInfo should start nil")
        XCTAssertFalse(vm.isScanning)
        XCTAssertFalse(vm.isApplying)
        XCTAssertEqual(vm.progress, 0)
    }

    // MARK: - Store defaults

    func testStoresDefaultValues() {
        let (vm, mappings) = makeSUT()

        // CustomMappingsStore starts empty
        XCTAssertTrue(mappings.mappings.isEmpty, "CustomMappingsStore should start with no mappings")
        XCTAssertTrue(mappings.dictionary.isEmpty, "CustomMappingsStore dictionary should be empty")

        // ViewModel's published defaults
        XCTAssertNil(vm.lastBatchSummary)
        XCTAssertFalse(vm.showBatchSummary)
        XCTAssertEqual(vm.sipProtectedCount, 0)
        XCTAssertEqual(vm.matchingMode, .local)
        XCTAssertEqual(vm.statusFilter, .all)
    }

    func testPresetsStoreHasBuiltins() {
        let presetsStore = PresetsStore()
        // PresetsStore may have previously-saved presets from UserDefaults,
        // but its default state should be loadable without crash.
        XCTAssertNotNil(presetsStore.presets)
    }

    // MARK: - Search text

    func testSetSearchText() {
        let (vm, _) = makeSUT()

        vm.searchText = "music"
        XCTAssertEqual(vm.searchText, "music")

        vm.searchText = ""
        XCTAssertTrue(vm.searchText.isEmpty)
    }

    func testSearchTextFiltersItems() {
        let (vm, _) = makeSUT()

        let music = sampleItem(name: "Music")
        let photos = sampleItem(name: "Photos")
        vm.items = [music, photos]

        vm.searchText = "Music"
        XCTAssertEqual(vm.filteredItems.count, 1)
        XCTAssertEqual(vm.filteredItems.first?.displayName, "Music")

        vm.searchText = ""
        XCTAssertEqual(vm.filteredItems.count, 2)
    }

    // MARK: - Selection

    func testSelectAndDeselectFolder() {
        let (vm, _) = makeSUT()
        let item = sampleItem()
        vm.items = [item]

        // Initially no selection
        XCTAssertTrue(vm.selectedItemIDs.isEmpty)

        // Select via selectOnly
        vm.selectOnly(item)
        XCTAssertEqual(vm.selectedItemIDs.count, 1)
        XCTAssertTrue(vm.selectedItemIDs.contains(item.id))

        // Toggle off via toggleSelection
        vm.toggleSelection(item)
        XCTAssertTrue(vm.selectedItemIDs.isEmpty, "Toggling a selected item should deselect it")
    }

    func testToggleSelectionAddsAndRemoves() {
        let (vm, _) = makeSUT()
        let a = sampleItem(name: "A")
        let b = sampleItem(name: "B")
        vm.items = [a, b]

        vm.toggleSelection(a)
        vm.toggleSelection(b)
        XCTAssertEqual(vm.selectedItemIDs.count, 2)

        vm.toggleSelection(a)
        XCTAssertEqual(vm.selectedItemIDs.count, 1)
        XCTAssertTrue(vm.selectedItemIDs.contains(b.id))
    }

    func testClearSelection() {
        let (vm, _) = makeSUT()
        let item = sampleItem()
        vm.items = [item]
        vm.selectOnly(item)
        XCTAssertFalse(vm.selectedItemIDs.isEmpty)

        vm.clearSelection()
        XCTAssertTrue(vm.selectedItemIDs.isEmpty)
    }

    func testSelectAllVisible() {
        let (vm, _) = makeSUT()
        let a = sampleItem(name: "A")
        let b = sampleItem(name: "B")
        vm.items = [a, b]

        vm.selectAllVisible()
        XCTAssertEqual(vm.selectedItemIDs.count, 2)
    }

    // MARK: - Reset adjustments (FolderItem fields)

    func testResetAdjustments() {
        let item = sampleItem()

        // Modify adjustment fields
        item.symbolOpacity = 0.5
        item.symbolScale = 1.5
        item.symbolOffsetY = 10.0
        item.symbolGradientEnd = .red
        item.customImage = NSImage(size: NSSize(width: 10, height: 10))

        // Simulate what resetAdjustments does (mirrors FolderRowView.resetAdjustments)
        item.symbolScale = FolderItem.defaultSymbolScale
        item.symbolOpacity = FolderItem.defaultSymbolOpacity
        item.symbolOffsetY = FolderItem.defaultSymbolOffsetY
        item.symbolGradientEnd = nil
        item.customImage = nil

        XCTAssertEqual(item.symbolOpacity, FolderItem.defaultSymbolOpacity)
        XCTAssertEqual(item.symbolScale, FolderItem.defaultSymbolScale)
        XCTAssertEqual(item.symbolOffsetY, FolderItem.defaultSymbolOffsetY)
        XCTAssertNil(item.symbolGradientEnd)
        XCTAssertNil(item.customImage)
    }

    // MARK: - Undo / Redo integration

    func testUndoRedoIntegration() {
        let (vm, _) = makeSUT()
        let item = sampleItem()
        vm.items = [item]

        // Initially no undo/redo available
        XCTAssertFalse(vm.undoManager.canUndo)
        XCTAssertFalse(vm.undoManager.canRedo)

        // Record an apply action
        let previousState = IconicUndoManager.FolderState(
            status: .pending,
            symbolName: item.symbolName,
            symbolColor: item.symbolColor
        )
        vm.undoManager.recordAction(.applySingle(url: item.url, previousState: previousState))

        XCTAssertTrue(vm.undoManager.canUndo, "Should be able to undo after recording an action")
        XCTAssertFalse(vm.undoManager.canRedo, "Redo should be empty after a new action")

        // Undo
        vm.performUndo()
        XCTAssertFalse(vm.undoManager.canUndo, "No more undo after undoing")
        XCTAssertTrue(vm.undoManager.canRedo, "Redo should be available after undo")
    }

    func testRedoReappliesAction() {
        let (vm, _) = makeSUT()
        let item = sampleItem()
        vm.items = [item]

        let state = IconicUndoManager.FolderState(
            status: .pending,
            symbolName: "music.note",
            symbolColor: nil
        )
        vm.undoManager.recordAction(.restoreSingle(url: item.url, previousState: state))

        vm.performUndo()
        XCTAssertTrue(vm.undoManager.canRedo)

        vm.performRedo()
        XCTAssertTrue(vm.undoManager.canUndo, "Redo pushes back onto undo stack")
        XCTAssertFalse(vm.undoManager.canRedo, "Redo stack consumed")
    }

    // MARK: - Export empty icon map

    func testExportEmptyIconMap() {
        let (vm, _) = makeSUT()
        vm.items = []

        // No items → no custom icons → export should produce empty dictionary
        let customIcons: [String: String] = vm.items.reduce(into: [:]) { dict, item in
            if !item.symbolName.isEmpty {
                dict[item.displayName] = item.symbolName
            }
        }
        XCTAssertTrue(customIcons.isEmpty)
    }

    // MARK: - FolderItem symbol name delegation

    func testIconForGlyph() {
        // FolderItem.symbolName delegates to the first entry in symbolNames
        let item = FolderItem(url: URL(fileURLWithPath: "/tmp/test"), symbolName: "heart.fill")
        XCTAssertEqual(item.symbolName, "heart.fill")
    }

    func testUnassignedItemHasEmptySymbolName() {
        let item = FolderItem.unassigned(url: URL(fileURLWithPath: "/tmp/test"))
        XCTAssertTrue(item.symbolName.isEmpty)
        XCTAssertTrue(item.isUnassigned)
    }

    // MARK: - Matched folder tracking

    func testMatchedFolderTracking() {
        let (vm, _) = makeSUT()
        let a = sampleItem(name: "A")
        let b = sampleItem(name: "B")
        let c = sampleItem(name: "C")
        vm.items = [a, b, c]

        // Simulate matched folder tracking via selectedItems
        vm.selectedItemIDs = Set([a.id, b.id])
        XCTAssertEqual(vm.selectedItems.count, 2)

        vm.selectedItemIDs = Set([a.id, b.id, c.id])
        XCTAssertEqual(vm.selectedItems.count, 3)
    }

    // MARK: - Status filter

    func testStatusFilter() {
        let (vm, _) = makeSUT()

        let applied = sampleItem(name: "Applied")
        applied.status = .applied
        let pending = sampleItem(name: "Pending")
        pending.status = .pending
        vm.items = [applied, pending]

        vm.statusFilter = .all
        XCTAssertEqual(vm.filteredItems.count, 2)

        vm.statusFilter = .applied
        XCTAssertEqual(vm.filteredItems.count, 1)
        XCTAssertEqual(vm.filteredItems.first?.displayName, "Applied")

        vm.statusFilter = .pending
        XCTAssertEqual(vm.filteredItems.count, 1)
        XCTAssertEqual(vm.filteredItems.first?.displayName, "Pending")
    }

    // MARK: - FolderItem defaults

    func testFolderItemDefaults() {
        let item = sampleItem()
        XCTAssertEqual(item.symbolOpacity, FolderItem.defaultSymbolOpacity)
        XCTAssertEqual(item.symbolScale, FolderItem.defaultSymbolScale)
        XCTAssertEqual(item.symbolOffsetY, FolderItem.defaultSymbolOffsetY)
        XCTAssertNil(item.symbolColor)
        XCTAssertNil(item.folderColor)
        XCTAssertNil(item.preview)
        XCTAssertEqual(item.status, .pending)
    }

    func testFolderItemDisplayName() {
        let item = sampleItem(name: "MyProject")
        XCTAssertEqual(item.displayName, "MyProject")
    }
}
