//
//  FolderTypeDetectorTests.swift
//  IconicTests
//
//  Tests for FolderTypeDetector.detectType(at:) marker-file detection.
//  Creates temporary directories with known marker files/samples and
//  asserts the correct SF Symbol is returned.
//

import XCTest
@testable import Iconic

final class FolderTypeDetectorTests: XCTestCase {

    private let fm = FileManager.default
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = fm.temporaryDirectory.appendingPathComponent("FDTTest_\(UUID().uuidString)")
        try? fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? fm.removeItem(at: tempDir)
        super.tearDown()
    }

    /// Create a file inside tempDir (creating the dir first if needed).
    private func createMarker(_ name: String) {
        let url = tempDir.appendingPathComponent(name)
        fm.createFile(atPath: url.path, contents: Data())
    }

    /// Create a subdirectory inside tempDir with the given name and optional marker files.
    private func createFolder(
        named name: String,
        markers: [String] = [],
        files: [String] = []
    ) -> URL {
        let folder = tempDir.appendingPathComponent(name)
        try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
        for marker in markers {
            let url = folder.appendingPathComponent(marker)
            fm.createFile(atPath: url.path, contents: Data())
        }
        for file in files {
            let url = folder.appendingPathComponent(file)
            fm.createFile(atPath: url.path, contents: Data(repeating: 0, count: 100))
        }
        return folder
    }

    // MARK: - Development detection

    func testDetectDevelopmentFolderGit() {
        let folder = createFolder(named: "src", markers: [".git"])
        let result = FolderTypeDetector.detectType(at: folder)
        XCTAssertEqual(result, "arrow.triangle.branch", ".git → arrow.triangle.branch")
    }

    func testDetectDevelopmentFolderXcodeproj() {
        let folder = createFolder(named: "MyApp")
        // xcodeproj is a directory, so create it as a directory marker
        let xcodeproj = folder.appendingPathComponent("MyApp.xcodeproj")
        try? fm.createDirectory(at: xcodeproj, withIntermediateDirectories: true)
        let result = FolderTypeDetector.detectType(at: folder)
        XCTAssertEqual(result, "hammer.fill", ".xcodeproj → hammer.fill")
    }

    func testDetectDevelopmentFolderPackageJson() {
        let folder = createFolder(named: "src", markers: ["package.json"])
        let result = FolderTypeDetector.detectType(at: folder)
        XCTAssertEqual(result, "cube.fill", "package.json → cube.fill (Node.js)")
    }

    func testDetectDevelopmentFolderPython() {
        let folder = createFolder(named: "src", markers: ["requirements.txt"])
        let result = FolderTypeDetector.detectType(at: folder)
        XCTAssertEqual(result, "chevron.left.forwardslash.chevron.right", "requirements.txt → Python symbol")
    }

    func testDetectDevelopmentFolderDocker() {
        let folder = createFolder(named: "src", markers: ["Dockerfile"])
        let result = FolderTypeDetector.detectType(at: folder)
        XCTAssertEqual(result, "shippingbox.fill", "Dockerfile → shippingbox.fill")
    }

    func testDetectDevelopmentFolderDockerCompose() {
        let folder = createFolder(named: "src", markers: ["docker-compose.yml"])
        let result = FolderTypeDetector.detectType(at: folder)
        XCTAssertEqual(result, "shippingbox.fill", "docker-compose.yml → shippingbox.fill")
    }

    // MARK: - Design / media detection

    func testDetectDesignFolder() {
        // art folder with 5+ photo files triggers media detection
        let photos = (0..<6).map { "photo\($0).jpg" }
        let folder = createFolder(named: "art", files: photos)
        let result = FolderTypeDetector.detectType(at: folder)
        XCTAssertEqual(result, "photo.stack", "Folder with ≥70% jpg → photo.stack")
    }

    func testDetectMediaFolder() {
        let photos = (0..<10).map { "img\($0).png" }
        let folder = createFolder(named: "photos", files: photos)
        let result = FolderTypeDetector.detectType(at: folder)
        XCTAssertEqual(result, "photo.stack", "Folder with mostly png files → photo.stack")
    }

    func testDetectVideoFolder() {
        let videos = (0..<10).map { "clip\($0).mp4" }
        let folder = createFolder(named: "videos", files: videos)
        let result = FolderTypeDetector.detectType(at: folder)
        XCTAssertEqual(result, "film.stack.fill", "Folder with ≥70% mp4 → film.stack.fill")
    }

    func testDetectMediaFolderTooFewFiles() {
        // Only 3 files — detector requires ≥5 to determine media type
        let folder = createFolder(named: "small", files: ["a.jpg", "b.jpg", "c.jpg"])
        let result = FolderTypeDetector.detectType(at: folder)
        XCTAssertNil(result, "Fewer than 5 files should not trigger media detection")
    }

    // MARK: - Generic / empty detection

    func testDetectGenericFolder() {
        let folder = createFolder(named: "random")
        let result = FolderTypeDetector.detectType(at: folder)
        XCTAssertNil(result, "Empty folder → nil (generic)")
    }

    func testDetectGenericFolderWithUnrelatedFiles() {
        let folder = createFolder(named: "random", files: ["readme.txt", "notes.md", "data.csv"])
        let result = FolderTypeDetector.detectType(at: folder)
        XCTAssertNil(result, "Folder with non-marker, non-media files → nil")
    }

    // MARK: - Marker priority

    func testGitTakesPriorityOverXcodeproj() {
        let folder = createFolder(named: "mixed", markers: [".git"])
        let xcodeproj = folder.appendingPathComponent("App.xcodeproj")
        try? fm.createDirectory(at: xcodeproj, withIntermediateDirectories: true)

        let result = FolderTypeDetector.detectType(at: folder)
        XCTAssertEqual(result, "arrow.triangle.branch", ".git should take priority over .xcodeproj")
    }

    func testGitTakesPriorityOverPackageJson() {
        let folder = createFolder(named: "mixed", markers: [".git", "package.json"])
        let result = FolderTypeDetector.detectType(at: folder)
        XCTAssertEqual(result, "arrow.triangle.branch", ".git should take priority over package.json")
    }

    func testXcodeprojTakesPriorityOverPackageJson() {
        let folder = createFolder(named: "mixed", markers: ["package.json"])
        let xcodeproj = folder.appendingPathComponent("App.xcodeproj")
        try? fm.createDirectory(at: xcodeproj, withIntermediateDirectories: true)

        let result = FolderTypeDetector.detectType(at: folder)
        XCTAssertEqual(result, "hammer.fill", ".xcodeproj should take priority over package.json")
    }

    // MARK: - Nonexistent path

    func testDetectTypeNonexistentPath() {
        let url = tempDir.appendingPathComponent("does_not_exist_\(UUID().uuidString)")
        let result = FolderTypeDetector.detectType(at: url)
        XCTAssertNil(result, "Nonexistent path → nil")
    }
}
