//
//  BackupStore.swift
//  Iconic
//

import AppKit
import Foundation
import SwiftUI
import Combine

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

struct BackupSnapshot: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var createdAt: Date
    var rootPath: String
    var entries: [BackupEntry]
}

@MainActor
final class BackupStore: ObservableObject {
    @Published private(set) var snapshots: [BackupSnapshot] = []

    private let key = "iconic.backups.v1"

    init() {
        load()
    }

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

    func remove(at offsets: IndexSet) {
        snapshots.remove(atOffsets: offsets)
        save()
    }

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
