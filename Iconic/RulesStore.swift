//
// SPDX-License-Identifier: MIT
//  RulesStore.swift
//  Iconic
//
//  User-defined rules for matching folder names to icons.
//  Rules support glob patterns and regex, with priority order and auto-apply.
//

import AppKit
import Foundation
import SwiftUI
import Combine

enum RuleMatchType: String, Codable, CaseIterable, Identifiable {
    case glob, regex, contains, exact

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .glob: return "Glob (* and ?)"
        case .regex: return "Regular Expression"
        case .contains: return "Contains"
        case .exact: return "Exact Match"
        }
    }
}

struct IconRule: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var pattern: String
    var matchType: RuleMatchType
    var symbol: String
    var symbolColorHex: String?
    var folderColorHex: String?
    var enabled: Bool = true
    var autoApply: Bool = false
    var priority: Int = 0  // higher = applied first

    var symbolColor: NSColor? {
        get { symbolColorHex.flatMap { NSColor.from(hex: $0) } }
        set { symbolColorHex = newValue.flatMap { $0.hexString } }
    }

    var folderColor: NSColor? {
        get { folderColorHex.flatMap { NSColor.from(hex: $0) } }
        set { folderColorHex = newValue.flatMap { $0.hexString } }
    }

    func matches(_ folderName: String) -> Bool {
        let lowerName = folderName.lowercased()
        let lowerPattern = pattern.lowercased()
        switch matchType {
        case .exact:
            return lowerName == lowerPattern
        case .contains:
            return lowerName.contains(lowerPattern)
        case .glob:
            return ExcludePatternsStore.matches(folderName, patterns: [pattern])
        case .regex:
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                return false
            }
            let range = NSRange(folderName.startIndex..<folderName.endIndex, in: folderName)
            return regex.firstMatch(in: folderName, options: [], range: range) != nil
        }
    }
}

extension NSColor {
    static func from(hex: String) -> NSColor? {
        var hex = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard hex.count == 6 else { return nil }
        var rgb: UInt64 = 0
        guard Scanner(string: hex).scanHexInt64(&rgb) else { return nil }
        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0
        return NSColor(red: r, green: g, blue: b, alpha: 1.0)
    }

    var hexString: String {
        guard let rgb = usingColorSpace(.sRGB) else { return "#000000" }
        let r = Int((rgb.redComponent * 255).rounded())
        let g = Int((rgb.greenComponent * 255).rounded())
        let b = Int((rgb.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

@MainActor
final class RulesStore: ObservableObject {
    @Published private(set) var rules: [IconRule] = []

    private let key = "iconic.rules.v1"

    init() {
        load()
    }

    /// Returns the first matching rule for a folder name (highest priority first).
    /// Only enabled rules are considered.
    func firstMatch(for folderName: String) -> IconRule? {
        rules.filter { $0.enabled }
            .sorted { $0.priority > $1.priority }
            .first { $0.matches(folderName) }
    }

    func add(_ rule: IconRule) {
        rules.append(rule)
        save()
    }

    func update(_ rule: IconRule) {
        if let idx = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[idx] = rule
            save()
        }
    }

    func remove(at offsets: IndexSet) {
        rules.remove(atOffsets: offsets)
        save()
    }

    func remove(id: UUID) {
        rules.removeAll { $0.id == id }
        save()
    }

    func move(from source: IndexSet, to destination: Int) {
        rules.move(fromOffsets: source, toOffset: destination)
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([IconRule].self, from: data) else {
            return
        }
        rules = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(rules) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
