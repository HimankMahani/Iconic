//
//  FolderScanner.swift
//  Iconic
//
//  Async recursive enumeration of subdirectories under a root URL.
//  Skips hidden folders, packages, and SIP-protected paths gracefully.
//

import Foundation

struct FolderScanner {

    struct Options {
        var includeRoot: Bool = true
        var skipHidden: Bool = true
        var skipPackages: Bool = true
        var maxDepth: Int = 8
        /// Folder names (or glob patterns) to skip entirely. Matched against
        /// the leaf name only, not the full path. Empty = no exclusions.
        var excludePatterns: [String] = []
    }

    /// Enumerates subdirectories under `root` off the main thread.
    /// Errors on individual entries are swallowed (permission-denied, etc.)
    /// and that branch is skipped rather than aborting the whole scan.
    /// `progress` is called from a background queue with the running total
    /// and the most recent folder URL — throttle on the UI side as needed.
    static func scan(
        _ root: URL,
        options: Options = .init(),
        progress: (@Sendable (Int, URL) -> Void)? = nil
    ) async -> [URL] {
        await Task.detached(priority: .userInitiated) {
            collect(root: root, options: options, progress: progress)
        }.value
    }

    private nonisolated static func collect(
        root: URL,
        options: Options,
        progress: (@Sendable (Int, URL) -> Void)?
    ) -> [URL] {
        var results: [URL] = []
        if options.includeRoot {
            results.append(root)
            progress?(results.count, root)
        }

        let keys: [URLResourceKey] = [
            .isDirectoryKey,
            .isHiddenKey,
            .isPackageKey,
            .isSymbolicLinkKey
        ]

        var stack: [(url: URL, depth: Int)] = [(root, 0)]
        let fm = FileManager.default
        let excludes = options.excludePatterns

        while let (current, depth) = stack.popLast() {
            if depth >= options.maxDepth { continue }

            let children: [URL]
            do {
                children = try fm.contentsOfDirectory(
                    at: current,
                    includingPropertiesForKeys: keys,
                    options: [.skipsSubdirectoryDescendants]
                )
            } catch {
                // Permission denied / SIP / unreadable — skip this branch.
                continue
            }

            for child in children {
                guard let values = try? child.resourceValues(forKeys: Set(keys)) else {
                    continue
                }
                if values.isSymbolicLink == true { continue }
                if values.isDirectory != true { continue }
                if options.skipHidden, values.isHidden == true { continue }
                if options.skipPackages, values.isPackage == true { continue }
                if child.lastPathComponent.hasPrefix(".") { continue }
                if !excludes.isEmpty,
                   ExcludePatternsStore.matches(child.lastPathComponent, patterns: excludes) {
                    continue
                }

                results.append(child)
                progress?(results.count, child)
                stack.append((child, depth + 1))
            }
        }

        return results
    }
}
