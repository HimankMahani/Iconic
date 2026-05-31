//
//  FolderTypeDetector.swift
//  Iconic
//
//  Detects special folder types by analyzing their contents.
//  Fast marker-file checks for git repos, Xcode projects, Node.js, Python,
//  Docker, and media folders.
//

import Foundation

struct FolderTypeDetector {

    /// Detects the folder type by checking for specific marker files/patterns.
    /// Returns nil if no special type is detected.
    /// Designed to be fast: only checks for specific marker files, no full enumeration.
    static func detectType(at url: URL) -> String? {
        let fm = FileManager.default

        // Helper to check if a file exists in the folder
        func exists(_ name: String) -> Bool {
            fm.fileExists(atPath: url.appendingPathComponent(name).path)
        }

        // Git repository
        if exists(".git") {
            return "arrow.triangle.branch"
        }

        // Xcode project
        if hasFileWithExtension(at: url, extension: "xcodeproj") {
            return "hammer.fill"
        }

        // Node.js project
        if exists("package.json") {
            return "cube.fill"
        }

        // Python project
        if exists("requirements.txt") || exists("setup.py") || exists("pyproject.toml") {
            return "chevron.left.forwardslash.chevron.right"
        }

        // Docker project
        if exists("Dockerfile") || exists("docker-compose.yml") || exists("docker-compose.yaml") {
            return "shippingbox.fill"
        }

        // Media folders (check file composition)
        if let mediaSymbol = detectMediaFolder(at: url) {
            return mediaSymbol
        }

        return nil
    }

    /// Checks if a folder contains files with a specific extension.
    private static func hasFileWithExtension(at url: URL, extension ext: String) -> Bool {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        ) else {
            return false
        }

        return contents.contains { $0.pathExtension.lowercased() == ext.lowercased() }
    }

    /// Detects photo or video folders by sampling up to 20 files.
    /// Returns appropriate symbol if folder is predominantly one media type.
    private static func detectMediaFolder(at url: URL) -> String? {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        ) else {
            return nil
        }

        // Filter to files only (not subdirectories)
        let files = contents.filter { url in
            guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey]),
                  let isDir = values.isDirectory else {
                return false
            }
            return !isDir
        }

        // Need at least 5 files to make a determination
        guard files.count >= 5 else { return nil }

        // Sample up to 20 files for performance
        let sampled = Array(files.prefix(20))

        let photoExtensions: Set<String> = ["jpg", "jpeg", "png", "heic", "heif", "gif", "bmp", "tiff", "tif", "webp", "raw", "cr2", "nef", "arw"]
        let videoExtensions: Set<String> = ["mp4", "mov", "avi", "mkv", "m4v", "wmv", "flv", "webm", "mpeg", "mpg", "3gp"]

        var photoCount = 0
        var videoCount = 0

        for file in sampled {
            let ext = file.pathExtension.lowercased()
            if photoExtensions.contains(ext) {
                photoCount += 1
            } else if videoExtensions.contains(ext) {
                videoCount += 1
            }
        }

        let totalMedia = photoCount + videoCount
        guard totalMedia >= 3 else { return nil }

        // If 70% or more are photos
        if Double(photoCount) / Double(sampled.count) >= 0.7 {
            return "photo.stack"
        }

        // If 70% or more are videos
        if Double(videoCount) / Double(sampled.count) >= 0.7 {
            return "film.stack.fill"
        }

        return nil
    }
}
