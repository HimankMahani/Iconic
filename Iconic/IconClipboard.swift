//
// SPDX-License-Identifier: MIT
//  IconClipboard.swift
//  Iconic
//
//  Manages copying and pasting icon settings (symbol, colors, etc.) between folders.
//

import AppKit
import Foundation

struct IconSettings: Codable {
    let symbolName: String
    let symbolColor: NSColor?
    let folderColor: NSColor?

    enum CodingKeys: String, CodingKey {
        case symbolName
        case symbolColorData
        case folderColorData
    }

    init(symbolName: String, symbolColor: NSColor?, folderColor: NSColor?) {
        self.symbolName = symbolName
        self.symbolColor = symbolColor
        self.folderColor = folderColor
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        symbolName = try container.decode(String.self, forKey: .symbolName)

        if let colorData = try container.decodeIfPresent(Data.self, forKey: .symbolColorData),
           let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: colorData) {
            symbolColor = color
        } else {
            symbolColor = nil
        }

        if let colorData = try container.decodeIfPresent(Data.self, forKey: .folderColorData),
           let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: colorData) {
            folderColor = color
        } else {
            folderColor = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(symbolName, forKey: .symbolName)

        if let color = symbolColor,
           let data = try? NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: false) {
            try container.encode(data, forKey: .symbolColorData)
        }

        if let color = folderColor,
           let data = try? NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: false) {
            try container.encode(data, forKey: .folderColorData)
        }
    }
}

enum IconClipboard {
    private static let pasteboardType = NSPasteboard.PasteboardType("com.iconic.iconSettings")

    static func copy(_ settings: IconSettings) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        if let data = try? JSONEncoder().encode(settings) {
            pasteboard.setData(data, forType: pasteboardType)
        }
    }

    static func paste() -> IconSettings? {
        let pasteboard = NSPasteboard.general
        guard let data = pasteboard.data(forType: pasteboardType),
              let settings = try? JSONDecoder().decode(IconSettings.self, from: data) else {
            return nil
        }
        return settings
    }

    static func hasContent() -> Bool {
        let pasteboard = NSPasteboard.general
        return pasteboard.data(forType: pasteboardType) != nil
    }
}
