//
//  FolderItemTests.swift
//  IconicTests
//
//  Unit tests for FolderItem: initialization defaults, published properties,
//  static constants, and helper computed properties.
//

import XCTest
import AppKit
@testable import Iconic

@MainActor
final class FolderItemTests: XCTestCase {

    // MARK: - Initialization Defaults

    func testInitializationDefaults() {
        let url = URL(fileURLWithPath: "/tmp/TestFolder")
        let item = FolderItem(url: url, symbolName: "folder")

        XCTAssertEqual(item.symbolOpacity, FolderItem.defaultSymbolOpacity)
        XCTAssertEqual(item.symbolScale, FolderItem.defaultSymbolScale)
        XCTAssertEqual(item.symbolOffsetY, FolderItem.defaultSymbolOffsetY)
        XCTAssertNil(item.symbolColor)
        XCTAssertNil(item.folderColor)
        XCTAssertNil(item.customImage)
        XCTAssertNil(item.symbolGradientEnd)
        XCTAssertEqual(item.symbolNames, ["folder"])
    }

    func testInitializationWithColor() {
        let url = URL(fileURLWithPath: "/tmp/TestFolder")
        let color = NSColor.red
        let item = FolderItem(url: url, symbolName: "star", symbolColor: color)

        XCTAssertEqual(item.symbolName, "star")
        XCTAssertEqual(item.symbolColor, color)
    }

    func testInitializationWithMultipleSymbols() {
        let url = URL(fileURLWithPath: "/tmp/TestFolder")
        let item = FolderItem(url: url, symbolNames: ["star", "heart"])

        XCTAssertEqual(item.symbolNames, ["star", "heart"])
        XCTAssertEqual(item.symbolName, "star", "symbolName should return the first symbol")
    }

    // MARK: - Static Default Constants

    func testDefaultSymbolOpacity() {
        XCTAssertEqual(FolderItem.defaultSymbolOpacity, 1.0)
    }

    func testDefaultSymbolScale() {
        XCTAssertEqual(FolderItem.defaultSymbolScale, 1.0)
    }

    func testDefaultSymbolOffsetY() {
        XCTAssertEqual(FolderItem.defaultSymbolOffsetY, 0.0)
    }

    // MARK: - Computed Properties

    func testDisplayName() {
        let url = URL(fileURLWithPath: "/tmp/MyFolder")
        let item = FolderItem(url: url, symbolName: "folder")

        XCTAssertEqual(item.displayName, "MyFolder")
    }

    func testSymbolNameReturnsFirstSymbol() {
        let url = URL(fileURLWithPath: "/tmp/test")
        let item = FolderItem(url: url, symbolNames: ["star", "heart", "moon"])

        XCTAssertEqual(item.symbolName, "star")
    }

    func testSymbolNameReturnsEmptyForEmptyArray() {
        let url = URL(fileURLWithPath: "/tmp/test")
        let item = FolderItem(url: url, symbolNames: [])

        XCTAssertEqual(item.symbolName, "")
    }

    func testIsUnassignedDefaultFalse() {
        let url = URL(fileURLWithPath: "/tmp/test")
        let item = FolderItem(url: url, symbolName: "folder")

        XCTAssertFalse(item.isUnassigned, "matchSource should default to .localDictionary, not .unassigned")
    }

    func testUnassignedFactoryMethod() {
        let url = URL(fileURLWithPath: "/tmp/test")
        let item = FolderItem.unassigned(url: url)

        XCTAssertTrue(item.isUnassigned)
        XCTAssertEqual(item.symbolName, "")
        XCTAssertNil(item.symbolColor)
    }

    func testStatusDefaultPending() {
        let url = URL(fileURLWithPath: "/tmp/test")
        let item = FolderItem(url: url, symbolName: "folder")

        XCTAssertEqual(item.status, .pending)
    }

    func testHasChangesFalseWhenNoOriginalOrPreview() {
        let url = URL(fileURLWithPath: "/tmp/test")
        let item = FolderItem(url: url, symbolName: "folder")

        XCTAssertFalse(item.hasChanges, "Should be false when originalIcon and preview are nil")
    }

    func testIdIsUnique() {
        let url = URL(fileURLWithPath: "/tmp/test")
        let item1 = FolderItem(url: url, symbolName: "a")
        let item2 = FolderItem(url: url, symbolName: "a")

        XCTAssertNotEqual(item1.id, item2.id, "Each FolderItem should get a unique id")
    }
}
