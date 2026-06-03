//
// SPDX-License-Identifier: MIT
//  GeminiService.swift
//  Iconic
//
//  REST client for Gemini API. Batch-matches folder names to SF Symbols.
//  Uses URLSession, no third-party dependencies.
//  Includes persistent caching to reduce API calls.
//

import Foundation
import os.log

struct GeminiService {

    private static let log = Logger(subsystem: "app.iconic.Iconic", category: "GeminiService")

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

    private static let sfSymbolCacheKey = "iconic.ai.cache.v1"
    private static let emojiCacheKey = "iconic.ai.cache.emoji.v1"

    private static func userDefaultsCacheKey(for style: IconStyle) -> String {
        switch style {
        case .sfSymbol: return sfSymbolCacheKey
        case .emoji:    return emojiCacheKey
        }
    }

    // Track cache hits/misses for statistics (session-only)
    private static var cacheHits = 0
    private static var cacheMisses = 0

    // MARK: - Batching constants

    /// Maximum number of folder names sent in a single Gemini API request.
    /// Keeping this small (≤25) ensures prompts stay well within Gemini's
    /// token limits and each request finishes within `queryTimeoutInterval`.
    static let batchSize: Int = 25

    /// Seconds to wait between consecutive batch requests. Prevents bursting
    /// the free-tier rate limit (15 RPM = 1 request every 4 s; 0.5 s leaves
    /// headroom while staying responsive).
    private static let interBatchDelay: TimeInterval = 0.5

    /// Per-request timeout in seconds. 60 s is generous for a 25-name prompt
    /// while still failing fast enough to show a useful error.
    private static let queryTimeoutInterval: TimeInterval = 60

    enum GeminiError: LocalizedError, Equatable {
        case missingAPIKey
        case invalidAPIKeyFormat
        case invalidURL
        case networkError(String)
        case invalidResponse
        case apiError(String)
        case rateLimitExceeded(retryAfterSeconds: Int)
        case invalidJSON
        case offline
        case timeout

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "API key not found. Add one in Settings → Gemini AI."
            case .invalidAPIKeyFormat:
                return "Invalid API key format. Keys start with 'AIza' and are 39 characters."
            case .invalidURL:
                return "Invalid API endpoint. Please report this bug."
            case .networkError(let detail):
                return "Network error: \(detail)"
            case .invalidResponse:
                return "Gemini returned an invalid response. Try again."
            case .apiError(let message):
                return "API error: \(message)"
            case .rateLimitExceeded(let seconds):
                let minutes = max(1, (seconds + 59) / 60)
                return "Rate limit reached. Try again in \(minutes) minute(s)."
            case .invalidJSON:
                return "Failed to parse AI response. Using local matching."
            case .offline:
                return "No internet connection. Using local matching."
            case .timeout:
                return "Request timed out. The batch was split — some folders may still be matched locally."
            }
        }

        var recoverySuggestion: String? {
            switch self {
            case .missingAPIKey:
                return "Get a free key at https://aistudio.google.com/apikey"
            case .rateLimitExceeded:
                return "Free tier allows 15 requests/minute"
            case .offline, .networkError, .timeout:
                return "Check your internet connection"
            default:
                return nil
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

    /// Batch-matches folder names to SF Symbols (or emoji, when `style` is `.emoji`)
    /// using Gemini API with caching.
    ///
    /// Uncached folders are split into chunks of at most `batchSize` names and
    /// sent as sequential API requests. This avoids prompt-size timeouts when
    /// there are hundreds of folders, stays within free-tier rate limits, and
    /// lets the caller handle partial results gracefully when one chunk fails.
    ///
    /// Each completed chunk is written to the persistent cache immediately so
    /// that a mid-run cancellation doesn't discard already-fetched results.
    ///
    /// - Parameters:
    ///   - folderNames: Array of folder names to match
    ///   - apiKey: Gemini API key
    ///   - style: Whether to return SF Symbol names or single-emoji strings
    ///   - learningExamples: Optional user preference examples for few-shot learning
    ///   - contentAnalysis: Optional array of content analysis results to provide context
    ///   - onChunkCompleted: Optional callback invoked after each chunk finishes,
    ///     receiving the partial results so the caller can update the UI progressively.
    ///     Called on whatever concurrency context `matchFolders` is running in.
    static func matchFolders(
        _ folderNames: [String],
        apiKey: String,
        style: IconStyle = .sfSymbol,
        learningExamples: [(folder: String, symbol: String)]? = nil,
        contentAnalysis: [FolderContentAnalyzer.ContentAnalysis]? = nil,
        onChunkCompleted: ((_ chunkResults: [String: MatchResult], _ completedTotal: Int, _ grandTotal: Int) -> Void)? = nil
    ) async throws -> [String: MatchResult] {
        guard !apiKey.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw GeminiError.missingAPIKey
        }

        guard !folderNames.isEmpty else {
            return [:]
        }

        // Step 1: Load cache and split into cached vs. uncached
        let cache = loadCache(style: style)
        var results: [String: MatchResult] = [:]
        var uncachedFolders: [String] = []

        for folderName in folderNames {
            let normalizedName = folderName.lowercased()
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

        // Step 3: Split uncached folders into chunks and query sequentially.
        // Sequential (not parallel) requests stay safely within the free-tier
        // 15 RPM limit regardless of how many chunks there are.
        let chunks = stride(from: 0, to: uncachedFolders.count, by: batchSize).map {
            Array(uncachedFolders[$0 ..< min($0 + batchSize, uncachedFolders.count)])
        }
        let grandTotal = folderNames.count
        var completedUncached = 0

        for (chunkIndex, chunk) in chunks.enumerated() {
            // Respect inter-batch delay for all chunks after the first
            if chunkIndex > 0 {
                try await Task.sleep(nanoseconds: UInt64(interBatchDelay * 1_000_000_000))
            }

            do {
                let chunkResults = try await queryAPI(
                    folderNames: chunk,
                    apiKey: apiKey,
                    style: style,
                    learningExamples: learningExamples,
                    contentAnalysis: contentAnalysis
                )

                // Merge chunk results and persist immediately so partial
                // results survive a future cancellation or crash.
                for (name, match) in chunkResults {
                    results[name] = match
                }
                saveToCache(chunkResults, style: style)

                completedUncached += chunk.count
                let completedTotal = (grandTotal - uncachedFolders.count) + completedUncached
                onChunkCompleted?(chunkResults, completedTotal, grandTotal)

            } catch let error as GeminiError {
                // Log the chunk error but continue with the remaining chunks
                // so one bad network blip doesn't discard everything.
                log.warning("Chunk \(chunkIndex + 1)/\(chunks.count) failed: \(error.localizedDescription, privacy: .public)")
                completedUncached += chunk.count
                // Re-throw only for the very first chunk to surface the error
                // to the caller; subsequent chunk failures are silently skipped
                // because partial results are more useful than a full fallback.
                if chunkIndex == 0 && results.isEmpty {
                    throw error
                }
            }
        }

        return results
    }

    /// Tests if the API key is valid by making a minimal API call.
    static func testAPIKey(_ apiKey: String) async throws {
        _ = try await matchFolders(["Test"], apiKey: apiKey)
    }

    // MARK: - Cache Management

    /// Loads the persistent cache from UserDefaults for the given style.
    private static func loadCache(style: IconStyle = .sfSymbol) -> [String: CachedMatch] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsCacheKey(for: style)) else {
            return [:]
        }

        do {
            let decoder = JSONDecoder()
            let cacheArray = try decoder.decode([CachedMatch].self, from: data)
            // Convert array to dictionary with lowercased folder names as keys
            return Dictionary(uniqueKeysWithValues: cacheArray.map { ($0.folderName.lowercased(), $0) })
        } catch {
            log.error("Failed to load cache: \(error.localizedDescription, privacy: .public)")
            return [:]
        }
    }

    /// Saves new matches to the persistent cache for the given style.
    private static func saveToCache(_ matches: [String: MatchResult], style: IconStyle = .sfSymbol) {
        guard !matches.isEmpty else { return }

        // Load existing cache
        var cache = loadCache(style: style)

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
            UserDefaults.standard.set(data, forKey: userDefaultsCacheKey(for: style))
        } catch {
            log.error("Failed to save cache: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Clears the entire cache (both styles).
    static func clearCache() {
        UserDefaults.standard.removeObject(forKey: sfSymbolCacheKey)
        UserDefaults.standard.removeObject(forKey: emojiCacheKey)
        cacheHits = 0
        cacheMisses = 0
    }

    /// Returns cache statistics for the currently-selected style.
    static func getCacheStats() -> CacheStats {
        let style = IconStyleStore.current
        let cache = loadCache(style: style)
        let totalRequests = cacheHits + cacheMisses
        let hitRate = totalRequests > 0 ? Double(cacheHits) / Double(totalRequests) : 0.0

        // Calculate approximate cache size
        var cacheSize = 0
        if let data = UserDefaults.standard.data(forKey: userDefaultsCacheKey(for: style)) {
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
    private static func queryAPI(folderNames: [String], apiKey: String, style: IconStyle = .sfSymbol, learningExamples: [(folder: String, symbol: String)]? = nil, contentAnalysis: [FolderContentAnalyzer.ContentAnalysis]? = nil) async throws -> [String: MatchResult] {
        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=\(apiKey)"
        guard let url = URL(string: endpoint) else {
            throw GeminiError.invalidURL
        }

        let prompt: String
        switch style {
        case .sfSymbol:
            prompt = buildPrompt(folderNames: folderNames, learningExamples: learningExamples, contentAnalysis: contentAnalysis)
        case .emoji:
            prompt = buildEmojiPrompt(folderNames: folderNames, learningExamples: learningExamples, contentAnalysis: contentAnalysis)
        }
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
        request.timeoutInterval = queryTimeoutInterval

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let urlError as URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                throw GeminiError.offline
            case .timedOut:
                throw GeminiError.timeout
            case .cannotFindHost, .cannotConnectToHost:
                throw GeminiError.networkError("Cannot reach Gemini servers.")
            default:
                throw GeminiError.networkError(urlError.localizedDescription)
            }
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.invalidResponse
        }

        if httpResponse.statusCode == 429 {
            // Parse Retry-After header (RFC 7231: either delta-seconds or HTTP-date).
            // Default to 60 seconds if header is missing or unparseable.
            var retryAfter = 60
            if let header = httpResponse.value(forHTTPHeaderField: "Retry-After"),
               let seconds = Int(header.trimmingCharacters(in: .whitespaces)) {
                retryAfter = seconds
            }
            throw GeminiError.rateLimitExceeded(retryAfterSeconds: retryAfter)
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
        - "downloads" → "tray.and.arrow.down" (confidence: 0.95) - downloading action, tray with arrow
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

    private static func buildEmojiPrompt(folderNames: [String], learningExamples: [(folder: String, symbol: String)]? = nil, contentAnalysis: [FolderContentAnalyzer.ContentAnalysis]? = nil) -> String {
        let list = folderNames.map { "\"\($0)\"" }.joined(separator: ", ")

        var prompt = """
        You are an expert at matching folder names to the single most fitting emoji. Your goal is to pick a visually distinctive emoji that immediately conveys what's in the folder.

        FOLDER NAMES: [\(list)]

        """

        if let analyses = contentAnalysis, !analyses.isEmpty {
            prompt += """
            FOLDER CONTENT CONTEXT (use this to improve matching accuracy):
            """
            for analysis in analyses {
                prompt += "\n- '\(analysis.folderName)': \(analysis.contextDescription)"
            }
            prompt += "\n\nUse the content context to pick a more accurate emoji.\n\n"
        }

        if let examples = learningExamples, !examples.isEmpty {
            prompt += """
            USER PREFERENCES (learn from these examples - the user explicitly chose these):
            """
            for (folder, symbol) in examples {
                prompt += "\n- '\(folder)' → '\(symbol)'"
            }
            prompt += "\n\nWhen similar folder names appear, strongly prefer emoji that align with these examples.\n\n"
        }

        prompt += """
        GUIDELINES:
        1. Return EXACTLY ONE emoji per folder, as a single Unicode emoji character (with variation selector if needed).
        2. Prefer concrete, recognizable emoji over abstract ones (🎵 over 🎼 for "music").
        3. Match semantic meaning, not just literal words (e.g. "finances" → 💰, not 📁).
        4. Use the most common, visually distinctive emoji even at small sizes.
        5. NEVER return SF Symbol names — only Unicode emoji characters.

        CONFIDENCE SCORING:
        - 1.0: Perfect semantic match (e.g. "Music" → 🎵)
        - 0.9: Strong match (e.g. "Photos" → 📸)
        - 0.8: Good match (e.g. "Work" → 💼)
        - 0.7: Acceptable but generic (e.g. "Files" → 📄)
        - 0.6 or below: Weak match — use 📁

        EXAMPLES:
        - "photos" → "📸" (confidence: 0.95)
        - "music" → "🎵" (confidence: 1.0)
        - "code" → "💻" (confidence: 0.95)
        - "documents" → "📑" (confidence: 0.9)
        - "downloads" → "⬇️" (confidence: 0.95)
        - "videos" → "🎬" (confidence: 1.0)
        - "finance" → "💰" (confidence: 0.95)
        - "health" → "❤️" (confidence: 0.9)
        - "travel" → "✈️" (confidence: 0.95)
        - "recipes" → "🍽️" (confidence: 0.9)
        - "books" → "📚" (confidence: 1.0)
        - "games" → "🎮" (confidence: 1.0)
        - "design" → "🎨" (confidence: 0.9)
        - "backup" → "💾" (confidence: 0.9)

        RESPONSE FORMAT:
        Return ONLY a valid JSON array. No markdown code fences, no explanation, just the JSON array.

        Each object must have exactly three keys:
        - "folder": the original folder name (string)
        - "symbol": a single emoji character (string)
        - "confidence": your confidence score (number between 0 and 1)

        Example:
        [{"folder": "Music", "symbol": "🎵", "confidence": 1.0}, {"folder": "Photos", "symbol": "📸", "confidence": 0.95}]

        If you cannot find a good match (confidence < 0.6), use "📁" with confidence 0.5.
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
