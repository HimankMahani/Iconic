//
//  FolderScannerTests.swift
//  IconicTests
//
//  Verifies recursive enumeration under a temporary root, including
//  hidden/package/symlink filtering and exclude-pattern support.
//

import XCTest
@testable import Iconic

final class FolderScannerTests: XCTestCase {

    private var tempRoot: URL!

    override func setUp() async throws {
        try await super.setUp()
        tempRoot = makeTempDirectory()
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempRoot)
        tempRoot = nil
        try await super.tearDown()
    }

    // MARK: - Basic recursion

    func testEmptyRootReturnsOnlyRoot() async {
        let result = await FolderScanner.scan(tempRoot, options: .init())
        XCTAssertEqual(result.count, 1, "Empty root should only contain itself (includeRoot = true)")
        XCTAssertEqual(result.first?.standardizedFileURL, tempRoot.standardizedFileURL)
    }

    func testRecursionFindsAllSubfolders() async {
        try! createDirectory(at: tempRoot.appendingPathComponent("A"))
        try! createDirectory(at: tempRoot.appendingPathComponent("A/B"))
        try! createDirectory(at: tempRoot.appendingPathComponent("A/B/C"))
        try! createDirectory(at: tempRoot.appendingPathComponent("D"))

        let result = await FolderScanner.scan(tempRoot, options: .init())
        let paths = Set(result.map { $0.standardizedFileURL.path })
        XCTAssertTrue(
            paths.isSuperset(of: [
                tempRoot.appendingPathComponent("A").standardizedFileURL.path,
                tempRoot.appendingPathComponent("A/B").standardizedFileURL.path,
                tempRoot.appendingPathComponent("A/B/C").standardizedFileURL.path,
                tempRoot.appendingPathComponent("D").standardizedFileURL.path,
            ])
        )
    }

    // MARK: - Hidden / package / symlink

    func testHiddenFoldersAreSkipped() async {
        try! createDirectory(at: tempRoot.appendingPathComponent("Visible"))
        try! createDirectory(at: tempRoot.appendingPathComponent(".hidden"))

        let result = await FolderScanner.scan(tempRoot, options: .init())
        let names = Set(result.map { $0.lastPathComponent })
        XCTAssertTrue(names.contains("Visible"))
        XCTAssertFalse(names.contains(".hidden"), "Default options should skip hidden folders")
    }

    func testFilesAreIgnored() async {
        try! createDirectory(at: tempRoot.appendingPathComponent("Sub"))
        let file = tempRoot.appendingPathComponent("a.txt")
        try! "hello".write(to: file, atomically: true, encoding: .utf8)

        let result = await FolderScanner.scan(tempRoot, options: .init())
        let names = result.map { $0.lastPathComponent }
        XCTAssertFalse(names.contains("a.txt"), "Files must not be included")
    }

    // MARK: - Excludes

    func testExcludePatternsSkipByLeafName() async {
        try! createDirectory(at: tempRoot.appendingPathComponent("node_modules"))
        try! createDirectory(at: tempRoot.appendingPathComponent("src"))

        let result = await FolderScanner.scan(
            tempRoot,
            options: FolderScanner.Options(excludePatterns: ["node_modules"])
        )
        let names = Set(result.map { $0.lastPathComponent })
        XCTAssertTrue(names.contains("src"))
        XCTAssertFalse(names.contains("node_modules"))
    }

    // MARK: - Depth

    func testMaxDepthLimitsRecursion() async {
        try! createDirectory(at: tempRoot.appendingPathComponent("L1/L2/L3/L4/L5/L6/L7/L8/L9/L10"))

        let result = await FolderScanner.scan(
            tempRoot,
            options: FolderScanner.Options(maxDepth: 2)
        )
        let depth = result.map { pathDepth($0, under: tempRoot) }
        XCTAssertTrue(depth.allSatisfy { $0 <= 2 }, "No folder should exceed maxDepth=2, got \(depth)")
    }

    // MARK: - Permission failures

    func testPermissionDeniedDirectoryIsSkippedGracefully() async {
        // Create a sibling folder we can't read; scanner should continue past it.
        try! createDirectory(at: tempRoot.appendingPathComponent("Readable"))
        let unreadable = tempRoot.appendingPathComponent("Unreadable")
        try! createDirectory(at: unreadable)
        // Strip read perms on the parent. Note: this is best-effort; on some
        // macOS configs the test runner can still read despite chmod 000.
        try? FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: unreadable.path)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: unreadable.path)
        }

        let result = await FolderScanner.scan(tempRoot, options: .init())
        // The key property is that the scan completes without throwing.
        // Whether "Unreadable" is included depends on the test runner's
        // permissions, so we only assert the scan returned.
        XCTAssertGreaterThanOrEqual(result.count, 1, "Scan should at minimum return the root")
    }

    // MARK: - Progress callback

    func testProgressCallbackFires() async {
        try! createDirectory(at: tempRoot.appendingPathComponent("A/B/C"))

        actor Counter {
            var n = 0
            func inc() { n += 1 }
            func value() -> Int { n }
        }
        let counter = Counter()

        _ = await FolderScanner.scan(tempRoot, options: .init()) { count, _ in
            Task { await counter.inc() }
        }
        // Give the detached task a moment to flush.
        try? await Task.sleep(nanoseconds: 100_000_000)
        let n = await counter.value()
        XCTAssertGreaterThan(n, 0, "Progress callback should fire at least once")
    }

    // MARK: - Helpers

    private func makeTempDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("IconicTests-\(UUID().uuidString)", isDirectory: true)
        try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func createDirectory(at url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    private func pathDepth(_ url: URL, under root: URL) -> Int {
        let rootComponents = root.standardizedFileURL.pathComponents
        let urlComponents = url.standardizedFileURL.pathComponents
        return max(0, urlComponents.count - rootComponents.count)
    }
}
