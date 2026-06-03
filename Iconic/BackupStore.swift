//
// SPDX-License-Identifier: MIT
//  BackupStore.swift
//  Iconic
//

import AppKit
import Foundation
import SwiftUI
import Combine

/// A single folder's icon settings captured in a `BackupSnapshot`.
/// Stores colors as hex strings so the snapshot is JSON-portable.
struct BackupEntry: Codable, Hashable {
    var folderPath: String
    var symbolName: String
    var symbolColorHex: String?
    var folderColorHex: String?
    var symbolOpacity: Double
    var symbolScale: Double
    var symbolOffsetY: Double
    var symbolGradientEndHex: String?
}

/// A named, point-in-time capture of a folder tree's icon assignments.
/// Shown in the Backups preferences tab and can be applied via `BackupStore.restore`.
struct BackupSnapshot: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var createdAt: Date
    var rootPath: String
    var entries: [BackupEntry]
}

/// In-memory list of saved icon-map snapshots, persisted to `UserDefaults`.
/// Drives the Backups preferences tab.
@MainActor
final class BackupStore: ObservableObject {
    @Published private(set) var snapshots: [BackupSnapshot] = []

    private let key = "iconic.backups.v1"

    /// Loads any previously-saved snapshots from `UserDefaults`.
    init() {
        load()
    }

    /// Captures the current icon settings for `items` and stores them as a new snapshot.
    /// - Parameters:
    ///   - name: User-supplied label for the snapshot.
    ///   - items: Folders to include in the snapshot.
    ///   - rootURL: Optional root of the folder tree the snapshot represents.
    /// - Returns: The newly created snapshot (also prepended to `snapshots`).
    func capture(name: String, items: [FolderItem], rootURL: URL?) -> BackupSnapshot {
        let entries = items.map { item in
            BackupEntry(
                folderPath: item.url.path,
                symbolName: item.symbolName,
                symbolColorHex: item.symbolColor?.hexString,
                folderColorHex: item.folderColor?.hexString,
                symbolOpacity: item.symbolOpacity,
                symbolScale: item.symbolScale,
                symbolOffsetY: item.symbolOffsetY,
                symbolGradientEndHex: item.symbolGradientEnd?.hexString
            )
        }

        let snapshot = BackupSnapshot(
            name: name,
            createdAt: Date(),
            rootPath: rootURL?.path ?? "",
            entries: entries
        )

        snapshots.insert(snapshot, at: 0)
        save()
        return snapshot
    }

    /// Mutates the in-memory `items` to match `snapshot`. Items not present
    /// in the snapshot are left untouched. Note: this only updates the model —
    /// callers are responsible for re-applying the icons to disk.
    /// - Parameters:
    ///   - snapshot: The snapshot to replay.
    ///   - items: The current folder list to mutate in place.
    func restore(_ snapshot: BackupSnapshot, into items: [FolderItem]) {
        let entryLookup = Dictionary(uniqueKeysWithValues: snapshot.entries.map { ($0.folderPath, $0) })

        for item in items {
            guard let entry = entryLookup[item.url.path] else { continue }

            item.symbolNames = [entry.symbolName]
            item.symbolColor = entry.symbolColorHex.flatMap { NSColor.from(hex: $0) }
            item.folderColor = entry.folderColorHex.flatMap { NSColor.from(hex: $0) }
            item.symbolOpacity = entry.symbolOpacity
            item.symbolScale = entry.symbolScale
            item.symbolOffsetY = entry.symbolOffsetY
            item.symbolGradientEnd = entry.symbolGradientEndHex.flatMap { NSColor.from(hex: $0) }
        }
    }

    /// Removes snapshots at the given indices (ForEach `.onDelete` hook).
    func remove(at offsets: IndexSet) {
        snapshots.remove(atOffsets: offsets)
        save()
    }

    /// Removes the snapshot with the given id, if present.
    func remove(id: UUID) {
        snapshots.removeAll { $0.id == id }
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([BackupSnapshot].self, from: data) else {
            return
        }
        snapshots = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(snapshots) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
