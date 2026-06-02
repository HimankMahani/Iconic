//
//  KeychainHelperTests.swift
//  IconicTests
//
//  Round-trip tests for the Keychain storage of the Gemini API key.
//  Uses a unique service name suffix to avoid colliding with the shipped app's
//  Keychain entries on the test host.
//

import XCTest
@testable import Iconic

final class KeychainHelperTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Best-effort: clear any leftover key from a previous test run.
        try? KeychainHelper.deleteAPIKey()
    }

    override func tearDown() {
        try? KeychainHelper.deleteAPIKey()
        super.tearDown()
    }

    func testSaveLoadRoundTrip() throws {
        let original = "test-api-key-\(UUID().uuidString)"
        try KeychainHelper.saveAPIKey(original)

        let loaded = try KeychainHelper.loadAPIKey()
        XCTAssertEqual(loaded, original, "Loaded key should match saved key")
    }

    func testLoadReturnsNilWhenAbsent() throws {
        // setUp() deleted any existing key.
        let loaded = try KeychainHelper.loadAPIKey()
        XCTAssertNil(loaded, "Loading when no key exists should return nil")
    }

    func testHasAPIKeyReflectsState() throws {
        XCTAssertFalse(KeychainHelper.hasAPIKey(), "Should be false before save")
        try KeychainHelper.saveAPIKey("any-value")
        XCTAssertTrue(KeychainHelper.hasAPIKey(), "Should be true after save")
    }

    func testDeleteRemovesKey() throws {
        try KeychainHelper.saveAPIKey("to-be-deleted")
        XCTAssertTrue(KeychainHelper.hasAPIKey())
        try KeychainHelper.deleteAPIKey()
        XCTAssertFalse(KeychainHelper.hasAPIKey(), "Delete should remove the key")
    }

    func testDeleteIsIdempotentWhenAbsent() throws {
        // Deleting a non-existent key should not throw.
        XCTAssertNoThrow(try KeychainHelper.deleteAPIKey())
    }

    func testSaveOverwritesPreviousValue() throws {
        try KeychainHelper.saveAPIKey("first")
        try KeychainHelper.saveAPIKey("second")
        let loaded = try KeychainHelper.loadAPIKey()
        XCTAssertEqual(loaded, "second", "Second save should overwrite the first")
    }
}
