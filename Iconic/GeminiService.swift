//
//  GeminiService.swift
//  Iconic
//
//  REST client for Gemini API. Batch-matches folder names to SF Symbols.
//  Uses URLSession, no third-party dependencies.
//  Includes persistent caching to reduce API calls.
//

import Foundation

struct GeminiService {

    // MARK: - Cache

    /// Cached AI response for a folder name
    private struct CachedMatch: Codable {
        let folderName: String
        let symbolName: String
        let confidence: Double
        let timestamp: Date
    }

    /// Cache statistics for monitoring performance
    struct CacheStats {
        let totalEntries: Int
        let hitRate: Double // 0.0 to 1.0
        let cacheSize: Int // bytes
    }

    private static let cacheKey = "iconic.ai.cache.v1"

    // Track cache hits/misses for statistics (session-only)
    private static var cacheHits = 0
    private static var cacheMisses = 0

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
        let confidence: Double?
    }

    /// Result of a symbol match with confidence score
    struct MatchResult {
        let symbol: String
        let confidence: Double
    }

    /// Batch-matches folder names to SF Symbols using Gemini API with caching.
    /// Returns a dictionary mapping folder name → MatchResult (symbol + confidence).
    /// Throws GeminiError on failure.
    /// - Parameters:
    ///   - folderNames: Array of folder names to match
    ///   - apiKey: Gemini API key
    ///   - learningExamples: Optional user preference examples for few-shot learning
    ///   - contentAnalysis: Optional array of content analysis results to provide context
    static func matchFolders(_ folderNames: [String], apiKey: String, learningExamples: [(folder: String, symbol: String)]? = nil, contentAnalysis: [FolderContentAnalyzer.ContentAnalysis]? = nil) async throws -> [String: MatchResult] {
        guard !apiKey.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw GeminiError.missingAPIKey
        }

        guard !folderNames.isEmpty else {
            return [:]
        }

        // Step 1: Load cache and check for cached matches
        let cache = loadCache()
        var results: [String: MatchResult] = [:]
        var uncachedFolders: [String] = []

        for folderName in folderNames {
            let normalizedName = folderName.lowercased()

            // Check if we have a cached match for this folder
            if let cached = cache[normalizedName] {
                results[folderName] = MatchResult(symbol: cached.symbolName, confidence: cached.confidence)
                cacheHits += 1
            } else {
                uncachedFolders.append(folderName)
                cacheMisses += 1
            }
        }

        // Step 2: If all folders were cached, return immediately
        if uncachedFolders.isEmpty {
            return results
        }

        // Step 3: Query API for uncached folders only
        let apiResults = try await queryAPI(folderNames: uncachedFolders, apiKey: apiKey, learningExamples: learningExamples, contentAnalysis: contentAnalysis)

        // Step 4: Merge API results with cached results
        for (folderName, matchResult) in apiResults {
            results[folderName] = matchResult
        }

        // Step 5: Save new API results to cache
        saveToCache(apiResults)

        return results
    }

    /// Tests if the API key is valid by making a minimal API call.
    static func testAPIKey(_ apiKey: String) async throws {
        _ = try await matchFolders(["Test"], apiKey: apiKey)
    }

    // MARK: - Cache Management

    /// Loads the persistent cache from UserDefaults
    private static func loadCache() -> [String: CachedMatch] {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else {
            return [:]
        }

        do {
            let decoder = JSONDecoder()
            let cacheArray = try decoder.decode([CachedMatch].self, from: data)
            // Convert array to dictionary with lowercased folder names as keys
            return Dictionary(uniqueKeysWithValues: cacheArray.map { ($0.folderName.lowercased(), $0) })
        } catch {
            print("Failed to load cache: \(error)")
            return [:]
        }
    }

    /// Saves new matches to the persistent cache
    private static func saveToCache(_ matches: [String: MatchResult]) {
        guard !matches.isEmpty else { return }

        // Load existing cache
        var cache = loadCache()

        // Add new matches with current timestamp
        let now = Date()
        for (folderName, matchResult) in matches {
            let normalizedName = folderName.lowercased()
            cache[normalizedName] = CachedMatch(
                folderName: normalizedName,
                symbolName: matchResult.symbol,
                confidence: matchResult.confidence,
                timestamp: now
            )
        }

        // Save back to UserDefaults
        do {
            let encoder = JSONEncoder()
            let cacheArray = Array(cache.values)
            let data = try encoder.encode(cacheArray)
            UserDefaults.standard.set(data, forKey: cacheKey)
        } catch {
            print("Failed to save cache: \(error)")
        }
    }

    /// Clears the entire cache
    static func clearCache() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
        cacheHits = 0
        cacheMisses = 0
    }

    /// Returns cache statistics
    static func getCacheStats() -> CacheStats {
        let cache = loadCache()
        let totalRequests = cacheHits + cacheMisses
        let hitRate = totalRequests > 0 ? Double(cacheHits) / Double(totalRequests) : 0.0

        // Calculate approximate cache size
        var cacheSize = 0
        if let data = UserDefaults.standard.data(forKey: cacheKey) {
            cacheSize = data.count
        }

        return CacheStats(
            totalEntries: cache.count,
            hitRate: hitRate,
            cacheSize: cacheSize
        )
    }

    // MARK: - Private API Methods

    /// Queries the Gemini API for folder matches (no caching)
    private static func queryAPI(folderNames: [String], apiKey: String, learningExamples: [(folder: String, symbol: String)]? = nil, contentAnalysis: [FolderContentAnalyzer.ContentAnalysis]? = nil) async throws -> [String: MatchResult] {
        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=\(apiKey)"
        guard let url = URL(string: endpoint) else {
            throw GeminiError.invalidURL
        }

        let prompt = buildPrompt(folderNames: folderNames, learningExamples: learningExamples, contentAnalysis: contentAnalysis)
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

    // MARK: - Private

    private static func buildPrompt(folderNames: [String], learningExamples: [(folder: String, symbol: String)]? = nil, contentAnalysis: [FolderContentAnalyzer.ContentAnalysis]? = nil) -> String {
        let list = folderNames.map { "\"\($0)\"" }.joined(separator: ", ")

        var prompt = """
        You are an expert at matching folder names to Apple SF Symbols. Your goal is to find the most semantically appropriate, visually distinctive symbol for each folder.

        FOLDER NAMES: [\(list)]

        """

        // Add content analysis context if available
        if let analyses = contentAnalysis, !analyses.isEmpty {
            prompt += """
            FOLDER CONTENT CONTEXT (use this to improve matching accuracy):
            """
            for analysis in analyses {
                prompt += "\n- '\(analysis.folderName)': \(analysis.contextDescription)"
            }
            prompt += "\n\nIMPORTANT: Use the content context to make more accurate symbol choices. For example, a folder with photos should get a camera symbol, a Git repository should get a code-related symbol, etc.\n\n"
        }

        // Add user preference examples if available (few-shot learning)
        if let examples = learningExamples, !examples.isEmpty {
            prompt += """
            USER PREFERENCES (learn from these examples - the user has explicitly chosen these symbols):
            """
            for (folder, symbol) in examples {
                prompt += "\n- '\(folder)' → '\(symbol)'"
            }
            prompt += "\n\nIMPORTANT: These are the user's actual preferences. When matching similar folder names, strongly prefer symbols that align with these examples. Give high confidence (0.95+) to matches that follow these patterns.\n\n"
        }

        prompt += """
        GUIDELINES:
        1. Prefer specific, descriptive symbols over generic ones (e.g., "camera.fill" over "photo")
        2. Consider the folder's likely purpose and contents
        3. Use filled variants (.fill) for better visibility on folder icons
        4. Match semantic meaning, not just literal words (e.g., "finances" → "dollarsign.circle.fill", not "folder.fill")
        5. For technical folders, use appropriate dev symbols (e.g., code, terminal, gear)
        6. For creative folders, use artistic symbols (e.g., paintbrush, music.note, camera)
        7. Only use valid SF Symbol names from SF Symbols 5

        CONFIDENCE SCORING:
        - 1.0: Perfect semantic match (e.g., "Music" → "music.note")
        - 0.9: Strong match with clear association (e.g., "Photos" → "camera.fill")
        - 0.8: Good match, reasonable interpretation (e.g., "Work" → "briefcase.fill")
        - 0.7: Acceptable match, somewhat generic (e.g., "Files" → "doc.fill")
        - 0.6 or below: Weak match, fallback to "folder.fill"

        EXAMPLES OF GOOD MATCHES:
        - "photos" → "camera.fill" (confidence: 0.95) - cameras create photos
        - "music" → "music.note" (confidence: 1.0) - exact semantic match
        - "code" → "chevron.left.forwardslash.chevron.right" (confidence: 0.95) - standard code symbol
        - "documents" → "doc.text.fill" (confidence: 0.9) - documents contain text
        - "downloads" → "arrow.down.circle.fill" (confidence: 0.95) - downloading action
        - "videos" → "video.fill" (confidence: 1.0) - exact match
        - "projects" → "folder.badge.gearshape" (confidence: 0.85) - work/configuration
        - "archive" → "archivebox.fill" (confidence: 1.0) - exact match
        - "trash" → "trash.fill" (confidence: 1.0) - exact match
        - "finances" → "dollarsign.circle.fill" (confidence: 0.9) - money-related
        - "health" → "heart.fill" (confidence: 0.9) - health/medical
        - "travel" → "airplane" (confidence: 0.9) - travel/trips
        - "recipes" → "fork.knife" (confidence: 0.9) - cooking/food
        - "books" → "book.fill" (confidence: 1.0) - exact match
        - "games" → "gamecontroller.fill" (confidence: 1.0) - gaming
        - "design" → "paintbrush.fill" (confidence: 0.9) - creative work
        - "backup" → "externaldrive.fill" (confidence: 0.9) - storage/backup

        RESPONSE FORMAT:
        Return ONLY a valid JSON array. No markdown code fences, no explanation, just the JSON array.

        Each object must have exactly three keys:
        - "folder": the original folder name (string)
        - "symbol": the SF Symbol name (string)
        - "confidence": your confidence score (number between 0 and 1)

        Example:
        [{"folder": "Music", "symbol": "music.note", "confidence": 1.0}, {"folder": "Photos", "symbol": "camera.fill", "confidence": 0.95}]

        If you cannot find a good match (confidence < 0.6), use "folder.fill" with confidence 0.5.
        """

        return prompt
    }

    private static func parseSymbolMatches(from text: String) throws -> [String: MatchResult] {
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

        // Convert to dictionary with MatchResult, validating confidence scores
        var results: [String: MatchResult] = [:]
        for match in matches {
            // Default to 0.8 if confidence is missing (backward compatibility)
            var confidence = match.confidence ?? 0.8

            // Validate confidence is in valid range [0, 1]
            if confidence < 0.0 {
                confidence = 0.0
            } else if confidence > 1.0 {
                confidence = 1.0
            }

            results[match.folder] = MatchResult(symbol: match.symbol, confidence: confidence)
        }

        return results
    }
}
