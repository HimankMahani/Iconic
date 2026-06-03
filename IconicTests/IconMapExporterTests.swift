//
//  IconMapExporterTests.swift
//  IconicTests
//
//  Tests for IconMapExporter JSON/CSV/Markdown export and round-trip fidelity.
//

import XCTest
@testable import Iconic

final class IconMapExporterTests: XCTestCase {

    // MARK: - Helpers

    private func makeEntry(
        path: String = "/tmp/Test",
        name: String = "Test",
        symbol: String = "folder.fill",
        symbolColorHex: String? = nil,
        folderColorHex: String? = nil,
        status: String = "pending"
    ) -> IconMapEntry {
        IconMapEntry(
            path: path,
            name: name,
            symbol: symbol,
            symbolColorHex: symbolColorHex,
            folderColorHex: folderColorHex,
            status: status
        )
    }

    // MARK: - testExportEmptyMapping

    func testExportEmptyMappingJSON() {
        let data = IconMapExporter.export([], as: .json)
        XCTAssertNotNil(data)

        let decoded = try? JSONDecoder().decode([IconMapEntry].self, from: data!)
        XCTAssertNotNil(decoded)
        XCTAssertTrue(decoded!.isEmpty, "Decoded empty array should have zero elements")
    }

    func testExportEmptyMappingCSV() {
        let data = IconMapExporter.export([], as: .csv)
        XCTAssertNotNil(data)

        let csv = String(data: data!, encoding: .utf8)!
        let lines = csv.split(separator: "\n")
        XCTAssertEqual(lines.count, 1, "Empty CSV should only contain the header row")
    }

    func testExportEmptyMappingMarkdown() {
        let data = IconMapExporter.export([], as: .markdown)
        XCTAssertNotNil(data)

        let md = String(data: data!, encoding: .utf8)!
        XCTAssertTrue(md.contains("Total folders: 0"))
    }

    // MARK: - testImportValidJSON

    func testImportValidJSON() {
        let entry = makeEntry(path: "/Users/test/Documents", name: "Documents", symbol: "doc.fill")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try! encoder.encode([entry])

        let decoded = try? JSONDecoder().decode([IconMapEntry].self, from: data)
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded!.count, 1)
        XCTAssertEqual(decoded![0].path, "/Users/test/Documents")
        XCTAssertEqual(decoded![0].name, "Documents")
        XCTAssertEqual(decoded![0].symbol, "doc.fill")
    }

    func testImportValidJSONWithColors() {
        let entry = makeEntry(
            symbolColorHex: "#FF0000",
            folderColorHex: "#00FF00",
            status: "applied"
        )
        let encoder = JSONEncoder()
        let data = try! encoder.encode([entry])

        let decoded = try! JSONDecoder().decode([IconMapEntry].self, from: data)
        XCTAssertEqual(decoded[0].symbolColorHex, "#FF0000")
        XCTAssertEqual(decoded[0].folderColorHex, "#00FF00")
        XCTAssertEqual(decoded[0].status, "applied")
    }

    // MARK: - testImportInvalidJSON

    func testImportInvalidJSON() {
        let garbage = "this is not json".data(using: .utf8)!
        let decoded = try? JSONDecoder().decode([IconMapEntry].self, from: garbage)
        XCTAssertNil(decoded, "Decoding garbage JSON should return nil")
    }

    func testImportWrongStructureJSON() {
        let wrong = "[{\"onlyName\": \"hello\"}]".data(using: .utf8)!
        let decoded = try? JSONDecoder().decode([IconMapEntry].self, from: wrong)
        XCTAssertNil(decoded, "Decoding JSON with wrong keys should fail")
    }

    // MARK: - testRoundTrip

    func testRoundTripJSON() {
        let entries = [
            makeEntry(path: "/a", name: "A", symbol: "star.fill", status: "applied"),
            makeEntry(path: "/b", name: "B", symbol: "heart.fill", symbolColorHex: "#ABCDEF", status: "pending"),
            makeEntry(path: "/c", name: "C", symbol: "folder.fill", folderColorHex: "#123456", status: "restored")
        ]

        guard let data = IconMapExporter.export(entries, as: .json) else {
            XCTFail("Export returned nil")
            return
        }

        let decoded = try? JSONDecoder().decode([IconMapEntry].self, from: data)
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded!.count, entries.count)

        for (original, roundTripped) in zip(entries, decoded!) {
            XCTAssertEqual(original.path, roundTripped.path)
            XCTAssertEqual(original.name, roundTripped.name)
            XCTAssertEqual(original.symbol, roundTripped.symbol)
            XCTAssertEqual(original.symbolColorHex, roundTripped.symbolColorHex)
            XCTAssertEqual(original.folderColorHex, roundTripped.folderColorHex)
            XCTAssertEqual(original.status, roundTripped.status)
        }
    }

    func testRoundTripSingleEntry() {
        let entry = makeEntry(
            path: "/Projects/MyApp",
            name: "MyApp",
            symbol: "hammer.fill",
            symbolColorHex: "#FF5733",
            folderColorHex: "#33FF57",
            status: "applied"
        )

        let data = IconMapExporter.export([entry], as: .json)!
        let decoded = try! JSONDecoder().decode([IconMapEntry].self, from: data)

        XCTAssertEqual(decoded.first?.path, entry.path)
        XCTAssertEqual(decoded.first?.name, entry.name)
        XCTAssertEqual(decoded.first?.symbol, entry.symbol)
        XCTAssertEqual(decoded.first?.symbolColorHex, entry.symbolColorHex)
        XCTAssertEqual(decoded.first?.folderColorHex, entry.folderColorHex)
        XCTAssertEqual(decoded.first?.status, entry.status)
    }

    // MARK: - testVersionField (tests encoding/decoding completeness)

    func testExportJSONIsDecodable() {
        let entries = [
            makeEntry(status: "pending"),
            makeEntry(status: "applying"),
            makeEntry(status: "applied"),
            makeEntry(status: "restored"),
            makeEntry(status: "failed: permission denied")
        ]

        let data = IconMapExporter.export(entries, as: .json)!
        let decoded = try! JSONDecoder().decode([IconMapEntry].self, from: data)
        XCTAssertEqual(decoded.count, 5)
        XCTAssertEqual(decoded[0].status, "pending")
        XCTAssertEqual(decoded[1].status, "applying")
        XCTAssertEqual(decoded[2].status, "applied")
        XCTAssertEqual(decoded[3].status, "restored")
        XCTAssertEqual(decoded[4].status, "failed: permission denied")
    }

    func testExportFormatJSONIsPrettyPrinted() {
        let data = IconMapExporter.export([makeEntry()], as: .json)!
        let json = String(data: data, encoding: .utf8)!
        XCTAssertTrue(json.contains("\n"), "Pretty-printed JSON should contain newlines")
        XCTAssertTrue(json.contains("  "), "Pretty-printed JSON should contain indentation")
    }

    func testExportFormatCSVContainsHeader() {
        let data = IconMapExporter.export([makeEntry()], as: .csv)!
        let csv = String(data: data, encoding: .utf8)!
        let header = csv.split(separator: "\n").first!
        XCTAssertTrue(header.toString().contains("Path"))
        XCTAssertTrue(header.toString().contains("Name"))
        XCTAssertTrue(header.toString().contains("Symbol"))
        XCTAssertTrue(header.toString().contains("Status"))
    }

    func testExportFormatMarkdownContainsTable() {
        let data = IconMapExporter.export([makeEntry()], as: .markdown)!
        let md = String(data: data, encoding: .utf8)!
        XCTAssertTrue(md.contains("| Folder |"))
        XCTAssertTrue(md.contains("| Symbol |"))
        XCTAssertTrue(md.contains("`folder.fill`"))
    }

    func testExportNilForEmptyJSONDoesNotCrash() {
        let data = IconMapExporter.export([], as: .json)
        XCTAssertNotNil(data)
    }
}

private extension Substring {
    func toString() -> String { String(self) }
}
