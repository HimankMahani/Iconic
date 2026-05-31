//
//  FolderWatcher.swift
//  Iconic
//
//  Monitors a folder for new subdirectories using FSEvents.
//

import Foundation
import AppKit

final class FolderWatcher {
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

        self.watchedURL = url
        self.callback = callback

        // Build initial snapshot of existing subfolders
        queue.async { [weak self] in
            guard let self = self else { return }
            self.knownSubfolders = self.scanSubfolders(at: url)
        }

        // Create FSEventStream
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let pathsToWatch = [url.path] as CFArray
        let flags = UInt32(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents)

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
            0.5, // latency in seconds
            flags
        ) else {
            return
        }

        self.eventStream = stream

        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
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

    private func handleEvents(numEvents: Int, eventPaths: UnsafeMutableRawPointer, eventFlags: UnsafePointer<FSEventStreamEventFlags>) {
        guard let watchedURL = watchedURL else { return }

        let paths = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as! [String]

        for i in 0..<numEvents {
            let path = paths[i]
            let flags = eventFlags[i]

            // Check if this is a directory creation or modification
            let isDirectory = (flags & UInt32(kFSEventStreamEventFlagItemIsDir)) != 0
            let isCreated = (flags & UInt32(kFSEventStreamEventFlagItemCreated)) != 0

            guard isDirectory else { continue }

            let url = URL(fileURLWithPath: path)

            // Only process direct children of the watched folder
            guard url.deletingLastPathComponent().path == watchedURL.path else { continue }

            // Check if this is a new folder we haven't seen before
            let folderPath = url.path
            if isCreated || !knownSubfolders.contains(folderPath) {
                knownSubfolders.insert(folderPath)

                // Verify it still exists and is a directory
                var isDir: ObjCBool = false
                guard FileManager.default.fileExists(atPath: folderPath, isDirectory: &isDir),
                      isDir.boolValue else { continue }

                // Call the callback on the main queue
                if let callback = callback {
                    DispatchQueue.main.async {
                        callback(url)
                    }
                }
            }
        }
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
                result.insert(fileURL.path)
            }
        }

        return result
    }

    deinit {
        stop()
    }
}
