//
// SPDX-License-Identifier: MIT
//  QuickLookPreviewRenderer.swift
//  Iconic
//
//  Renders a Finder-style preview composition (folder name + icon at multiple
//  sizes) for Quick Look. Used by ContentView's spacebar handler so the user
//  can preview a folder's icon at actual Finder sizes before applying it.
//

import AppKit

@MainActor
enum QuickLookPreviewRenderer {

    /// Renders a preview composition for a folder item and writes it as PNG
    /// to a temp file. Returns the file URL that Quick Look can display, or
    /// nil if the item has no preview image yet.
    static func makePreviewURL(for item: FolderItem) -> URL? {
        guard let icon = item.preview else { return nil }
        let image = renderComposition(item: item, icon: icon)
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }

        let dir = tempDirectory
        let fileURL = dir.appendingPathComponent("\(UUID().uuidString).png")
        do {
            try png.write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            return nil
        }
    }

    /// Stable temp directory; created on first use. Files are left to macOS
    /// to clean up — they're small and few.
    private static let tempDirectory: URL = {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("IconicQuickLook", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    // MARK: - Composition

    private static let canvasSize = NSSize(width: 640, height: 480)
    private static let sizeLadder: [CGFloat] = [16, 32, 64, 128, 256]

    private static func renderComposition(item: FolderItem, icon: NSImage) -> NSImage {
        let image = NSImage(size: canvasSize)
        image.lockFocus()

        // Background — subtle gradient for a Finder-ish feel
        let bg = NSGradient(
            colors: [
                NSColor(calibratedWhite: 0.98, alpha: 1.0),
                NSColor(calibratedWhite: 0.92, alpha: 1.0)
            ]
        )
        bg?.draw(in: NSRect(origin: .zero, size: canvasSize), angle: -90)

        // Folder name
        let nameAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 22, weight: .semibold),
            .foregroundColor: NSColor.labelColor
        ]
        let name = item.displayName as NSString
        let nameSize = name.size(withAttributes: nameAttr)
        let nameY = canvasSize.height - 44
        name.draw(at: NSPoint(
            x: (canvasSize.width - nameSize.width) / 2,
            y: nameY
        ), withAttributes: nameAttr)

        // Path (truncated middle, secondary label color)
        let path = item.url.deletingLastPathComponent().path
        let pathAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let pathStr = (path as NSString)
        let pathRect = NSRect(x: 40, y: nameY - 22, width: canvasSize.width - 80, height: 16)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byTruncatingMiddle
        var pathAttrs = pathAttr
        pathAttrs[.paragraphStyle] = paragraph
        pathStr.draw(in: pathRect, withAttributes: pathAttrs)

        // Large icon
        let largeSide: CGFloat = 220
        let largeRect = NSRect(
            x: (canvasSize.width - largeSide) / 2,
            y: nameY - 36 - largeSide,
            width: largeSide,
            height: largeSide
        )
        drawIcon(icon, in: largeRect)

        // Size ladder at the bottom
        let ladderY: CGFloat = 56
        let gap: CGFloat = 18
        let totalWidth = sizeLadder.reduce(0, +) + CGFloat(sizeLadder.count - 1) * gap
        var x = (canvasSize.width - totalWidth) / 2
        for side in sizeLadder {
            let rect = NSRect(x: x, y: ladderY, width: side, height: side)
            drawIcon(icon, in: rect)
            // Baseline under each size
            let label = "\(Int(side))pt" as NSString
            let labelAttr: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 9, weight: .medium),
                .foregroundColor: NSColor.tertiaryLabelColor
            ]
            let labelSize = label.size(withAttributes: labelAttr)
            label.draw(at: NSPoint(
                x: x + (side - labelSize.width) / 2,
                y: ladderY - 14
            ), withAttributes: labelAttr)
            x += side + gap
        }

        // "Preview at Finder sizes" caption above the ladder
        let caption = "Preview at Finder sizes" as NSString
        let captionAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let captionSize = caption.size(withAttributes: captionAttr)
        caption.draw(at: NSPoint(
            x: (canvasSize.width - captionSize.width) / 2,
            y: 18
        ), withAttributes: captionAttr)

        image.unlockFocus()
        return image
    }

    private static func drawIcon(_ icon: NSImage, in rect: NSRect) {
        icon.draw(
            in: rect,
            from: .zero,
            operation: .sourceOver,
            fraction: 1.0,
            respectFlipped: false,
            hints: [.interpolation: NSImageInterpolation.high]
        )
    }
}
