//
//  UndoManagerTests.swift
//  IconicTests
//
//  Unit tests for IconicUndoManager undo/redo stacks and action recording.
//

import XCTest
import AppKit
@testable import Iconic

@MainActor
final class UndoManagerTests: XCTestCase {

    private var manager: IconicUndoManager!

    override func setUp() {
        super.setUp()
        manager = IconicUndoManager()
    }

    override func tearDown() {
        manager = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func testInitialState() {
        XCTAssertFalse(manager.canUndo, "Undo stack should be empty initially")
        XCTAssertFalse(manager.canRedo, "Redo stack should be empty initially")
        XCTAssertNil(manager.undoDescription, "Description should be nil when empty")
    }

    // MARK: - Record Actions

    func testRecordApplySingle() {
        let url = URL(fileURLWithPath: "/tmp/test")
        let state = IconicUndoManager.FolderState(status: .pending, symbolName: "folder", symbolColor: nil)
        manager.recordAction(.applySingle(url: url, previousState: state))

        XCTAssertTrue(manager.canUndo)
        XCTAssertFalse(manager.canRedo)
        XCTAssertNotNil(manager.undoDescription)
    }

    func testRecordRestoreSingle() {
        let url = URL(fileURLWithPath: "/tmp/test")
        let state = IconicUndoManager.FolderState(status: .applied, symbolName: "folder.fill", symbolColor: .red)
        manager.recordAction(.restoreSingle(url: url, previousState: state))

        XCTAssertTrue(manager.canUndo)
        XCTAssertNotNil(manager.undoDescription)
    }

    func testRecordApplyMultiple() {
        let url1 = URL(fileURLWithPath: "/tmp/a")
        let url2 = URL(fileURLWithPath: "/tmp/b")
        let state1 = IconicUndoManager.FolderState(status: .pending, symbolName: "doc", symbolColor: nil)
        let state2 = IconicUndoManager.FolderState(status: .applied, symbolName: "doc.fill", symbolColor: .blue)
        manager.recordAction(.applyMultiple(states: [url1: state1, url2: state2]))

        XCTAssertTrue(manager.canUndo)
    }

    func testRecordRestoreMultiple() {
        let url = URL(fileURLWithPath: "/tmp/test")
        let state = IconicUndoManager.FolderState(status: .applied, symbolName: "star", symbolColor: .green)
        manager.recordAction(.restoreMultiple(states: [url: state]))

        XCTAssertTrue(manager.canUndo)
    }

    func testNewActionClearsRedoStack() {
        let url = URL(fileURLWithPath: "/tmp/test")
        let state = IconicUndoManager.FolderState(status: .pending, symbolName: "x", symbolColor: nil)
        manager.recordAction(.applySingle(url: url, previousState: state))
        manager.recordAction(.applySingle(url: url, previousState: state))

        let dummyItem = FolderItem(url: url, symbolName: "x")
        manager.undo(items: [dummyItem], applyIcon: { _, _, _ in }, restoreIcon: { _ in })
        XCTAssertTrue(manager.canRedo)

        manager.recordAction(.applySingle(url: url, previousState: state))
        XCTAssertFalse(manager.canRedo, "Recording a new action should clear the redo stack")
    }

    // MARK: - Undo / Redo Single

    func testUndoSingleAction() {
        let url = URL(fileURLWithPath: "/tmp/test")
        let state = IconicUndoManager.FolderState(status: .pending, symbolName: "folder", symbolColor: nil)
        manager.recordAction(.applySingle(url: url, previousState: state))

        let item = FolderItem(url: url, symbolName: "folder")
        manager.undo(items: [item], applyIcon: { _, _, _ in }, restoreIcon: { _ in })

        XCTAssertFalse(manager.canUndo, "Undo stack should be empty after undoing")
        XCTAssertTrue(manager.canRedo, "Redo stack should have the undone action")
    }

    func testRedoSingleAction() {
        let url = URL(fileURLWithPath: "/tmp/test")
        let state = IconicUndoManager.FolderState(status: .pending, symbolName: "folder", symbolColor: nil)
        manager.recordAction(.applySingle(url: url, previousState: state))

        let item = FolderItem(url: url, symbolName: "folder")
        manager.undo(items: [item], applyIcon: { _, _, _ in }, restoreIcon: { _ in })
        manager.redo(items: [item], applyIcon: { _, _, _ in }, restoreIcon: { _ in })

        XCTAssertTrue(manager.canUndo, "Undo stack should have the redone action")
        XCTAssertFalse(manager.canRedo, "Redo stack should be empty after redo")
    }

    // MARK: - Undo / Redo Multiple

    func testUndoMultipleActions() {
        let url = URL(fileURLWithPath: "/tmp/test")
        let state = IconicUndoManager.FolderState(status: .pending, symbolName: "a", symbolColor: nil)
        manager.recordAction(.applySingle(url: url, previousState: state))
        manager.recordAction(.applySingle(url: url, previousState: state))

        let item = FolderItem(url: url, symbolName: "a")
        manager.undo(items: [item], applyIcon: { _, _, _ in }, restoreIcon: { _ in })
        manager.undo(items: [item], applyIcon: { _, _, _ in }, restoreIcon: { _ in })

        XCTAssertFalse(manager.canUndo)
        XCTAssertTrue(manager.canRedo)
    }

    func testRedoMultipleActions() {
        let url = URL(fileURLWithPath: "/tmp/test")
        let state = IconicUndoManager.FolderState(status: .pending, symbolName: "a", symbolColor: nil)
        manager.recordAction(.applySingle(url: url, previousState: state))
        manager.recordAction(.applySingle(url: url, previousState: state))

        let item = FolderItem(url: url, symbolName: "a")
        manager.undo(items: [item], applyIcon: { _, _, _ in }, restoreIcon: { _ in })
        manager.undo(items: [item], applyIcon: { _, _, _ in }, restoreIcon: { _ in })

        manager.redo(items: [item], applyIcon: { _, _, _ in }, restoreIcon: { _ in })
        manager.redo(items: [item], applyIcon: { _, _, _ in }, restoreIcon: { _ in })

        XCTAssertTrue(manager.canUndo)
        XCTAssertFalse(manager.canRedo)
    }

    // MARK: - Clear

    func testClearHistory() {
        let url = URL(fileURLWithPath: "/tmp/test")
        let state = IconicUndoManager.FolderState(status: .pending, symbolName: "x", symbolColor: nil)
        manager.recordAction(.applySingle(url: url, previousState: state))
        manager.recordAction(.restoreSingle(url: url, previousState: state))

        let item = FolderItem(url: url, symbolName: "x")
        manager.undo(items: [item], applyIcon: { _, _, _ in }, restoreIcon: { _ in })

        manager.clear()

        XCTAssertFalse(manager.canUndo)
        XCTAssertFalse(manager.canRedo)
        XCTAssertNil(manager.undoDescription)
    }

    // MARK: - Closure Execution

    func testUndoCallsApplyIcon() {
        let url = URL(fileURLWithPath: "/tmp/test")
        let state = IconicUndoManager.FolderState(status: .applied, symbolName: "star", symbolColor: .red)
        manager.recordAction(.applySingle(url: url, previousState: state))

        var applyCalled = false
        let item = FolderItem(url: url, symbolName: "star")
        manager.undo(items: [item], applyIcon: { _, _, _ in applyCalled = true }, restoreIcon: { _ in })

        XCTAssertTrue(applyCalled, "Undo should call applyIcon when previous state is .applied")
    }

    func testUndoCallsRestoreIcon() {
        let url = URL(fileURLWithPath: "/tmp/test")
        let state = IconicUndoManager.FolderState(status: .pending, symbolName: "star", symbolColor: nil)
        manager.recordAction(.applySingle(url: url, previousState: state))

        var restoreCalled = false
        let item = FolderItem(url: url, symbolName: "star")
        manager.undo(items: [item], applyIcon: { _, _, _ in }, restoreIcon: { _ in restoreCalled = true })

        XCTAssertTrue(restoreCalled, "Undo should call restoreIcon when previous state is .pending")
    }

    func testRedoCallsApplyIcon() {
        let url = URL(fileURLWithPath: "/tmp/test")
        let state = IconicUndoManager.FolderState(status: .applied, symbolName: "star", symbolColor: .red)
        manager.recordAction(.applySingle(url: url, previousState: state))

        var applyCalled = false
        let item = FolderItem(url: url, symbolName: "star")
        manager.undo(items: [item], applyIcon: { _, _, _ in }, restoreIcon: { _ in })
        manager.redo(items: [item], applyIcon: { _, _, _ in applyCalled = true }, restoreIcon: { _ in })

        XCTAssertTrue(applyCalled, "Redo of applySingle should call applyIcon")
    }

    func testRedoCallsRestoreIcon() {
        let url = URL(fileURLWithPath: "/tmp/test")
        let state = IconicUndoManager.FolderState(status: .pending, symbolName: "star", symbolColor: nil)
        manager.recordAction(.restoreSingle(url: url, previousState: state))

        var restoreCalled = false
        let item = FolderItem(url: url, symbolName: "star")
        manager.undo(items: [item], applyIcon: { _, _, _ in }, restoreIcon: { _ in })
        manager.redo(items: [item], applyIcon: { _, _, _ in }, restoreIcon: { _ in restoreCalled = true })

        XCTAssertTrue(restoreCalled, "Redo of restoreSingle should call restoreIcon")
    }

    // MARK: - Empty Stack Operations

    func testUndoEmptyStack() {
        let item = FolderItem(url: URL(fileURLWithPath: "/tmp/x"), symbolName: "x")
        manager.undo(items: [item], applyIcon: { _, _, _ in }, restoreIcon: { _ in })

        XCTAssertFalse(manager.canUndo)
        XCTAssertFalse(manager.canRedo)
    }

    func testRedoEmptyStack() {
        let item = FolderItem(url: URL(fileURLWithPath: "/tmp/x"), symbolName: "x")
        manager.redo(items: [item], applyIcon: { _, _, _ in }, restoreIcon: { _ in })

        XCTAssertFalse(manager.canUndo)
        XCTAssertFalse(manager.canRedo)
    }

    // MARK: - Undo Description

    func testUndoDescriptionApplySingle() {
        let url = URL(fileURLWithPath: "/tmp/test")
        let state = IconicUndoManager.FolderState(status: .pending, symbolName: "x", symbolColor: nil)
        manager.recordAction(.applySingle(url: url, previousState: state))

        XCTAssertEqual(manager.undoDescription, "Undo: Applied 1 icon")
    }

    func testUndoDescriptionRestoreMultiple() {
        let url = URL(fileURLWithPath: "/tmp/test")
        let state = IconicUndoManager.FolderState(status: .applied, symbolName: "x", symbolColor: nil)
        manager.recordAction(.restoreMultiple(states: [url: state]))

        XCTAssertEqual(manager.undoDescription, "Undo: Restored 1 icon")
    }

    // MARK: - Stack Overflow (maxHistorySize = 20)

    func testMaxHistorySizeEnforced() {
        let url = URL(fileURLWithPath: "/tmp/test")
        let state = IconicUndoManager.FolderState(status: .pending, symbolName: "x", symbolColor: nil)

        for _ in 0..<25 {
            manager.recordAction(.applySingle(url: url, previousState: state))
        }

        let item = FolderItem(url: url, symbolName: "x")
        var undoCount = 0
        while manager.canUndo {
            manager.undo(items: [item], applyIcon: { _, _, _ in }, restoreIcon: { _ in })
            undoCount += 1
        }

        XCTAssertEqual(undoCount, 20, "Should cap at 20 actions")
    }
}
