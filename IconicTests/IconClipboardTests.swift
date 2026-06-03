//
//  IconClipboardTests.swift
//  IconicTests
//
//  Tests for IconClipboard copy / paste / hasContent round-trip via NSPasteboard.
//

import XCTest
import AppKit
@testable import Iconic

final class IconClipboardTests: XCTestCase {

    /// Clear the pasteboard before and after every test to avoid cross-test pollution.
    override func setUp() {
        super.setUp()
        NSPasteboard.general.clearContents()
    }

    override func tearDown() {
        NSPasteboard.general.clearContents()
        super.tearDown()
    }

    // MARK: - testInitialClipboardEmpty

    func testInitialClipboardEmpty() {
        // After clearing, hasContent should report false for Iconic data.
        XCTAssertFalse(IconClipboard.hasContent(), "Pasteboard should have no Iconic data after clear")
    }

    // MARK: - testPasteWhenEmpty

    func testPasteWhenEmpty() {
        let pasted = IconClipboard.paste()
        XCTAssertNil(pasted, "Pasting from an empty pasteboard should return nil")
    }

    // MARK: - testCopyAndPaste

    func testCopyAndPaste() {
        let original = IconSettings(
            symbolName: "star.fill",
            symbolColor: NSColor.red,
            folderColor: NSColor.blue
        )

        IconClipboard.copy(original)

        XCTAssertTrue(IconClipboard.hasContent(), "hasContent should be true after copy")

        let pasted = IconClipboard.paste()
        XCTAssertNotNil(pasted, "paste() should return non-nil after copy()")
        XCTAssertEqual(pasted?.symbolName, "star.fill")
    }

    func testCopyAndPasteSymbolNameOnly() {
        let original = IconSettings(
            symbolName: "heart.fill",
            symbolColor: nil,
            folderColor: nil
        )

        IconClipboard.copy(original)
        let pasted = IconClipboard.paste()

        XCTAssertNotNil(pasted)
        XCTAssertEqual(pasted?.symbolName, "heart.fill")
        XCTAssertNil(pasted?.symbolColor, "Nil symbolColor should remain nil after round-trip")
        XCTAssertNil(pasted?.folderColor, "Nil folderColor should remain nil after round-trip")
    }

    func testCopyOverwritesPreviousContent() {
        let first = IconSettings(symbolName: "star.fill", symbolColor: nil, folderColor: nil)
        let second = IconSettings(symbolName: "cloud.fill", symbolColor: NSColor.green, folderColor: nil)

        IconClipboard.copy(first)
        IconClipboard.copy(second)

        let pasted = IconClipboard.paste()
        XCTAssertEqual(pasted?.symbolName, "cloud.fill", "Second copy should overwrite first")
    }

    // MARK: - testClearClipboard

    func testClearClipboard() {
        let settings = IconSettings(symbolName: "folder.fill", symbolColor: nil, folderColor: nil)
        IconClipboard.copy(settings)

        XCTAssertTrue(IconClipboard.hasContent(), "Pre-condition: should have content after copy")

        NSPasteboard.general.clearContents()

        XCTAssertFalse(IconClipboard.hasContent(), "hasContent should be false after manual clear")
        XCTAssertNil(IconClipboard.paste(), "paste() should return nil after clear")
    }

    func testClearClipboardViaEmptyCopy() {
        // Copying an empty pasteboard (clearContents) should remove Iconic data
        let settings = IconSettings(symbolName: "star.fill", symbolColor: nil, folderColor: nil)
        IconClipboard.copy(settings)
        XCTAssertTrue(IconClipboard.hasContent())

        NSPasteboard.general.clearContents()
        XCTAssertFalse(IconClipboard.hasContent())
    }

    // MARK: - Edge cases

    func testPasteIgnoresNonIconicPasteboardData() {
        // Put a plain string on the pasteboard — IconClipboard.paste() should ignore it.
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString("not icon settings", forType: .string)

        let result = IconClipboard.paste()
        XCTAssertNil(result, "paste() should return nil for non-Iconic pasteboard data")
    }

    func testHasContentIgnoresNonIconicData() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString("hello", forType: .string)

        XCTAssertFalse(IconClipboard.hasContent(), "hasContent should ignore non-Iconic pasteboard types")
    }
}
