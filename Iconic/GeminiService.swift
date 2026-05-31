//
//  GeminiService.swift
//  Iconic
//
//  REST client for Gemini API. Batch-matches folder names to SF Symbols.
//  Uses URLSession, no third-party dependencies.
//

import Foundation

struct GeminiService {

    enum GeminiError: LocalizedError {
        case missingAPIKey
        case invalidURL
        case networkError(Error)
        case invalidResponse
        case apiError(String)
        case rateLimitExceeded
        case invalidJSON

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "Gemini API key not found. Please add it in Settings."
            case .invalidURL:
                return "Invalid Gemini API endpoint URL."
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .invalidResponse:
                return "Gemini returned an invalid response."
            case .apiError(let message):
                return "Gemini API error: \(message)"
            case .rateLimitExceeded:
                return "Gemini API rate limit exceeded. Try again later."
            case .invalidJSON:
                return "Failed to parse Gemini response."
            }
        }
    }

    private struct GeminiRequest: Codable {
        let contents: [Content]

        struct Content: Codable {
            let parts: [Part]
        }

        struct Part: Codable {
            let text: String
        }
    }

    private struct GeminiResponse: Codable {
        let candidates: [Candidate]?
        let error: ErrorDetail?

        struct Candidate: Codable {
            let content: Content
        }

        struct Content: Codable {
            let parts: [Part]
        }

        struct Part: Codable {
            let text: String
        }

        struct ErrorDetail: Codable {
            let message: String
            let code: Int?
        }
    }

    private struct SymbolMatch: Codable {
        let folder: String
        let symbol: String
    }

    /// Batch-matches folder names to SF Symbols using Gemini API.
    /// Returns a dictionary mapping folder name → SF Symbol name.
    /// Throws GeminiError on failure.
    static func matchFolders(_ folderNames: [String], apiKey: String) async throws -> [String: String] {
        guard !apiKey.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw GeminiError.missingAPIKey
        }

        guard !folderNames.isEmpty else {
            return [:]
        }

        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=\(apiKey)"
        guard let url = URL(string: endpoint) else {
            throw GeminiError.invalidURL
        }

        let prompt = buildPrompt(folderNames: folderNames)
        let requestBody = GeminiRequest(
            contents: [
                GeminiRequest.Content(
                    parts: [GeminiRequest.Part(text: prompt)]
                )
            ]
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.invalidResponse
        }

        if httpResponse.statusCode == 429 {
            throw GeminiError.rateLimitExceeded
        }

        guard httpResponse.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GeminiError.apiError("HTTP \(httpResponse.statusCode): \(errorMsg)")
        }

        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)

        if let error = geminiResponse.error {
            throw GeminiError.apiError(error.message)
        }

        guard let candidate = geminiResponse.candidates?.first,
              let text = candidate.content.parts.first?.text else {
            throw GeminiError.invalidResponse
        }

        return try parseSymbolMatches(from: text)
    }

    /// Tests if the API key is valid by making a minimal API call.
    static func testAPIKey(_ apiKey: String) async throws {
        _ = try await matchFolders(["Test"], apiKey: apiKey)
    }

    // MARK: - Private

    private static func buildPrompt(folderNames: [String]) -> String {
        let list = folderNames.map { "\"\($0)\"" }.joined(separator: ", ")
        return """
        Given these folder names: [\(list)].

        For each one, return the single best matching Apple SF Symbol name from SF Symbols 5.

        Return ONLY a valid JSON array of objects with keys "folder" and "symbol". No markdown, no explanation, just the JSON array.

        Example format:
        [{"folder": "Music", "symbol": "music.note"}, {"folder": "Photos", "symbol": "photo.stack"}]

        Only use valid SF Symbol names that exist in SF Symbols 5. If unsure, use "folder.fill".
        """
    }

    private static func parseSymbolMatches(from text: String) throws -> [String: String] {
        // Strip markdown code fences if present
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```json") {
            cleaned = cleaned.replacingOccurrences(of: "```json", with: "")
        }
        if cleaned.hasPrefix("```") {
            cleaned = cleaned.replacingOccurrences(of: "```", with: "")
        }
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8) else {
            throw GeminiError.invalidJSON
        }

        let matches = try JSONDecoder().decode([SymbolMatch].self, from: data)
        return Dictionary(uniqueKeysWithValues: matches.map { ($0.folder, $0.symbol) })
    }
}
