//
//  AILearningStore.swift
//  Iconic
//
//  Tracks user corrections to AI-suggested symbols and uses them to improve
//  future matches via few-shot learning. When users manually change an AI
//  suggestion, we record it and provide relevant examples to Gemini in future
//  prompts to align with user preferences.
//

import Foundation
import SwiftUI
import Combine

struct CorrectionEntry: Codable, Identifiable {
    var id = UUID()
    var folderName: String
    var aiSuggestion: String
    var userChoice: String
    var timestamp: Date
}

@MainActor
final class AILearningStore: ObservableObject {
    @Published private(set) var corrections: [CorrectionEntry] = []

    private let key = "iconic.ai.corrections.v1"
    private let maxCorrections = 500 // Limit storage to prevent unbounded growth

    init() {
        load()
    }

    // MARK: - Recording Corrections

    /// Records when a user changes an AI-suggested symbol to a different one.
    /// This correction will be used to improve future AI suggestions.
    func recordCorrection(folderName: String, aiSuggestion: String, userChoice: String) {
        // Don't record if the user chose the same symbol (no correction)
        guard aiSuggestion != userChoice else { return }

        // Don't record if the user chose a generic fallback (not a real preference)
        guard userChoice != "folder.fill" else { return }

        let entry = CorrectionEntry(
            folderName: folderName,
            aiSuggestion: aiSuggestion,
            userChoice: userChoice,
            timestamp: Date()
        )

        corrections.append(entry)

        // Trim old corrections if we exceed the limit
        if corrections.count > maxCorrections {
            // Keep the most recent corrections
            corrections = Array(corrections.suffix(maxCorrections))
        }

        save()
    }

    // MARK: - Retrieving Examples

    /// Returns the most relevant correction examples for a given folder name.
    /// Uses fuzzy matching to find similar folder names from past corrections.
    /// Returns up to `limit` examples, sorted by relevance (similarity score).
    func getRelevantExamples(for folderName: String, limit: Int = 5) -> [(folder: String, symbol: String)] {
        guard !corrections.isEmpty else { return [] }

        let normalized = folderName.lowercased()

        // Score each correction by similarity to the target folder name
        let scored = corrections.compactMap { entry -> (CorrectionEntry, Double)? in
            let similarity = fuzzyMatch(normalized, entry.folderName.lowercased())
            // Only include corrections with reasonable similarity (> 0.5)
            guard similarity > 0.5 else { return nil }
            return (entry, similarity)
        }

        // Sort by similarity (highest first)
        let sorted = scored.sorted { $0.1 > $1.1 }

        // Return top N unique examples (folder name → user's chosen symbol)
        var result: [(String, String)] = []
        var seenFolders = Set<String>()

        for (entry, _) in sorted {
            let normalizedFolder = entry.folderName.lowercased()
            if !seenFolders.contains(normalizedFolder) {
                result.append((entry.folderName, entry.userChoice))
                seenFolders.insert(normalizedFolder)
            }
            if result.count >= limit { break }
        }

        return result
    }

    /// Returns all corrections as examples for batch processing.
    /// Groups by folder name and returns the most recent user choice for each.
    func getAllExamples(limit: Int = 20) -> [(folder: String, symbol: String)] {
        guard !corrections.isEmpty else { return [] }

        // Group by folder name (case-insensitive) and take the most recent correction
        var latestByFolder: [String: CorrectionEntry] = [:]

        for entry in corrections {
            let key = entry.folderName.lowercased()
            if let existing = latestByFolder[key] {
                // Keep the more recent correction
                if entry.timestamp > existing.timestamp {
                    latestByFolder[key] = entry
                }
            } else {
                latestByFolder[key] = entry
            }
        }

        // Sort by timestamp (most recent first) and take top N
        let sorted = latestByFolder.values
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(limit)

        return sorted.map { ($0.folderName, $0.userChoice) }
    }

    // MARK: - Statistics

    /// Returns the total number of corrections recorded.
    var totalCorrections: Int {
        corrections.count
    }

    /// Returns the most common corrections (AI suggestion → user choice pairs).
    /// Useful for understanding systematic AI mistakes.
    func mostCommonCorrections(limit: Int = 10) -> [(aiSuggestion: String, userChoice: String, count: Int)] {
        guard !corrections.isEmpty else { return [] }

        // Group by (aiSuggestion, userChoice) pair
        var counts: [String: (String, String, Int)] = [:]

        for entry in corrections {
            let key = "\(entry.aiSuggestion)→\(entry.userChoice)"
            if let existing = counts[key] {
                counts[key] = (existing.0, existing.1, existing.2 + 1)
            } else {
                counts[key] = (entry.aiSuggestion, entry.userChoice, 1)
            }
        }

        // Sort by count (highest first)
        let sorted = counts.values.sorted { $0.2 > $1.2 }

        return Array(sorted.prefix(limit))
    }

    /// Clears all recorded corrections. Use with caution.
    func clear() {
        corrections.removeAll()
        save()
    }

    // MARK: - Fuzzy Matching

    /// Simple fuzzy matching using Levenshtein distance, normalized to 0...1.
    /// Returns 1.0 for exact match, 0.0 for completely different strings.
    private func fuzzyMatch(_ a: String, _ b: String) -> Double {
        guard !a.isEmpty, !b.isEmpty else { return 0 }

        // Exact match
        if a == b { return 1.0 }

        // Substring match (high score)
        if a.contains(b) || b.contains(a) { return 0.85 }

        // Token-based match (check if words overlap)
        let aTokens = Set(tokenize(a))
        let bTokens = Set(tokenize(b))
        let intersection = aTokens.intersection(bTokens)
        if !intersection.isEmpty {
            let union = aTokens.union(bTokens)
            let jaccardSimilarity = Double(intersection.count) / Double(union.count)
            if jaccardSimilarity > 0.3 {
                return 0.7 + (jaccardSimilarity * 0.2) // 0.7 to 0.9 range
            }
        }

        // Levenshtein distance (fallback)
        let distance = levenshteinDistance(a, b)
        let maxLen = max(a.count, b.count)
        return 1.0 - (Double(distance) / Double(maxLen))
    }

    /// Tokenizes a string into words, handling camelCase, snake_case, etc.
    private func tokenize(_ str: String) -> [String] {
        var tokens: [String] = []
        var current = ""

        for char in str {
            if char.isUppercase && !current.isEmpty {
                tokens.append(current.lowercased())
                current = String(char)
            } else if char.isLetter || char.isNumber {
                current.append(char)
            } else if !current.isEmpty {
                tokens.append(current.lowercased())
                current = ""
            }
        }

        if !current.isEmpty {
            tokens.append(current.lowercased())
        }

        return tokens.filter { $0.count > 1 } // Filter out single-char tokens
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

    // MARK: - Persistence

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key) else { return }
        if let decoded = try? JSONDecoder().decode([CorrectionEntry].self, from: data) {
            corrections = decoded
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(corrections) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
