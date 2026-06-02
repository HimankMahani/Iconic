//
// SPDX-License-Identifier: MIT
//  FolderWatcher.swift
//  Iconic
//
//  Monitors a folder for new subdirectories using FSEvents.
//

import Foundation
import AppKit
import os.log

final class FolderWatcher {
    private static let log = OSLog(subsystem: "app.iconic.Iconic", category: "FolderWatcher")

    private var eventStream: FSEventStreamRef?
    private var callback: ((URL) -> Void)?
    private var watchedURL: URL?
    private var knownSubfolders: Set<String> = []
    private let queue = DispatchQueue(label: "com.iconic.folderwatcher", qos: .userInitiated)

    /// Start watching a folder for new subdirectories.
    /// - Parameters:
    ///   - url: The folder to watch
    ///   - callback: Called on the main queue when a new subfolder is detected
    func start(watching url: URL, callback: @escaping (URL) -> Void) {
        stop()

        // Resolve symlinks so the path we hold matches what FSEvents reports.
        // Without this, locations like `/tmp` or `/var` (symlinks to /private/...)
        // never match incoming event paths and the watcher silently does nothing.
        let resolvedURL = URL(fileURLWithPath: url.path).resolvingSymlinksInPath()

        self.watchedURL = resolvedURL
        self.callback = callback

        // Build the initial snapshot SYNCHRONOUSLY before starting the stream.
        // A previous async dispatch left a race window where events could fire
        // against an empty `knownSubfolders` set, causing pre-existing folders
        // to be reported as new.
        self.knownSubfolders = scanSubfolders(at: resolvedURL)

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let pathsToWatch = [resolvedURL.path] as CFArray
        // NoDefer makes the first event in a quiet period fire immediately
        // (instead of waiting the full latency), which matters for the common
        // case where the user creates a single folder.
        let flags = UInt32(
            kFSEventStreamCreateFlagUseCFTypes
            | kFSEventStreamCreateFlagFileEvents
            | kFSEventStreamCreateFlagNoDefer
        )

        guard let stream = FSEventStreamCreate(
            nil,
            { (streamRef, contextInfo, numEvents, eventPaths, eventFlags, eventIds) in
                guard let contextInfo = contextInfo else { return }
                let watcher = Unmanaged<FolderWatcher>.fromOpaque(contextInfo).takeUnretainedValue()
                watcher.handleEvents(numEvents: numEvents, eventPaths: eventPaths, eventFlags: eventFlags)
            },
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5,
            flags
        ) else {
            os_log("FSEventStreamCreate failed for %{public}@", log: Self.log, type: .error, resolvedURL.path)
            return
        }

        self.eventStream = stream

        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)

        os_log("Watching %{public}@ (%{public}d existing subfolders)",
               log: Self.log, type: .info, resolvedURL.path, knownSubfolders.count)
    }

    /// Stop watching for folder changes.
    func stop() {
        guard let stream = eventStream else { return }

        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)

        eventStream = nil
        callback = nil
        watchedURL = nil
        knownSubfolders.removeAll()
    }

    private func handleEvents(numEvents: Int,
                              eventPaths: UnsafeMutableRawPointer,
                              eventFlags: UnsafePointer<FSEventStreamEventFlags>) {
        guard let watchedURL = watchedURL else { return }
        let watchedPath = watchedURL.path

        let paths = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as! [String]

        for i in 0..<numEvents {
            let path = paths[i]
            let flags = eventFlags[i]

            // Kernel asks us to rescan — happens under burst load. Without
            // handling this, folders created during the burst are dropped.
            if (flags & UInt32(kFSEventStreamEventFlagMustScanSubDirs)) != 0 {
                handleMustScan()
                continue
            }

            let isDirectory = (flags & UInt32(kFSEventStreamEventFlagItemIsDir)) != 0
            guard isDirectory else { continue }

            // Resolve symlinks on the event path too, then take the canonical
            // form so both sides of the parent equality check are normalized.
            let resolved = URL(fileURLWithPath: path).resolvingSymlinksInPath()
            let folderPath = resolved.path

            // Only direct children of the watched folder.
            guard resolved.deletingLastPathComponent().path == watchedPath else { continue }

            // Confirm it still exists (rapid create+delete shows up otherwise).
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: folderPath, isDirectory: &isDir),
                  isDir.boolValue else { continue }

            // Use set membership as the sole source of truth for "new". The
            // Created flag is unreliable: FSEvents coalesces flags across
            // multiple events for the same path, so it can persist after the
            // first delivery. Combining it with `||` re-fires the callback
            // and re-applies the icon every time the folder is touched.
            if !knownSubfolders.contains(folderPath) {
                knownSubfolders.insert(folderPath)
                fire(url: resolved)
            }
        }
    }

    /// Re-snapshot the watched directory and emit any folders we hadn't seen.
    /// Triggered by `kFSEventStreamEventFlagMustScanSubDirs`.
    private func handleMustScan() {
        guard let watchedURL = watchedURL else { return }
        let current = scanSubfolders(at: watchedURL)
        let newFolders = current.subtracting(knownSubfolders)
        knownSubfolders = current

        if !newFolders.isEmpty {
            os_log("MustScan rescue: %{public}d new folder(s) recovered",
                   log: Self.log, type: .info, newFolders.count)
        }

        for folderPath in newFolders {
            fire(url: URL(fileURLWithPath: folderPath))
        }
    }

    private func fire(url: URL) {
        guard let callback = callback else { return }
        DispatchQueue.main.async { callback(url) }
    }

    private func scanSubfolders(at url: URL) -> Set<String> {
        var result = Set<String>()

        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        ) else {
            return result
        }

        for case let fileURL as URL in enumerator {
            if let resourceValues = try? fileURL.resourceValues(forKeys: [.isDirectoryKey]),
               resourceValues.isDirectory == true {
                // Store resolved path so equality checks line up with event paths.
                result.insert(fileURL.resolvingSymlinksInPath().path)
            }
        }

        return result
    }

    deinit {
        stop()
    }
}
