//
//  QuickLookPreviewRendererTests.swift
//  IconicTests
//
//  Verifies that the Quick Look preview writer produces a valid PNG in the
//  expected temp directory, and returns nil when there's nothing to preview.
//

import XCTest
import AppKit
@testable import Iconic

@MainActor
final class QuickLookPreviewRendererTests: XCTestCase {

    func testReturnsURLForItemWithPreview() {
        // Build a FolderItem with a small synthesized preview image.
        let folderURL = URL(fileURLWithPath: "/tmp/iconic-tests/SomeFolder", isDirectory: true)
        let item = FolderItem(url: folderURL, symbolName: "music.note")
        item.preview = makeTestImage(size: NSSize(width: 64, height: 64))

        let url = QuickLookPreviewRenderer.makePreviewURL(for: item)
        XCTAssertNotNil(url, "Item with a preview should yield a Quick Look URL")
        XCTAssertTrue(url!.pathExtension == "png", "Output should be a .png")
        XCTAssertTrue(
            url!.path.contains("IconicQuickLook"),
            "Output should live in the dedicated IconicQuickLook temp dir, got \(url!.path)"
        )
        // Verify it's a real PNG (8-byte signature).
        let signature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        if let data = try? Data(contentsOf: url!) {
            XCTAssertEqual(Array(data.prefix(8)), signature, "Output file should be a real PNG")
        } else {
            XCTFail("Output file should be readable")
        }
    }

    func testReturnsNilWhenPreviewIsMissing() {
        let folderURL = URL(fileURLWithPath: "/tmp/iconic-tests/Empty", isDirectory: true)
        let item = FolderItem(url: folderURL, symbolName: "photo")
        item.preview = nil

        let url = QuickLookPreviewRenderer.makePreviewURL(for: item)
        XCTAssertNil(url, "Item without a preview should yield nil")
    }

    func testEachCallProducesAUniqueFile() {
        let folderURL = URL(fileURLWithPath: "/tmp/iconic-tests/Unique", isDirectory: true)
        let item = FolderItem(url: folderURL, symbolName: "trash")
        item.preview = makeTestImage(size: NSSize(width: 32, height: 32))

        let a = QuickLookPreviewRenderer.makePreviewURL(for: item)
        let b = QuickLookPreviewRenderer.makePreviewURL(for: item)
        XCTAssertNotNil(a)
        XCTAssertNotNil(b)
        XCTAssertNotEqual(a, b, "Each call should write a fresh file (UUID-suffixed)")
    }

    // MARK: - Helpers

    private func makeTestImage(size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.systemBlue.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        return image
    }
}
