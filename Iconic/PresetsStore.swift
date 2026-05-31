//
//  PresetsStore.swift
//  Iconic
//
//  Manages saving and loading complete configuration presets including
//  custom mappings, AI settings, and other preferences.
//

import Foundation
import Combine
import SwiftUI

// MARK: - Preset Model

struct Preset: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var customMappings: [CustomMapping]
    var aiEnabled: Bool
    var createdAt: Date

    init(name: String, customMappings: [CustomMapping], aiEnabled: Bool) {
        self.name = name
        self.customMappings = customMappings
        self.aiEnabled = aiEnabled
        self.createdAt = Date()
    }
}

// MARK: - Presets Store

@MainActor
final class PresetsStore: ObservableObject {
    @Published private(set) var presets: [Preset] = []

    private let key = "iconic.presets.v1"

    init() {
        load()
    }

    /// Saves the current configuration as a new preset.
    func saveCurrentAsPreset(
        name: String,
        mappings: [CustomMapping],
        aiEnabled: Bool
    ) throws {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)

        guard !trimmedName.isEmpty else {
            throw PresetError.emptyName
        }

        if presets.contains(where: { $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame }) {
            throw PresetError.duplicateName
        }

        let preset = Preset(
            name: trimmedName,
            customMappings: mappings,
            aiEnabled: aiEnabled
        )

        presets.append(preset)
        save()
    }

    /// Loads a preset and returns its configuration.
    func loadPreset(_ preset: Preset) -> PresetConfiguration {
        PresetConfiguration(
            customMappings: preset.customMappings,
            aiEnabled: preset.aiEnabled
        )
    }

    /// Deletes presets at the given offsets.
    func delete(at offsets: IndexSet) {
        presets.remove(atOffsets: offsets)
        save()
    }

    /// Deletes a specific preset by ID.
    func delete(id: UUID) {
        presets.removeAll { $0.id == id }
        save()
    }

    /// Renames a preset.
    func rename(id: UUID, newName: String) throws {
        let trimmedName = newName.trimmingCharacters(in: .whitespaces)

        guard !trimmedName.isEmpty else {
            throw PresetError.emptyName
        }

        if presets.contains(where: { $0.id != id && $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame }) {
            throw PresetError.duplicateName
        }

        guard let index = presets.firstIndex(where: { $0.id == id }) else {
            throw PresetError.presetNotFound
        }

        presets[index].name = trimmedName
        save()
    }

    /// Exports a preset to a JSON file.
    func exportPreset(_ preset: Preset, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(preset)
        try data.write(to: url)
    }

    /// Imports a preset from a JSON file.
    func importPreset(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var preset = try decoder.decode(Preset.self, from: data)

        // Generate new ID to avoid conflicts
        preset.id = UUID()

        // Handle duplicate names by appending a number
        var finalName = preset.name
        var counter = 1
        while presets.contains(where: { $0.name.caseInsensitiveCompare(finalName) == .orderedSame }) {
            finalName = "\(preset.name) (\(counter))"
            counter += 1
        }
        preset.name = finalName

        presets.append(preset)
        save()
    }

    // MARK: - Private

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let decoded = try? decoder.decode([Preset].self, from: data) {
            presets = decoded
        }
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(presets) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

// MARK: - Supporting Types

struct PresetConfiguration {
    let customMappings: [CustomMapping]
    let aiEnabled: Bool
}

enum PresetError: LocalizedError {
    case emptyName
    case duplicateName
    case presetNotFound

    var errorDescription: String? {
        switch self {
        case .emptyName:
            return "Preset name cannot be empty"
        case .duplicateName:
            return "A preset with this name already exists"
        case .presetNotFound:
            return "Preset not found"
        }
    }
}
