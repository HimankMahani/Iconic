//
//  ColorPaletteTests.swift
//  IconicTests
//
//  Tests for the automatic color assignment pipeline: category detection,
//  determinism for repeated names, and color variety across adjacent folders.
//

import XCTest
import AppKit
@testable import Iconic

final class ColorPaletteTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Make sure seasonal theme is off so category-based assignment is deterministic.
        SeasonalThemeStore.isEnabled = false
    }

    override func tearDown() {
        SeasonalThemeStore.isEnabled = false
        super.tearDown()
    }

    // MARK: - Category mapping

    func testCodeFolderResolvesToCodePalette() {
        let color = ColorPalette.assignColor(for: "my-code-project")
        let codeColors = ColorPalette.palettes["code"]!
        XCTAssertTrue(
            codeColors.contains(where: { isClose(color, $0) }),
            "Expected a color from the 'code' palette for 'my-code-project'"
        )
    }

    func testMusicFolderResolvesToMusicPalette() {
        let color = ColorPalette.assignColor(for: "My Music Library")
        let musicColors = ColorPalette.palettes["music"]!
        XCTAssertTrue(
            musicColors.contains(where: { isClose(color, $0) }),
            "Expected a color from the 'music' palette for 'My Music Library'"
        )
    }

    func testUnknownCategoryUsesDefaultPalette() {
        let color = ColorPalette.assignColor(for: "zxqvbnm_random_xyz_42")
        let defaultColors = ColorPalette.palettes["default"]!
        XCTAssertTrue(
            defaultColors.contains(where: { isClose(color, $0) }),
            "Expected a color from the 'default' palette for an unknown category"
        )
    }

    // MARK: - Determinism

    func testSameNameSameColor() {
        let c1 = ColorPalette.assignColor(for: "Documents")
        let c2 = ColorPalette.assignColor(for: "Documents")
        let c3 = ColorPalette.assignColor(for: "Documents")
        XCTAssertTrue(isClose(c1, c2))
        XCTAssertTrue(isClose(c2, c3))
    }

    // MARK: - Variety

    func testAssignColorsAvoidsAdjacentSimilarity() {
        // 20 random-ish names from different categories should not all collide
        // on the same RGB triplet.
        let names = (0..<20).map { "folder-\($0)-\(["a","b","c","d","e","f","g","h"][$0 % 8])" }
        let assignments = ColorPalette.assignColors(for: names)
        XCTAssertEqual(assignments.count, names.count)

        // Count unique colors; should be at least 2 for a varied palette.
        let uniqueColors = Set(assignments.values.map { rgbKey($0) })
        XCTAssertGreaterThan(
            uniqueColors.count, 1,
            "Expected varied colors across 20 folders, got \(uniqueColors.count) unique"
        )
    }

    // MARK: - Season

    func testSeasonComputation() {
        XCTAssertEqual(Season.current(date: dateWith(month: 4)), .spring)
        XCTAssertEqual(Season.current(date: dateWith(month: 7)), .summer)
        XCTAssertEqual(Season.current(date: dateWith(month: 10)), .autumn)
        XCTAssertEqual(Season.current(date: dateWith(month: 1)), .winter)
        XCTAssertEqual(Season.current(date: dateWith(month: 12)), .winter)
    }

    // MARK: - Helpers

    private func isClose(_ a: NSColor, _ b: NSColor) -> Bool {
        let threshold: CGFloat = 0.01
        guard let a = a.usingColorSpace(.deviceRGB),
              let b = b.usingColorSpace(.deviceRGB) else { return false }
        return abs(a.redComponent - b.redComponent) < threshold
            && abs(a.greenComponent - b.greenComponent) < threshold
            && abs(a.blueComponent - b.blueComponent) < threshold
    }

    private func rgbKey(_ color: NSColor) -> String {
        guard let c = color.usingColorSpace(.deviceRGB) else { return "" }
        return String(format: "%.2f,%.2f,%.2f", c.redComponent, c.greenComponent, c.blueComponent)
    }

    private func dateWith(month: Int) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = month
        components.day = 15
        return Calendar(identifier: .gregorian).date(from: components) ?? Date()
    }
}
