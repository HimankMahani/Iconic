//
// SPDX-License-Identifier: MIT
//  IconMapExporter.swift
//  Iconic
//
//  Exports the current icon assignments to JSON, CSV, or Markdown.
//

import AppKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// Output formats supported by `IconMapExporter`. The raw value doubles
/// as the user-facing label shown in the format picker.
enum IconMapExportFormat: String, CaseIterable, Identifiable {
    case json = "JSON"
    case csv = "CSV"
    case markdown = "Markdown"

    var id: String { rawValue }

    /// File extension (without leading dot) for the saved file.
    var fileExtension: String {
        switch self {
        case .json: return "json"
        case .csv: return "csv"
        case .markdown: return "md"
        }
    }

    /// Uniform Type Identifier used for the save panel and `FileDocument`.
    var contentType: UTType {
        switch self {
        case .json: return .json
        case .csv: return .commaSeparatedText
        case .markdown: return UTType("net.daringfireball.markdown") ?? .plainText
        }
    }
}

/// One row of the exported icon map. Colors are stored as hex strings
/// so the file is portable and diff-friendly.
struct IconMapEntry: Codable {
    let path: String
    let name: String
    let symbol: String
    let symbolColorHex: String?
    let folderColorHex: String?
    let status: String
}

/// Serializes a list of `IconMapEntry` (or a live `FolderItem` list) to
/// JSON, CSV, or Markdown for the export action in the toolbar.
enum IconMapExporter {

    /// Projects a list of `FolderItem` into the exportable `IconMapEntry` form,
    /// converting NSColors to hex and the status enum to a string.
    static func entries(from items: [FolderItem]) -> [IconMapEntry] {
        items.map { item in
            IconMapEntry(
                path: item.url.path,
                name: item.displayName,
                symbol: item.symbolName,
                symbolColorHex: item.symbolColor.flatMap { hexString(from: $0) },
                folderColorHex: item.folderColor.flatMap { hexString(from: $0) },
                status: statusString(item.status)
            )
        }
    }

    /// Encodes `entries` as the chosen format. Returns nil only if JSON
    /// encoding fails; CSV/Markdown always succeed for valid input.
    static func export(_ entries: [IconMapEntry], as format: IconMapExportFormat) -> Data? {
        switch format {
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            return try? encoder.encode(entries)
        case .csv:
            return csvData(from: entries)
        case .markdown:
            return markdownData(from: entries)
        }
    }

    private static func csvData(from entries: [IconMapEntry]) -> Data? {
        var output = "Path,Name,Symbol,Symbol Color,Folder Color,Status\n"
        for entry in entries {
            let row = [
                csvEscape(entry.path),
                csvEscape(entry.name),
                csvEscape(entry.symbol),
                csvEscape(entry.symbolColorHex ?? ""),
                csvEscape(entry.folderColorHex ?? ""),
                csvEscape(entry.status)
            ].joined(separator: ",")
            output += row + "\n"
        }
        return output.data(using: .utf8)
    }

    private static func csvEscape(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return field
    }

    private static func markdownData(from entries: [IconMapEntry]) -> Data? {
        var output = "# Iconic Icon Map\n\n"
        output += "Generated: \(ISO8601DateFormatter().string(from: Date()))\n\n"
        output += "Total folders: \(entries.count)\n\n"
        output += "| Folder | Symbol | Symbol Color | Folder Color | Status | Path |\n"
        output += "|--------|--------|--------------|--------------|--------|------|\n"
        for entry in entries {
            let row = [
                entry.name,
                "`\(entry.symbol)`",
                entry.symbolColorHex ?? "—",
                entry.folderColorHex ?? "—",
                entry.status,
                "`\(entry.path)`"
            ].joined(separator: " | ")
            output += "| \(row) |\n"
        }
        return output.data(using: .utf8)
    }

    private static func hexString(from color: NSColor) -> String {
        guard let rgb = color.usingColorSpace(.sRGB) else { return "" }
        let r = Int(rgb.redComponent * 255)
        let g = Int(rgb.greenComponent * 255)
        let b = Int(rgb.blueComponent * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    private static func statusString(_ status: FolderItemStatus) -> String {
        switch status {
        case .pending: return "pending"
        case .applying: return "applying"
        case .applied: return "applied"
        case .restored: return "restored"
        case .failed(let msg): return "failed: \(msg)"
        }
    }
}

/// `FileDocument` wrapper around an already-serialized `Data` blob.
/// Used so the export action can use the system file exporter UI
/// without re-running `IconMapExporter.export` on read.
struct IconMapDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .commaSeparatedText, .plainText] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
