//
//  IconApplierTests.swift
//  IconicTests
//
//  Tests for the SIP / path-validation guards on the icon applier. Does not
//  actually call setIcon (which would touch the filesystem and require user
//  consent); instead exercises the pure-validation paths.
//

import XCTest
@testable import Iconic

final class IconApplierTests: XCTestCase {

    // MARK: - SIP detection

    func testSystemFolderIsSIPProtected() {
        XCTAssertTrue(IconApplier.isSIPProtected(URL(fileURLWithPath: "/System/Library")))
        XCTAssertTrue(IconApplier.isSIPProtected(URL(fileURLWithPath: "/System/Applications")))
    }

    func testUsrLocalIsNotSIPProtected() {
        // /usr/local is excluded from SIP.
        XCTAssertFalse(IconApplier.isSIPProtected(URL(fileURLWithPath: "/usr/local/bin")))
    }

    func testUsrIsSIPProtectedExceptLocal() {
        XCTAssertTrue(IconApplier.isSIPProtected(URL(fileURLWithPath: "/usr/bin")))
        XCTAssertTrue(IconApplier.isSIPProtected(URL(fileURLWithPath: "/usr/sbin")))
    }

    func testBinAndSbinAreSIPProtected() {
        XCTAssertTrue(IconApplier.isSIPProtected(URL(fileURLWithPath: "/bin")))
        XCTAssertTrue(IconApplier.isSIPProtected(URL(fileURLWithPath: "/sbin")))
    }

    func testAppleLibraryIsSIPProtected() {
        XCTAssertTrue(IconApplier.isSIPProtected(URL(fileURLWithPath: "/Library/Apple/usr")))
    }

    func testUserHomeIsNotSIPProtected() {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        XCTAssertFalse(IconApplier.isSIPProtected(home))
        XCTAssertFalse(IconApplier.isSIPProtected(home.appendingPathComponent("Documents")))
        XCTAssertFalse(IconApplier.isSIPProtected(home.appendingPathComponent("Desktop")))
    }

    // MARK: - apply() error paths (no filesystem writes)

    func testApplyThrowsSIPProtected() {
        XCTAssertThrowsError(
            try IconApplier.apply(NSImage(), to: URL(fileURLWithPath: "/System/Foo"))
        ) { error in
            guard let applyError = error as? IconApplyError,
                  case .sipProtected = applyError else {
                return XCTFail("Expected .sipProtected, got \(error)")
            }
        }
    }

    func testApplyThrowsMissingPath() {
        let bogus = URL(fileURLWithPath: "/this/path/does/not/exist/anywhere-\(UUID().uuidString)")
        XCTAssertThrowsError(try IconApplier.apply(NSImage(), to: bogus)) { error in
            guard let applyError = error as? IconApplyError,
                  case .missingPath = applyError else {
                return XCTFail("Expected .missingPath, got \(error)")
            }
        }
    }

    // MARK: - Error descriptions

    func testErrorDescriptionMentionsSIP() {
        let error = IconApplyError.sipProtected(URL(fileURLWithPath: "/System"))
        XCTAssertNotNil(error.errorDescription)
        XCTAssertNotNil(error.recoverySuggestion)
    }
}
