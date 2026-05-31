//
//  ColorPalette.swift
//  Iconic
//
//  Beautiful color palettes for automatic folder icon coloring.
//

import AppKit

enum Season: String, CaseIterable {
    case spring, summer, autumn, winter

    static func current(date: Date = Date()) -> Season {
        let month = Calendar.current.component(.month, from: date)
        switch month {
        case 3...5: return .spring
        case 6...8: return .summer
        case 9...11: return .autumn
        default: return .winter
        }
    }

    var displayName: String {
        switch self {
        case .spring: return "Spring"
        case .summer: return "Summer"
        case .autumn: return "Autumn"
        case .winter: return "Winter"
        }
    }
}

enum SeasonalThemeStore {
    private static let key = "iconic.seasonalTheme.enabled"

    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

struct ColorPalette {

    /// Seasonal palettes that override category-based colors when enabled.
    static let seasonalPalettes: [Season: [NSColor]] = [
        .spring: [
            NSColor(red: 0.95, green: 0.75, blue: 0.85, alpha: 1.0),    // Cherry blossom
            NSColor(red: 0.65, green: 0.85, blue: 0.55, alpha: 1.0),    // Fresh green
            NSColor(red: 0.95, green: 0.85, blue: 0.50, alpha: 1.0),    // Daffodil
            NSColor(red: 0.55, green: 0.75, blue: 0.95, alpha: 1.0),    // Sky blue
            NSColor(red: 0.80, green: 0.65, blue: 0.95, alpha: 1.0)     // Lilac
        ],
        .summer: [
            NSColor(red: 1.00, green: 0.55, blue: 0.20, alpha: 1.0),    // Mango
            NSColor(red: 1.00, green: 0.80, blue: 0.20, alpha: 1.0),    // Sunshine
            NSColor(red: 0.20, green: 0.70, blue: 0.95, alpha: 1.0),    // Ocean
            NSColor(red: 0.95, green: 0.30, blue: 0.45, alpha: 1.0),    // Watermelon
            NSColor(red: 0.30, green: 0.85, blue: 0.65, alpha: 1.0)     // Mint
        ],
        .autumn: [
            NSColor(red: 0.85, green: 0.40, blue: 0.20, alpha: 1.0),    // Burnt orange
            NSColor(red: 0.65, green: 0.30, blue: 0.20, alpha: 1.0),    // Maple
            NSColor(red: 0.80, green: 0.65, blue: 0.30, alpha: 1.0),    // Amber
            NSColor(red: 0.55, green: 0.40, blue: 0.30, alpha: 1.0),    // Coffee
            NSColor(red: 0.70, green: 0.50, blue: 0.20, alpha: 1.0)     // Bronze
        ],
        .winter: [
            NSColor(red: 0.55, green: 0.75, blue: 0.85, alpha: 1.0),    // Frost
            NSColor(red: 0.30, green: 0.50, blue: 0.75, alpha: 1.0),    // Deep blue
            NSColor(red: 0.85, green: 0.85, blue: 0.95, alpha: 1.0),    // Snow
            NSColor(red: 0.45, green: 0.50, blue: 0.65, alpha: 1.0),    // Slate
            NSColor(red: 0.70, green: 0.60, blue: 0.85, alpha: 1.0)     // Twilight
        ]
    ]

    /// Predefined beautiful color palettes for different folder categories
    static let palettes: [String: [NSColor]] = [
        // Creative & Design
        "creative": [
            NSColor(red: 1.0, green: 0.4, blue: 0.6, alpha: 1.0),      // Pink
            NSColor(red: 0.8, green: 0.3, blue: 0.9, alpha: 1.0),      // Purple
            NSColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1.0)       // Orange
        ],

        // Code & Development
        "code": [
            NSColor(red: 0.2, green: 0.7, blue: 1.0, alpha: 1.0),      // Blue
            NSColor(red: 0.3, green: 0.8, blue: 0.5, alpha: 1.0),      // Green
            NSColor(red: 0.5, green: 0.4, blue: 0.9, alpha: 1.0)       // Indigo
        ],

        // Media (Photos/Videos)
        "media": [
            NSColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1.0),      // Red
            NSColor(red: 1.0, green: 0.7, blue: 0.2, alpha: 1.0),      // Yellow
            NSColor(red: 0.9, green: 0.4, blue: 0.7, alpha: 1.0)       // Magenta
        ],

        // Music & Audio
        "music": [
            NSColor(red: 0.6, green: 0.3, blue: 0.9, alpha: 1.0),      // Purple
            NSColor(red: 1.0, green: 0.4, blue: 0.8, alpha: 1.0),      // Pink
            NSColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 1.0)       // Sky Blue
        ],

        // Work & Business
        "work": [
            NSColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 1.0),      // Professional Blue
            NSColor(red: 0.4, green: 0.6, blue: 0.7, alpha: 1.0),      // Slate
            NSColor(red: 0.5, green: 0.5, blue: 0.6, alpha: 1.0)       // Gray Blue
        ],

        // Nature & Health
        "nature": [
            NSColor(red: 0.3, green: 0.8, blue: 0.4, alpha: 1.0),      // Green
            NSColor(red: 0.4, green: 0.7, blue: 0.3, alpha: 1.0),      // Lime
            NSColor(red: 0.2, green: 0.6, blue: 0.5, alpha: 1.0)       // Teal
        ],

        // Finance & Money
        "finance": [
            NSColor(red: 0.2, green: 0.7, blue: 0.4, alpha: 1.0),      // Money Green
            NSColor(red: 0.9, green: 0.7, blue: 0.2, alpha: 1.0),      // Gold
            NSColor(red: 0.3, green: 0.6, blue: 0.6, alpha: 1.0)       // Teal
        ],

        // Gaming
        "gaming": [
            NSColor(red: 1.0, green: 0.2, blue: 0.4, alpha: 1.0),      // Hot Pink
            NSColor(red: 0.5, green: 0.2, blue: 1.0, alpha: 1.0),      // Electric Purple
            NSColor(red: 0.0, green: 0.8, blue: 1.0, alpha: 1.0)       // Cyan
        ],

        // Education
        "education": [
            NSColor(red: 0.3, green: 0.5, blue: 0.9, alpha: 1.0),      // Royal Blue
            NSColor(red: 0.9, green: 0.5, blue: 0.2, alpha: 1.0),      // Orange
            NSColor(red: 0.6, green: 0.4, blue: 0.8, alpha: 1.0)       // Purple
        ],

        // Travel
        "travel": [
            NSColor(red: 0.2, green: 0.6, blue: 0.9, alpha: 1.0),      // Sky Blue
            NSColor(red: 1.0, green: 0.6, blue: 0.3, alpha: 1.0),      // Sunset Orange
            NSColor(red: 0.3, green: 0.8, blue: 0.7, alpha: 1.0)       // Turquoise
        ],

        // Default/Fallback - Vibrant Rainbow
        "default": [
            NSColor(red: 0.3, green: 0.7, blue: 1.0, alpha: 1.0),      // Blue
            NSColor(red: 0.6, green: 0.4, blue: 0.9, alpha: 1.0),      // Purple
            NSColor(red: 1.0, green: 0.4, blue: 0.6, alpha: 1.0),      // Pink
            NSColor(red: 1.0, green: 0.6, blue: 0.3, alpha: 1.0),      // Orange
            NSColor(red: 0.3, green: 0.8, blue: 0.5, alpha: 1.0),      // Green
            NSColor(red: 1.0, green: 0.7, blue: 0.3, alpha: 1.0)       // Yellow
        ]
    ]

    /// Category keywords for smart color assignment
    private static let categoryKeywords: [String: [String]] = [
        "creative": ["design", "art", "creative", "sketch", "draw", "illustration", "logo", "brand", "mockup", "figma", "photoshop"],
        "code": ["code", "dev", "project", "src", "git", "repo", "api", "backend", "frontend", "web", "app", "xcode", "node", "python", "swift"],
        "media": ["photo", "picture", "image", "video", "movie", "film", "clip", "screenshot", "camera", "gallery"],
        "music": ["music", "song", "audio", "sound", "podcast", "voice", "album", "playlist", "track", "beat"],
        "work": ["work", "office", "business", "client", "contract", "meeting", "presentation", "report", "resume", "admin"],
        "nature": ["health", "fitness", "workout", "gym", "yoga", "nutrition", "recipe", "food", "garden", "plant"],
        "finance": ["finance", "money", "bank", "invoice", "receipt", "tax", "budget", "expense", "invest", "crypto", "wallet"],
        "gaming": ["game", "gaming", "steam", "nintendo", "playstation", "xbox", "mod", "save", "rom"],
        "education": ["school", "college", "university", "class", "course", "homework", "assignment", "lecture", "study", "exam", "research"],
        "travel": ["travel", "trip", "vacation", "holiday", "flight", "hotel", "map", "passport", "itinerary"]
    ]

    /// Assigns a beautiful color to a folder based on its name and category
    static func assignColor(for folderName: String) -> NSColor {
        let normalized = folderName.lowercased()

        // Seasonal theme overrides category-based assignment
        if SeasonalThemeStore.isEnabled {
            let palette = seasonalPalettes[Season.current()] ?? palettes["default"]!
            let hash = abs(folderName.hashValue)
            return palette[hash % palette.count]
        }

        // Try to match category based on folder name
        for (category, keywords) in categoryKeywords {
            for keyword in keywords {
                if normalized.contains(keyword) {
                    if let colors = palettes[category] {
                        // Use hash of folder name to consistently pick same color for same name
                        let hash = abs(folderName.hashValue)
                        let index = hash % colors.count
                        return colors[index]
                    }
                }
            }
        }

        // Fallback to default rainbow palette
        let defaultColors = palettes["default"]!
        let hash = abs(folderName.hashValue)
        let index = hash % defaultColors.count
        return defaultColors[index]
    }

    /// Assigns colors to multiple folders, ensuring variety
    static func assignColors(for folderNames: [String]) -> [String: NSColor] {
        var assignments: [String: NSColor] = [:]
        var usedColors: [NSColor] = []

        for name in folderNames {
            let color = assignColor(for: name)

            // If we've used this exact color recently, try to get a different one from the same palette
            if usedColors.contains(where: { isSimilarColor($0, color) }) {
                // Try to find a different color from the same category
                if let alternateColor = getAlternateColor(for: name, avoiding: usedColors) {
                    assignments[name] = alternateColor
                    usedColors.append(alternateColor)
                } else {
                    assignments[name] = color
                    usedColors.append(color)
                }
            } else {
                assignments[name] = color
                usedColors.append(color)
            }

            // Keep only last 10 colors to allow reuse after some distance
            if usedColors.count > 10 {
                usedColors.removeFirst()
            }
        }

        return assignments
    }

    // MARK: - Private Helpers

    private static func isSimilarColor(_ color1: NSColor, _ color2: NSColor) -> Bool {
        guard let rgb1 = color1.usingColorSpace(.deviceRGB),
              let rgb2 = color2.usingColorSpace(.deviceRGB) else {
            return false
        }

        let threshold: CGFloat = 0.15
        return abs(rgb1.redComponent - rgb2.redComponent) < threshold &&
               abs(rgb1.greenComponent - rgb2.greenComponent) < threshold &&
               abs(rgb1.blueComponent - rgb2.blueComponent) < threshold
    }

    private static func getAlternateColor(for folderName: String, avoiding usedColors: [NSColor]) -> NSColor? {
        let normalized = folderName.lowercased()

        // Find the category
        for (category, keywords) in categoryKeywords {
            for keyword in keywords {
                if normalized.contains(keyword) {
                    if let colors = palettes[category] {
                        // Try to find a color from this palette that's not similar to recently used ones
                        for color in colors {
                            if !usedColors.contains(where: { isSimilarColor($0, color) }) {
                                return color
                            }
                        }
                    }
                }
            }
        }

        return nil
    }
}
