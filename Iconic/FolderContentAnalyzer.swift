//
// SPDX-License-Identifier: MIT
//  FolderContentAnalyzer.swift
//  Iconic
//
//  Analyzes folder contents to provide context for AI matching.
//  Only runs when AI Content Analysis is enabled in settings.
//

import Foundation

struct FolderContentAnalyzer {

    /// Analysis result containing folder content information
    struct ContentAnalysis {
        let folderName: String
        let hasGitRepo: Bool
        let hasPackageJSON: Bool
        let hasXcodeProject: Bool
        let hasDockerfile: Bool
        let hasPythonProject: Bool
        let fileTypes: [String: Int] // extension → count
        let totalFiles: Int
        let totalSize: Int64
        let dominantFileType: String? // e.g., "photos", "videos", "code"

        /// Human-readable description for AI prompt
        var contextDescription: String {
            var parts: [String] = []

            // Project type markers
            if hasGitRepo {
                parts.append("Git repository")
            }
            if hasXcodeProject {
                parts.append("Xcode project")
            }
            if hasPackageJSON {
                parts.append("Node.js project")
            }
            if hasPythonProject {
                parts.append("Python project")
            }
            if hasDockerfile {
                parts.append("Docker project")
            }

            // File composition
            if let dominant = dominantFileType {
                parts.append("contains mostly \(dominant)")
            }

            // File count
            if totalFiles > 0 {
                parts.append("\(totalFiles) files")
            }

            // Size
            if totalSize > 0 {
                let sizeStr = ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
                parts.append(sizeStr)
            }

            // Top file types
            let topTypes = fileTypes.sorted { $0.value > $1.value }.prefix(3)
            if !topTypes.isEmpty {
                let typeStr = topTypes.map { ".\($0.key) (\($0.value))" }.joined(separator: ", ")
                parts.append("file types: \(typeStr)")
            }

            return parts.isEmpty ? "no specific content detected" : parts.joined(separator: ", ")
        }
    }

    /// Analyzes a folder's contents to provide context for AI matching.
    /// Fast analysis: only samples files, doesn't enumerate entire tree.
    static func analyze(_ url: URL) -> ContentAnalysis? {
        let fm = FileManager.default

        // Check if folder is accessible
        guard fm.fileExists(atPath: url.path) else { return nil }

        // Helper to check if a file exists
        func exists(_ name: String) -> Bool {
            fm.fileExists(atPath: url.appendingPathComponent(name).path)
        }

        // Check for project markers
        let hasGit = exists(".git")
        let hasPackageJSON = exists("package.json")
        let hasDockerfile = exists("Dockerfile") || exists("docker-compose.yml")
        let hasPython = exists("requirements.txt") || exists("setup.py") || exists("pyproject.toml")
        let hasXcode = hasFileWithExtension(at: url, extension: "xcodeproj")

        // Sample files (limit to 50 for performance)
        guard let contents = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        ) else {
            return ContentAnalysis(
                folderName: url.lastPathComponent,
                hasGitRepo: hasGit,
                hasPackageJSON: hasPackageJSON,
                hasXcodeProject: hasXcode,
                hasDockerfile: hasDockerfile,
                hasPythonProject: hasPython,
                fileTypes: [:],
                totalFiles: 0,
                totalSize: 0,
                dominantFileType: nil
            )
        }

        // Filter to files only
        let files = contents.filter { url in
            guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey]),
                  let isDir = values.isDirectory else {
                return false
            }
            return !isDir
        }

        // Sample up to 50 files
        let sampled = Array(files.prefix(50))

        // Count file types
        var fileTypes: [String: Int] = [:]
        var totalSize: Int64 = 0

        for file in sampled {
            let ext = file.pathExtension.lowercased()
            if !ext.isEmpty {
                fileTypes[ext, default: 0] += 1
            }

            if let values = try? file.resourceValues(forKeys: [.fileSizeKey]),
               let size = values.fileSize {
                totalSize += Int64(size)
            }
        }

        // Determine dominant file type
        let dominant = determineDominantType(fileTypes: fileTypes)

        return ContentAnalysis(
            folderName: url.lastPathComponent,
            hasGitRepo: hasGit,
            hasPackageJSON: hasPackageJSON,
            hasXcodeProject: hasXcode,
            hasDockerfile: hasDockerfile,
            hasPythonProject: hasPython,
            fileTypes: fileTypes,
            totalFiles: sampled.count,
            totalSize: totalSize,
            dominantFileType: dominant
        )
    }

    /// Determines the dominant content type based on file extensions
    private static func determineDominantType(fileTypes: [String: Int]) -> String? {
        guard !fileTypes.isEmpty else { return nil }

        let photoExtensions: Set<String> = ["jpg", "jpeg", "png", "heic", "heif", "gif", "bmp", "tiff", "raw", "cr2", "nef", "arw"]
        let videoExtensions: Set<String> = ["mp4", "mov", "avi", "mkv", "m4v", "wmv", "flv", "webm", "mpeg"]
        let audioExtensions: Set<String> = ["mp3", "wav", "aac", "flac", "m4a", "ogg", "wma"]
        let codeExtensions: Set<String> = ["swift", "js", "ts", "py", "java", "cpp", "c", "h", "go", "rs", "rb", "php"]
        let documentExtensions: Set<String> = ["pdf", "doc", "docx", "txt", "md", "rtf", "pages"]

        var photoCount = 0
        var videoCount = 0
        var audioCount = 0
        var codeCount = 0
        var documentCount = 0

        for (ext, count) in fileTypes {
            if photoExtensions.contains(ext) { photoCount += count }
            if videoExtensions.contains(ext) { videoCount += count }
            if audioExtensions.contains(ext) { audioCount += count }
            if codeExtensions.contains(ext) { codeCount += count }
            if documentExtensions.contains(ext) { documentCount += count }
        }

        let total = fileTypes.values.reduce(0, +)
        let threshold = Double(total) * 0.5 // 50% threshold

        if Double(photoCount) >= threshold { return "photos" }
        if Double(videoCount) >= threshold { return "videos" }
        if Double(audioCount) >= threshold { return "audio files" }
        if Double(codeCount) >= threshold { return "code files" }
        if Double(documentCount) >= threshold { return "documents" }

        return nil
    }

    /// Checks if a folder contains files with a specific extension
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
}

// MARK: - Settings Store

enum AIContentAnalysisStore {
    private static let key = "iconic.ai.contentAnalysis.enabled"

    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}
