//
// SPDX-License-Identifier: MIT
//  UndoManager.swift
//  Iconic
//
//  Manages undo/redo history for icon operations.
//

import Foundation
import AppKit
import Combine

/// Bounded undo/redo stack for icon apply/restore operations.
/// Capped at 20 actions; a new recorded action clears the redo stack.
@MainActor
final class IconicUndoManager: ObservableObject {

    // MARK: - Action Types

    /// Discriminated union of all reversible icon operations.
    enum ActionType {
        case applySingle(url: URL, previousState: FolderState)
        case restoreSingle(url: URL, previousState: FolderState)
        case applyMultiple(states: [URL: FolderState])
        case restoreMultiple(states: [URL: FolderState])
    }

    /// Minimal snapshot of a folder's icon state, captured at action-record
    /// time so we can restore it on undo.
    struct FolderState {
        let status: FolderItemStatus
        let symbolName: String
        let symbolColor: NSColor?
    }

    // MARK: - Properties

    @Published private(set) var canUndo: Bool = false
    @Published private(set) var canRedo: Bool = false
    @Published private(set) var undoDescription: String?

    private var undoStack: [ActionType] = []
    private var redoStack: [ActionType] = []
    private let maxHistorySize = 20

    // MARK: - Public Methods

    /// Records a new action, dropping the oldest if the stack is full and
    /// clearing the redo stack (standard linear-history undo semantics).
    func recordAction(_ action: ActionType) {
        undoStack.append(action)

        // Limit history size
        if undoStack.count > maxHistorySize {
            undoStack.removeFirst()
        }

        // Clear redo stack when new action is recorded
        redoStack.removeAll()

        updateState()
    }

    /// Reverts the most recent action. The action is pushed onto the redo
    /// stack so it can be reapplied with `redo`. The closures are invoked
    /// to perform the actual filesystem work — this manager only mutates
    /// the in-memory `FolderItem` state and dispatches the side effect.
    func undo(items: [FolderItem], applyIcon: @escaping (FolderItem, String, NSColor?) -> Void, restoreIcon: @escaping (FolderItem) -> Void) {
        guard let action = undoStack.popLast() else { return }

        switch action {
        case .applySingle(let url, let previousState):
            if let item = items.first(where: { $0.url == url }) {
                // Restore previous state
                item.symbolNames = [previousState.symbolName]
                item.symbolColor = previousState.symbolColor

                // Re-apply the previous icon or restore default
                if previousState.status == .applied {
                    applyIcon(item, previousState.symbolName, previousState.symbolColor)
                } else {
                    restoreIcon(item)
                }
            }

        case .restoreSingle(let url, let previousState):
            if let item = items.first(where: { $0.url == url }) {
                // Restore previous applied state
                item.symbolNames = [previousState.symbolName]
                item.symbolColor = previousState.symbolColor
                applyIcon(item, previousState.symbolName, previousState.symbolColor)
            }

        case .applyMultiple(let states):
            for (url, previousState) in states {
                if let item = items.first(where: { $0.url == url }) {
                    item.symbolNames = [previousState.symbolName]
                    item.symbolColor = previousState.symbolColor

                    if previousState.status == .applied {
                        applyIcon(item, previousState.symbolName, previousState.symbolColor)
                    } else {
                        restoreIcon(item)
                    }
                }
            }

        case .restoreMultiple(let states):
            for (url, previousState) in states {
                if let item = items.first(where: { $0.url == url }) {
                    item.symbolNames = [previousState.symbolName]
                    item.symbolColor = previousState.symbolColor
                    applyIcon(item, previousState.symbolName, previousState.symbolColor)
                }
            }
        }

        redoStack.append(action)
        updateState()
    }

    func redo(items: [FolderItem], applyIcon: @escaping (FolderItem, String, NSColor?) -> Void, restoreIcon: @escaping (FolderItem) -> Void) {
        guard let action = redoStack.popLast() else { return }

        switch action {
        case .applySingle(let url, _):
            if let item = items.first(where: { $0.url == url }) {
                applyIcon(item, item.symbolName, item.symbolColor)
            }

        case .restoreSingle(let url, _):
            if let item = items.first(where: { $0.url == url }) {
                restoreIcon(item)
            }

        case .applyMultiple(let states):
            for url in states.keys {
                if let item = items.first(where: { $0.url == url }) {
                    applyIcon(item, item.symbolName, item.symbolColor)
                }
            }

        case .restoreMultiple(let states):
            for url in states.keys {
                if let item = items.first(where: { $0.url == url }) {
                    restoreIcon(item)
                }
            }
        }

        undoStack.append(action)
        updateState()
    }

    func clear() {
        undoStack.removeAll()
        redoStack.removeAll()
        updateState()
    }

    // MARK: - Private Methods

    private func updateState() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
        undoDescription = generateUndoDescription()
    }

    private func generateUndoDescription() -> String? {
        guard let lastAction = undoStack.last else { return nil }

        switch lastAction {
        case .applySingle:
            return "Undo: Applied 1 icon"
        case .restoreSingle:
            return "Undo: Restored 1 icon"
        case .applyMultiple(let states):
            return "Undo: Applied \(states.count) icons"
        case .restoreMultiple(let states):
            return "Undo: Restored \(states.count) icons"
        }
    }
}
