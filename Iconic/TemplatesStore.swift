//
//  TemplatesStore.swift
//  Iconic
//
//  Reusable icon templates that bundle symbol + colors + adjustments.
//  Apply a template to one or many folders to instantly theme them.
//

import AppKit
import Foundation
import SwiftUI
import Combine

struct IconTemplate: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var symbol: String
    var symbolColorHex: String?
    var folderColorHex: String?
    var symbolGradientEndHex: String?
    var symbolOpacity: Double = 1.0
    var symbolScale: Double = 1.0
    var symbolOffsetY: Double = 0.0

    var symbolColor: NSColor? {
        get { symbolColorHex.flatMap { NSColor.from(hex: $0) } }
        set { symbolColorHex = newValue.flatMap { $0.hexString } }
    }

    var folderColor: NSColor? {
        get { folderColorHex.flatMap { NSColor.from(hex: $0) } }
        set { folderColorHex = newValue.flatMap { $0.hexString } }
    }

    var symbolGradientEnd: NSColor? {
        get { symbolGradientEndHex.flatMap { NSColor.from(hex: $0) } }
        set { symbolGradientEndHex = newValue.flatMap { $0.hexString } }
    }
}

@MainActor
final class TemplatesStore: ObservableObject {
    @Published private(set) var templates: [IconTemplate] = []

    private let key = "iconic.templates.v1"

    init() {
        load()
    }

    func add(_ template: IconTemplate) {
        templates.append(template)
        save()
    }

    func update(_ template: IconTemplate) {
        if let idx = templates.firstIndex(where: { $0.id == template.id }) {
            templates[idx] = template
            save()
        }
    }

    func remove(at offsets: IndexSet) {
        templates.remove(atOffsets: offsets)
        save()
    }

    func remove(id: UUID) {
        templates.removeAll { $0.id == id }
        save()
    }

    /// Applies the template's visual settings to the given folder item.
    /// Returns the modified item.
    @discardableResult
    static func apply(_ template: IconTemplate, to item: FolderItem) -> FolderItem {
        item.symbolNames = [template.symbol]
        item.symbolColor = template.symbolColor
        item.folderColor = template.folderColor
        item.symbolGradientEnd = template.symbolGradientEnd
        item.symbolOpacity = template.symbolOpacity
        item.symbolScale = template.symbolScale
        item.symbolOffsetY = template.symbolOffsetY
        return item
    }

    /// Build a template from a folder item's current visual settings.
    static func capture(from item: FolderItem, name: String) -> IconTemplate {
        var template = IconTemplate(name: name, symbol: item.symbolName)
        template.symbolColor = item.symbolColor
        template.folderColor = item.folderColor
        template.symbolGradientEnd = item.symbolGradientEnd
        template.symbolOpacity = item.symbolOpacity
        template.symbolScale = item.symbolScale
        template.symbolOffsetY = item.symbolOffsetY
        return template
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([IconTemplate].self, from: data) else {
            return
        }
        templates = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(templates) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
