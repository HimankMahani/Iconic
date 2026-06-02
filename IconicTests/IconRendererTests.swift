//
//  IconRendererTests.swift
//  IconicTests
//
//  Verifies that the multi-resolution icon compositor produces a valid image
//  for the SF Symbol overlay pipeline.
//

import XCTest
import AppKit
@testable import Iconic

final class IconRendererTests: XCTestCase {

    func testMakeIconReturnsImageForValidSymbol() {
        let icon = IconRenderer.makeIcon(symbolName: "music.note", tint: .systemBlue)
        XCTAssertNotNil(icon, "Valid symbol should produce a non-nil icon")
    }

    func testMakeIconHasAllExpectedRepresentations() {
        guard let icon = IconRenderer.makeIcon(symbolName: "photo", tint: .systemRed) else {
            return XCTFail("Renderer returned nil")
        }
        let expectedSizes = Set(IconRenderer.representationSizes.map { Int($0) })
        let actualSizes = Set(icon.representations.compactMap { Int($0.size.width) })
        XCTAssertTrue(
            expectedSizes.isSubset(of: actualSizes),
            "Expected at least these sizes: \(expectedSizes.sorted()), got \(actualSizes.sorted())"
        )
    }

    func testMakeIconWithCustomTint() {
        // Two different tints should produce visually distinct images.
        let redIcon = IconRenderer.makeIcon(symbolName: "folder.fill", tint: .systemRed)
        let blueIcon = IconRenderer.makeIcon(symbolName: "folder.fill", tint: .systemBlue)
        XCTAssertNotNil(redIcon)
        XCTAssertNotNil(blueIcon)

        // PNG byte representations should differ.
        let redData = redIcon?.tiffRepresentation
        let blueData = blueIcon?.tiffRepresentation
        XCTAssertNotEqual(redData, blueData, "Different tints should yield different image data")
    }

    func testMakeIconWithFolderTint() {
        let icon = IconRenderer.makeIcon(
            symbolName: "music.note",
            tint: .white,
            folderTint: .systemTeal
        )
        XCTAssertNotNil(icon, "Folder tint + symbol should still produce an icon")
    }

    func testMultiSymbolComposition() {
        // The multi-symbol variant is used by the row's "Layers" feature.
        let icon = IconRenderer.makeIcon(
            symbolNames: ["music.note", "play.fill"],
            tint: .white,
            folderTint: .systemPurple
        )
        XCTAssertNotNil(icon, "Multi-symbol composition should produce an icon")
    }

    func testRepresentationSizesAreSane() {
        let sizes = IconRenderer.representationSizes
        XCTAssertFalse(sizes.isEmpty)
        XCTAssertTrue(sizes.contains(16), "Should include 16pt for Finder list view")
        XCTAssertTrue(sizes.contains(512), "Should include 512pt for Retina Finder")
        for s in sizes {
            XCTAssertGreaterThan(s, 0, "All sizes should be positive")
        }
    }
}
