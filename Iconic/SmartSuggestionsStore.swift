//
//  SmartSuggestionsStore.swift
//  Iconic
//
//  Tracks user choices and provides smart suggestions based on similar folder names.
//

import Foundation
import SwiftUI
import Combine

struct SuggestionEntry: Codable, Identifiable {
    var id = UUID()
    var folderName: String
    var symbolName: String
    var useCount: Int
}

@MainActor
final class SmartSuggestionsStore: ObservableObject {
    @Published private(set) var suggestions: [SuggestionEntry] = []

    private let key = "iconic.suggestions.v1"

    init() {
        load()
    }

    /// Records a user's choice of symbol for a folder name, incrementing use count.
    func recordChoice(folderName: String, symbolName: String) {
        let normalized = folderName.lowercased()

        if let idx = suggestions.firstIndex(where: {
            $0.folderName.lowercased() == normalized && $0.symbolName == symbolName
        }) {
            suggestions[idx].useCount += 1
        } else {
            let entry = SuggestionEntry(
                folderName: folderName,
                symbolName: symbolName,
                useCount: 1
            )
            suggestions.append(entry)
        }

        save()
    }

    /// Returns top 3 symbol suggestions for a given folder name based on fuzzy matching and use count.
    func getSuggestions(for folderName: String) -> [String] {
        let normalized = folderName.lowercased()

        // Find entries with similar folder names
        let matches = suggestions.compactMap { entry -> (String, Int, Double)? in
            let similarity = fuzzyMatch(normalized, entry.folderName.lowercased())
            guard similarity > 0.6 else { return nil }
            return (entry.symbolName, entry.useCount, similarity)
        }

        // Sort by similarity * useCount (weighted score)
        let sorted = matches.sorted { lhs, rhs in
            let scoreA = Double(lhs.1) * lhs.2
            let scoreB = Double(rhs.1) * rhs.2
            return scoreA > scoreB
        }

        // Return top 3 unique symbols
        var result: [String] = []
        var seen = Set<String>()
        for (symbol, _, _) in sorted {
            if !seen.contains(symbol) {
                result.append(symbol)
                seen.insert(symbol)
            }
            if result.count >= 3 { break }
        }

        return result
    }

    /// Simple fuzzy matching using Levenshtein distance, normalized to 0...1.
    private func fuzzyMatch(_ a: String, _ b: String) -> Double {
        guard !a.isEmpty, !b.isEmpty else { return 0 }

        // Exact match
        if a == b { return 1.0 }

        // Substring match
        if a.contains(b) || b.contains(a) { return 0.85 }

        // Levenshtein distance
        let distance = levenshteinDistance(a, b)
        let maxLen = max(a.count, b.count)
        return 1.0 - (Double(distance) / Double(maxLen))
    }

    /// Computes Levenshtein distance between two strings.
    private func levenshteinDistance(_ a: String, _ b: String) -> Int {
        let aChars = Array(a)
        let bChars = Array(b)
        let m = aChars.count
        let n = bChars.count

        guard m > 0 else { return n }
        guard n > 0 else { return m }

        var matrix = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)

        for i in 0...m { matrix[i][0] = i }
        for j in 0...n { matrix[0][j] = j }

        for i in 1...m {
            for j in 1...n {
                let cost = aChars[i - 1] == bChars[j - 1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i - 1][j] + 1,      // deletion
                    matrix[i][j - 1] + 1,      // insertion
                    matrix[i - 1][j - 1] + cost // substitution
                )
            }
        }

        return matrix[m][n]
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key) else { return }
        if let decoded = try? JSONDecoder().decode([SuggestionEntry].self, from: data) {
            suggestions = decoded
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(suggestions) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
