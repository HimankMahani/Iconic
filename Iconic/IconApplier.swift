//
//  IconApplier.swift
//  Iconic
//
//  Thin wrapper around NSWorkspace.setIcon. Applying nil restores the default.
//

import AppKit

enum IconApplyError: LocalizedError {
    case setIconReturnedFalse(URL)
    case missingPath(URL)

    var errorDescription: String? {
        switch self {
        case .setIconReturnedFalse(let url):
            return "Couldn't change icon for “\(url.lastPathComponent)”. The folder may be SIP-protected or you don't have write permission."
        case .missingPath(let url):
            return "Folder no longer exists at “\(url.path)”."
        }
    }
}

struct IconApplier {

    /// Applies `icon` to `folder`. Pass `nil` to restore the default folder icon.
    /// Throws `IconApplyError` if the folder is SIP-protected or unwritable.
    static func apply(_ icon: NSImage?, to folder: URL) throws {
        guard FileManager.default.fileExists(atPath: folder.path) else {
            throw IconApplyError.missingPath(folder)
        }
        let ok = NSWorkspace.shared.setIcon(icon, forFile: folder.path, options: [])
        if !ok {
            throw IconApplyError.setIconReturnedFalse(folder)
        }
    }

    /// Convenience: resets the icon to the system default.
    static func restoreDefault(_ folder: URL) throws {
        try apply(nil, to: folder)
    }

    /// Returns true if `folder` already has a custom icon set (via Icon\r resource fork
    /// or extended attribute). Best-effort: checks for the canonical Icon\r file inside
    /// the folder and the com.apple.FinderInfo extended attribute.
    static func hasCustomIcon(_ folder: URL) -> Bool {
        // Check for Icon\r file inside the folder (resource-fork style custom icon)
        let iconPath = folder.appendingPathComponent("Icon\r").path
        if FileManager.default.fileExists(atPath: iconPath) {
            return true
        }
        // Check FinderInfo xattr — the kHasCustomIcon flag is set in byte 8.
        let path = folder.path
        let attrName = "com.apple.FinderInfo"
        let bufferSize = getxattr(path, attrName, nil, 0, 0, 0)
        if bufferSize <= 0 { return false }
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        let read = getxattr(path, attrName, &buffer, bufferSize, 0, 0)
        guard read >= 9 else { return false }
        // The "kHasCustomIcon" Finder flag is bit 10 of the high word at offset 8 (big-endian).
        // Byte 8 is the high byte of the flags word; bit 2 (0x04) of that byte = kHasCustomIcon.
        return (buffer[8] & 0x04) != 0
    }
}
