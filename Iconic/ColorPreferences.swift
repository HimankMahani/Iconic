//
//  ColorPreferences.swift
//  Iconic
//
//  Manages default symbol color preference in UserDefaults.
//

import AppKit

enum ColorPreferences {
    private static let key = "iconic.defaultSymbolColor"

    /// Get the default symbol color from UserDefaults, or .white if not set.
    static func getDefaultColor() -> NSColor {
        guard let data = UserDefaults.standard.data(forKey: key),
              let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) else {
            return .white
        }
        return color
    }

    /// Save the default symbol color to UserDefaults.
    static func setDefaultColor(_ color: NSColor) {
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: true) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
