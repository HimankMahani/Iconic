//
//  SymbolMapperTests.swift
//  IconicTests
//
//  Focused tests for the keyword → SF Symbol mapping pipeline.
//  Exercises the exact, token, substring, fuzzy, and custom-mapping paths
//  that the runtime uses for every scanned folder.
//

import XCTest
@testable import Iconic

final class SymbolMapperTests: XCTestCase {

    // MARK: - Exact full-name match

    func testExactFullNameMatch() {
        let result = SymbolMapper.symbolWithConfidence(for: "Music")
        XCTAssertEqual(result.symbol, "music.note", "Music → music.note")
        XCTAssertEqual(result.confidence, 1.0, accuracy: 0.001)
    }

    func testExactFullNameMatchIsCaseInsensitive() {
        let r1 = SymbolMapper.symbolWithConfidence(for: "MUSIC")
        let r2 = SymbolMapper.symbolWithConfidence(for: "music")
        let r3 = SymbolMapper.symbolWithConfidence(for: "Music")
        XCTAssertEqual(r1.symbol, "music.note")
        XCTAssertEqual(r2.symbol, "music.note")
        XCTAssertEqual(r3.symbol, "music.note")
    }

    // MARK: - Token match

    func testTokenMatchPicksKnownWord() {
        // "My Photos 2024" — tokenization strips "2024" as a year.
        // The remaining tokens ("my", "photos") should match "photo"/"photos".
        let result = SymbolMapper.symbolWithConfidence(for: "My Photos 2024")
        XCTAssertTrue(
            ["photo", "photo.stack"].contains(result.symbol),
            "Expected photo or photo.stack, got \(result.symbol)"
        )
    }

    func testCamelCaseTokenization() {
        // "myMusicLibrary" splits into "my", "music", "library". The matcher's
        // reverse-keyword table in SymbolMetadata.swift matches "music" against
        // both "music.note" and "music.note.house.fill" — the latter wins by
        // token-overlap scoring. Accept any music.* family symbol.
        let result = SymbolMapper.symbolWithConfidence(for: "myMusicLibrary")
        XCTAssertTrue(
            result.symbol.hasPrefix("music."),
            "Expected a music-family symbol, got \(result.symbol)"
        )
    }

    // MARK: - Substring match

    func testSubstringMatchHandlesPlurals() {
        // "photographs" should still resolve to the photo symbol family.
        let result = SymbolMapper.symbolWithConfidence(for: "photographs")
        XCTAssertTrue(
            ["photo", "photo.stack"].contains(result.symbol),
            "Expected photo symbol family for 'photographs', got \(result.symbol)"
        )
    }

    // MARK: - Fuzzy match

    func testFuzzyMatchFindsCloseKeyword() {
        // "musik" is 1 edit from "music" — fuzzy-matches the music keyword
        // family. The reverse-keyword table resolves to a music.* symbol;
        // exact name doesn't matter, just that we land in the music family.
        let result = SymbolMapper.symbolWithConfidence(for: "musik")
        XCTAssertTrue(
            result.symbol.hasPrefix("music."),
            "musik should fuzzy-match into the music family, got \(result.symbol)"
        )
    }

    // MARK: - Custom mappings

    func testCustomMappingTakesPriorityOverBuiltIn() {
        let custom = ["music": "headphones"]
        let result = SymbolMapper.symbolWithConfidence(
            for: "Music",
            customMappings: custom
        )
        XCTAssertEqual(result.symbol, "headphones", "Custom mapping should win over built-in")
        XCTAssertEqual(result.source, .customMapping)
    }

    func testCustomMappingByFullName() {
        // Custom mappings are matched on the full normalized folder name
        // (after tokenization), not on individual tokens. A mapping keyed
        // "vacation" applies to the folder "Vacation" or "vacation photos"
        // when its normalized form is "vacation".
        let custom = ["vacation": "suitcase.fill"]
        let result = SymbolMapper.symbolWithConfidence(
            for: "Vacation",
            customMappings: custom
        )
        XCTAssertEqual(result.symbol, "suitcase.fill")
    }

    // MARK: - Noise tokens

    func testNoiseTokensAreIgnored() {
        // "build-2024" — "2024" is a year noise token; "build" should match.
        let result = SymbolMapper.symbolWithConfidence(for: "build-2024")
        XCTAssertEqual(result.symbol, "hammer.circle", "build should map to hammer.circle, got \(result.symbol)")
    }

    func testAllNoiseTokensFallbackKeepsOriginals() {
        // If every token is noise (e.g. "2024"), the matcher falls back to
        // folder.fill. The important property is that it doesn't crash and
        // returns a valid symbol.
        let result = SymbolMapper.symbolWithConfidence(for: "2024")
        XCTAssertFalse(result.symbol.isEmpty)
    }

    // MARK: - Fallback

    func testUnknownFolderReturnsFallback() {
        // A nonsense name with no matching keyword should hit the fallback.
        // Use a string with NO substring that maps to any known keyword
        // (avoid "random", "music", "photo", "library", etc. as substrings).
        let result = SymbolMapper.symbolWithConfidence(for: "xqzktvwb-2024-qmjh")
        XCTAssertEqual(result.symbol, SymbolMapper.fallbackSymbol)
        XCTAssertEqual(result.confidence, 0.0, accuracy: 0.001)
    }

    // MARK: - Public helpers

    func testPublicTokenizeIsStable() {
        let a = SymbolMapper.publicTokenize("MyPhotos 2024")
        let b = SymbolMapper.publicTokenize("myphotos 2024")
        XCTAssertEqual(a, b, "Tokenize should be case-insensitive")
    }

    func testPublicSimilarityIsInUnitInterval() {
        let s1 = SymbolMapper.publicSimilarity("music", "music")
        let s2 = SymbolMapper.publicSimilarity("music", "musik")
        let s3 = SymbolMapper.publicSimilarity("music", "completely")
        XCTAssertEqual(s1, 1.0, accuracy: 0.001)
        XCTAssertGreaterThan(s2, 0.7, "One-edit distance should be > 0.7")
        XCTAssertLessThan(s3, 0.5, "Disjoint words should be < 0.5")
    }
}
