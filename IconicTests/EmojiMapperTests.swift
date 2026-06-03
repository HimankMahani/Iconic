//
//  EmojiMapperTests.swift
//  IconicTests
//
//  Verifies EmojiMapper's keyword → emoji mapping pipeline.
//

import XCTest
@testable import Iconic

final class EmojiMapperTests: XCTestCase {

    // MARK: - Known glyph

    func testEmojiForKnownGlyph() {
        let emoji = EmojiMapper.emoji(for: "health")
        XCTAssertEqual(emoji, "❤️", "health should map to ❤️")
    }

    func testEmojiForKnownGlyphMusic() {
        let emoji = EmojiMapper.emoji(for: "music")
        XCTAssertEqual(emoji, "🎵", "music should map to 🎵")
    }

    func testEmojiForKnownGlyphCode() {
        let emoji = EmojiMapper.emoji(for: "code")
        XCTAssertEqual(emoji, "💻", "code should map to 💻")
    }

    // MARK: - Unknown glyph

    func testEmojiForUnknownGlyph() {
        let emoji = EmojiMapper.emoji(for: "xqzktvwb-qmjh-999")
        // Unknown input returns the fallback emoji
        XCTAssertEqual(emoji, EmojiMapper.fallbackEmoji)
    }

    // MARK: - Empty string

    func testEmojiForEmptyString() {
        let emoji = EmojiMapper.emoji(for: "")
        XCTAssertEqual(emoji, EmojiMapper.fallbackEmoji)
    }

    // MARK: - Fallback constant

    func testFallbackEmojiIsFolder() {
        XCTAssertEqual(EmojiMapper.fallbackEmoji, "📁")
    }

    // MARK: - Case insensitivity

    func testCaseInsensitiveLookup() {
        let lower = EmojiMapper.emoji(for: "music")
        let upper = EmojiMapper.emoji(for: "MUSIC")
        let mixed = EmojiMapper.emoji(for: "Music")
        XCTAssertEqual(lower, upper)
        XCTAssertEqual(lower, mixed)
    }

    // MARK: - Custom mappings override

    func testCustomMappingOverridesBuiltIn() {
        let custom = ["music": "🎶"]
        let result = EmojiMapper.emoji(for: "music", customMappings: custom)
        XCTAssertEqual(result, "🎶", "Custom mapping should override built-in")
    }

    // MARK: - Confidence API

    func testEmojiWithConfidenceReturnsSource() {
        let match = EmojiMapper.emojiWithConfidence(for: "music")
        XCTAssertEqual(match.emoji, "🎵")
        XCTAssertGreaterThan(match.confidence, 0)
    }

    func testEmojiWithConfidenceForUnknownReturnsFallback() {
        let match = EmojiMapper.emojiWithConfidence(for: "xqzktvwb")
        XCTAssertEqual(match.emoji, EmojiMapper.fallbackEmoji)
        XCTAssertEqual(match.source, .fallback)
    }
}
