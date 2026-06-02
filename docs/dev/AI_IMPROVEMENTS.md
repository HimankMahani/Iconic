# AI Improvements for Iconic

## Current Implementation Analysis

### What's Working ✅
- Gemini 2.5 Flash integration
- Batch processing (all folders in one API call)
- JSON response parsing
- Error handling and fallback to local matching
- API key management with Keychain
- Rate limit detection

### Current Limitations ❌
1. **Single AI Provider**: Only Gemini (no alternatives)
2. **Basic Prompting**: Simple prompt without context
3. **No Caching**: Repeated folders re-query the API
4. **No Learning**: Doesn't learn from user corrections
5. **Limited Context**: Doesn't consider folder contents
6. **No Confidence Scores**: Can't tell if match is good
7. **Batch Size Limits**: No chunking for large folder sets
8. **No Retry Logic**: Single attempt only
9. **No Offline Mode**: Requires internet always
10. **No Cost Tracking**: Users don't know API usage

---

## 🚀 Proposed Improvements

### Priority 1: High Impact, Easy to Implement

#### 1. **AI Response Caching** ⭐⭐⭐
**Problem**: Same folder names query API repeatedly  
**Solution**: Cache AI responses locally

```swift
// Add to GeminiService
private static var responseCache: [String: String] = [:]

static func matchFolders(_ folderNames: [String], apiKey: String) async throws -> [String: String] {
    // Check cache first
    var uncached: [String] = []
    var results: [String: String] = [:]
    
    for name in folderNames {
        if let cached = responseCache[name.lowercased()] {
            results[name] = cached
        } else {
            uncached.append(name)
        }
    }
    
    // Only query API for uncached folders
    if !uncached.isEmpty {
        let apiResults = try await queryAPI(uncached, apiKey: apiKey)
        // Cache results
        for (folder, symbol) in apiResults {
            responseCache[folder.lowercased()] = symbol
        }
        results.merge(apiResults) { $1 }
    }
    
    return results
}
```

**Benefits**:
- Faster responses
- Reduced API costs
- Works offline for cached folders
- Persistent across sessions

---

#### 2. **Improved Prompting with Context** ⭐⭐⭐
**Problem**: AI doesn't understand folder purpose  
**Solution**: Enhanced prompt with examples and context

```swift
private static func buildPrompt(folderNames: [String], context: FolderContext?) -> String {
    var prompt = """
    You are an expert at matching folder names to Apple SF Symbols.
    
    Task: For each folder name, suggest the BEST matching SF Symbol.
    
    Guidelines:
    - Use specific symbols over generic ones (e.g., "camera.fill" not "photo")
    - Consider common naming patterns (e.g., "src" → "chevron.left.forwardslash.chevron.right")
    - Match the folder's likely purpose, not just literal meaning
    - Only use valid SF Symbols from SF Symbols 5
    
    Folder names: [\(folderNames.map { "\"\($0)\"" }.joined(separator: ", "))]
    """
    
    // Add context if available
    if let context = context {
        prompt += """
        
        Additional context:
        - Parent folder: \(context.parentFolder ?? "unknown")
        - Sibling folders: \(context.siblings.joined(separator: ", "))
        - Detected type: \(context.detectedType ?? "unknown")
        """
    }
    
    prompt += """
    
    Return ONLY a JSON array: [{"folder": "name", "symbol": "symbol.name", "confidence": 0.95}]
    Include confidence score (0-1) for each match.
    """
    
    return prompt
}
```

**Benefits**:
- More accurate matches
- Better understanding of context
- Confidence scores for validation

---

#### 3. **Multiple AI Provider Support** ⭐⭐
**Problem**: Locked into Gemini only  
**Solution**: Abstract AI provider interface

```swift
protocol AIProvider {
    func matchFolders(_ names: [String]) async throws -> [String: AIMatch]
}

struct AIMatch {
    let symbol: String
    let confidence: Double
    let reasoning: String?
}

class GeminiProvider: AIProvider { ... }
class ClaudeProvider: AIProvider { ... }
class OpenAIProvider: AIProvider { ... }
class LocalLLMProvider: AIProvider { ... } // Ollama, LM Studio
```

**Supported Providers**:
- ✅ Gemini 2.5 Flash (current)
- 🆕 Claude 3.5 Sonnet (Anthropic)
- 🆕 GPT-4o mini (OpenAI)
- 🆕 Local LLMs (Ollama, LM Studio)

**Benefits**:
- User choice
- Fallback options
- Cost optimization
- Privacy (local LLMs)

---

#### 4. **Smart Batching & Chunking** ⭐⭐
**Problem**: Large folder sets may exceed token limits  
**Solution**: Intelligent chunking

```swift
static func matchFolders(_ folderNames: [String], apiKey: String) async throws -> [String: String] {
    let chunkSize = 50 // Adjust based on provider
    var allResults: [String: String] = [:]
    
    for chunk in folderNames.chunked(into: chunkSize) {
        let results = try await queryAPI(chunk, apiKey: apiKey)
        allResults.merge(results) { $1 }
        
        // Rate limiting delay
        if folderNames.count > chunkSize {
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5s
        }
    }
    
    return allResults
}
```

**Benefits**:
- Handle unlimited folders
- Respect rate limits
- Better error recovery

---

### Priority 2: Medium Impact, Moderate Effort

#### 5. **Learning from User Corrections** ⭐⭐⭐
**Problem**: AI makes same mistakes repeatedly  
**Solution**: Track corrections and use as examples

```swift
class AILearningStore {
    // Store user corrections
    func recordCorrection(folderName: String, aiSuggestion: String, userChoice: String) {
        corrections[folderName.lowercased()] = (ai: aiSuggestion, user: userChoice)
        save()
    }
    
    // Get examples for prompt
    func getRelevantExamples(for folderName: String, limit: Int = 5) -> [(folder: String, symbol: String)] {
        // Find similar corrections using fuzzy matching
        // Return as few-shot examples
    }
}

// In prompt:
"""
Learn from these user preferences:
- User prefers "camera.fill" over "photo" for "photos" folders
- User prefers "terminal.fill" over "command" for "cli" folders
"""
```

**Benefits**:
- Improves over time
- Personalized to user
- Reduces corrections needed

---

#### 6. **Confidence Scores & Validation** ⭐⭐
**Problem**: Can't tell if AI is confident  
**Solution**: Request and use confidence scores

```swift
struct AIMatch {
    let symbol: String
    let confidence: Double // 0.0 - 1.0
    let alternatives: [String] // Other options
}

// In UI:
if match.confidence < 0.7 {
    // Show warning icon
    // Suggest alternatives
    // Offer to use local matching instead
}
```

**Benefits**:
- User knows when to review
- Better fallback decisions
- Quality metrics

---

#### 7. **Folder Content Analysis** ⭐⭐
**Problem**: Only uses folder name, not contents  
**Solution**: Analyze folder contents for better context

```swift
struct FolderContext {
    let hasGitRepo: Bool
    let hasPackageJSON: Bool
    let hasXcodeProject: Bool
    let fileTypes: [String] // [".jpg", ".mp4", ".swift"]
    let fileCount: Int
    let totalSize: Int64
}

// Enhanced prompt:
"""
Folder "photos" contains:
- 150 .jpg files
- 20 .raw files
- Total size: 2.5 GB
Suggested symbol: "camera.fill" (high confidence)
"""
```

**Benefits**:
- More accurate matches
- Understands folder purpose
- Better than name alone

---

#### 8. **Retry Logic with Exponential Backoff** ⭐
**Problem**: Single network failure = complete failure  
**Solution**: Retry with backoff

```swift
static func matchFolders(_ names: [String], apiKey: String, retries: Int = 3) async throws -> [String: String] {
    var lastError: Error?
    
    for attempt in 0..<retries {
        do {
            return try await queryAPI(names, apiKey: apiKey)
        } catch {
            lastError = error
            
            // Don't retry on auth errors
            if case GeminiError.missingAPIKey = error {
                throw error
            }
            
            // Exponential backoff
            let delay = pow(2.0, Double(attempt)) // 1s, 2s, 4s
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
    }
    
    throw lastError ?? GeminiError.networkError(NSError(domain: "", code: -1))
}
```

**Benefits**:
- More reliable
- Handles transient errors
- Better user experience

---

### Priority 3: Advanced Features

#### 9. **Cost Tracking & Budgets** ⭐⭐
**Problem**: Users don't know API costs  
**Solution**: Track usage and show costs

```swift
class AIUsageTracker {
    struct Usage {
        var totalRequests: Int
        var totalTokens: Int
        var estimatedCost: Double
        var lastReset: Date
    }
    
    func recordRequest(folderCount: Int, tokensUsed: Int) {
        // Track usage
        // Calculate cost based on provider
        // Show in analytics
    }
    
    func shouldWarnUser() -> Bool {
        // Warn if approaching budget
        return usage.estimatedCost > userBudget * 0.8
    }
}
```

**UI Addition**:
- Analytics tab shows AI usage
- Monthly cost estimates
- Budget warnings
- Usage graphs

---

#### 10. **Hybrid AI + Local Matching** ⭐⭐⭐
**Problem**: Either AI or local, not both  
**Solution**: Use AI for hard cases, local for easy ones

```swift
func matchFolders(_ names: [String]) async -> [String: String] {
    var results: [String: String] = [:]
    var hardCases: [String] = []
    
    // Try local matching first
    for name in names {
        if let localMatch = SymbolMapper.symbol(for: name, confidence: &confidence),
           confidence > 0.9 {
            results[name] = localMatch
        } else {
            hardCases.append(name)
        }
    }
    
    // Use AI only for hard cases
    if !hardCases.isEmpty, let apiKey = getAPIKey() {
        let aiResults = try? await GeminiService.matchFolders(hardCases, apiKey: apiKey)
        results.merge(aiResults ?? [:]) { $1 }
    }
    
    return results
}
```

**Benefits**:
- Reduced API costs
- Faster responses
- Best of both worlds

---

#### 11. **Streaming Responses** ⭐
**Problem**: Wait for entire batch to complete  
**Solution**: Stream results as they arrive

```swift
func matchFoldersStreaming(_ names: [String], onMatch: @escaping (String, String) -> Void) async throws {
    // Use streaming API endpoint
    // Call onMatch for each result as it arrives
    // Update UI in real-time
}
```

**Benefits**:
- Faster perceived performance
- Progressive UI updates
- Better UX for large batches

---

#### 12. **Local LLM Support** ⭐⭐⭐
**Problem**: Requires internet and costs money  
**Solution**: Support local LLMs (Ollama, LM Studio)

```swift
class OllamaProvider: AIProvider {
    func matchFolders(_ names: [String]) async throws -> [String: AIMatch] {
        // Connect to local Ollama instance
        // Use llama3, mistral, or other models
        // 100% private, 100% free
    }
}
```

**Supported Models**:
- Llama 3
- Mistral
- Phi-3
- Gemma

**Benefits**:
- Free
- Private
- Offline
- Fast (with good hardware)

---

## 📊 Implementation Roadmap

### Phase 1: Quick Wins (1-2 days)
1. ✅ AI Response Caching
2. ✅ Improved Prompting
3. ✅ Smart Batching
4. ✅ Retry Logic

### Phase 2: Core Improvements (3-5 days)
5. ✅ Multiple AI Providers
6. ✅ Confidence Scores
7. ✅ Learning from Corrections
8. ✅ Folder Content Analysis

### Phase 3: Advanced Features (1 week)
9. ✅ Cost Tracking
10. ✅ Hybrid Matching
11. ✅ Streaming Responses
12. ✅ Local LLM Support

---

## 🎯 Recommended Priority

**Start with these 3:**
1. **AI Response Caching** - Immediate impact, easy to implement
2. **Improved Prompting** - Better results with minimal code
3. **Learning from Corrections** - Gets smarter over time

**Then add:**
4. **Multiple AI Providers** - User choice and flexibility
5. **Hybrid Matching** - Cost savings and speed

---

## 💡 Quick Implementation: AI Caching

Want me to implement AI response caching right now? It's the easiest high-impact improvement:

- ✅ 50-90% reduction in API calls
- ✅ Instant responses for cached folders
- ✅ Persistent across app restarts
- ✅ ~50 lines of code

Should I implement this first?
