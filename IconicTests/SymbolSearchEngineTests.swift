//
//  SymbolSearchEngineTests.swift
//  IconicTests
//
//  Verifies SymbolSearchEngine's tag-based SF Symbol search.
//

import XCTest
@testable import Iconic

final class SymbolSearchEngineTests: XCTestCase {

    // MARK: - Common term

    func testSearchForCommonTerm() {
        let result = SymbolSearchEngine.search(folderName: "heart")
        XCTAssertNotNil(result, "Searching for 'heart' should return a result")
        XCTAssertFalse(result!.symbol.isEmpty)
    }

    func testSearchForCommonTermPhoto() {
        let result = SymbolSearchEngine.search(folderName: "photo")
        XCTAssertNotNil(result, "Searching for 'photo' should return a result")
    }

    // MARK: - Nonsense term

    func testSearchForNonsense() {
        let result = SymbolSearchEngine.search(folderName: "xqzktvwb-qmjh-999")
        XCTAssertNil(result, "Nonsense input should return nil")
    }

    // MARK: - Minimum confidence constant

    func testMinimumConfidenceConstant() {
        XCTAssertEqual(
            SymbolSearchEngine.minimumConfidence,
            0.7,
            accuracy: 0.001,
            "minimumConfidence should be 0.7"
        )
    }

    // MARK: - Search returns single best result

    func testSearchReturnsAtMostOneResult() {
        // The public API returns Optional<Result>, not an array — so it
        // always returns 0 or 1 results by design.
        let result = SymbolSearchEngine.search(folderName: "music")
        XCTAssertNotNil(result, "Searching for 'music' should return a result")
        // Verify it is a single Result, not a collection
        let symbol = result?.symbol
        XCTAssertNotNil(symbol)
    }

    // MARK: - Search result structure

    func testSearchResultStructure() {
        guard let result = SymbolSearchEngine.search(folderName: "heart") else {
            return XCTFail("Expected a result for 'heart'")
        }
        XCTAssertFalse(result.symbol.isEmpty, "Result symbol should be a non-empty string")
        XCTAssertGreaterThan(result.confidence, 0, "Confidence should be positive")
        XCTAssertLessThanOrEqual(result.confidence, 1.0, "Confidence should be <= 1.0")
    }

    // MARK: - Confidence threshold

    func testResultsMeetMinimumConfidence() {
        let result = SymbolSearchEngine.search(folderName: "heart")
        if let result {
            XCTAssertGreaterThanOrEqual(
                result.confidence,
                SymbolSearchEngine.minimumConfidence,
                "Returned results should meet minimumConfidence"
            )
        }
    }

    func testNonsenseFallsBelowThreshold() {
        let result = SymbolSearchEngine.search(folderName: "xqzktvwb")
        XCTAssertNil(result, "No result should be returned below minimumConfidence")
    }

    // MARK: - Various folder names

    func testSearchForMusic() {
        let result = SymbolSearchEngine.search(folderName: "music")
        XCTAssertNotNil(result)
    }

    func testSearchForCode() {
        let result = SymbolSearchEngine.search(folderName: "code")
        XCTAssertNotNil(result)
    }

    func testSearchForTravel() {
        let result = SymbolSearchEngine.search(folderName: "travel")
        XCTAssertNotNil(result)
    }

    func testSearchForGame() {
        let result = SymbolSearchEngine.search(folderName: "game")
        XCTAssertNotNil(result)
    }
}
