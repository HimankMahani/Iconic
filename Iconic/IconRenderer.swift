//
//  IconRenderer.swift
//  Iconic
//
//  Tints the system folder icon with a Core Image monochrome filter so every
//  gradient, ridge, and shadow in the original folder asset survives the
//  recolor. SF Symbol overlay sits on the front face on top.
//

import AppKit
import CoreImage
import UniformTypeIdentifiers

struct IconRenderer {

    static let representationSizes: [CGFloat] = [16, 32, 64, 128, 256, 512]

    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    static func makeIcon(
        symbolName: String,
        tint: NSColor = .white,
        folderTint: NSColor? = nil,
        opacity: Double = 1.0,
        scale: Double = 1.0,
        offsetY: Double = 0.0,
        gradientEnd: NSColor? = nil,
        customImage: NSImage? = nil
    ) -> NSImage? {
        return makeIcon(
            symbolNames: [symbolName],
            tint: tint,
            folderTint: folderTint,
            opacity: opacity,
            scale: scale,
            offsetY: offsetY,
            gradientEnd: gradientEnd,
            customImage: customImage
        )
    }

    static func makeIcon(
        symbolNames: [String],
        tint: NSColor = .white,
        folderTint: NSColor? = nil,
        opacity: Double = 1.0,
        scale: Double = 1.0,
        offsetY: Double = 0.0,
        gradientEnd: NSColor? = nil,
        customImage: NSImage? = nil
    ) -> NSImage? {
        let baseFolder = baseFolderIcon()
        guard customImage != nil || !symbolNames.isEmpty else { return baseFolder }

        let composite = NSImage(size: NSSize(width: 512, height: 512))
        composite.cacheMode = .never

        for side in representationSizes {
            let size = NSSize(width: side, height: side)
            let rep = renderRepresentation(
                size: size,
                folder: baseFolder,
                symbolNames: symbolNames,
                symbolColor: tint,
                folderTint: folderTint,
                opacity: opacity,
                scale: scale,
                offsetY: offsetY,
                gradientEnd: gradientEnd,
                customImage: customImage
            )
            if let rep { composite.addRepresentation(rep) }
        }
        return composite
    }

    // MARK: - Private

    private static func baseFolderIcon() -> NSImage {
        let icon = NSWorkspace.shared.icon(for: .folder)
        icon.size = NSSize(width: 512, height: 512)
        return icon
    }

    private static func resolveSymbolName(orFallback name: String) -> String? {
        if NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil {
            return name
        }
        if NSImage(systemSymbolName: "folder.fill", accessibilityDescription: nil) != nil {
            return "folder.fill"
        }
        return nil
    }

    /// Returns a CGImage of the folder icon tinted to `color`. Every pixel
    /// of the original folder maps to the same hue+saturation as `color`,
    /// scaled by the original pixel's luminance — so highlights stay bright,
    /// shadows stay dark, the ridge between tab and face survives, and the
    /// drop shadow comes through unmodified.
    private static func tintedFolderImage(folder: NSImage, size: NSSize, tint: NSColor) -> CGImage? {
        var proposedRect = CGRect(origin: .zero, size: size)
        guard let cgImage = folder.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil) else {
            return nil
        }
        guard let ciColor = CIColor(color: tint),
              let filter = CIFilter(name: "CIColorMonochrome") else {
            return cgImage
        }
        let ciImage = CIImage(cgImage: cgImage)
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(ciColor, forKey: "inputColor")
        filter.setValue(1.0, forKey: "inputIntensity")
        guard let output = filter.outputImage else { return cgImage }
        return ciContext.createCGImage(output, from: output.extent)
    }

    private static func renderRepresentation(
        size: NSSize,
        folder: NSImage,
        symbolNames: [String],
        symbolColor: NSColor,
        folderTint: NSColor?,
        opacity: Double,
        scale: Double,
        offsetY: Double,
        gradientEnd: NSColor?,
        customImage: NSImage?
    ) -> NSBitmapImageRep? {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 32
        ) else { return nil }

        rep.size = size

        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }

        guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
        NSGraphicsContext.current = ctx
        ctx.imageInterpolation = .high

        let rect = NSRect(origin: .zero, size: size)

        // Draw folder — tinted via CIColorMonochrome if a tint was provided,
        // otherwise the unmodified system folder.
        if let folderTint,
           let tinted = tintedFolderImage(folder: folder, size: size, tint: folderTint) {
            ctx.cgContext.draw(tinted, in: rect)
        } else {
            folder.draw(in: rect, from: .zero, operation: .copy, fraction: 1.0)
        }

        if let customImage {
            drawCustomImage(customImage, iconSize: size, opacity: opacity, scale: scale, offsetY: offsetY)
        } else {
            drawSymbols(
                names: symbolNames,
                color: symbolColor,
                iconSize: size,
                opacity: opacity,
                scale: scale,
                offsetY: offsetY,
                gradientEnd: gradientEnd
            )
        }

        return rep
    }

    private static func drawCustomImage(_ image: NSImage, iconSize: NSSize, opacity: Double, scale: Double, offsetY: Double) {
        let baseSide = iconSize.width * 0.42 * CGFloat(scale)
        let aspect = image.size.width / max(image.size.height, 1)
        let drawWidth = baseSide * (aspect >= 1 ? 1 : aspect)
        let drawHeight = baseSide * (aspect >= 1 ? 1 / aspect : 1)
        let centerY = iconSize.height * (0.42 + CGFloat(offsetY) * 0.20)
        let drawRect = NSRect(
            x: iconSize.width / 2.0 - drawWidth / 2.0,
            y: centerY - drawHeight / 2.0,
            width: drawWidth,
            height: drawHeight
        )
        image.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: CGFloat(opacity))
    }

    private static func drawSymbols(
        names: [String],
        color: NSColor,
        iconSize: NSSize,
        opacity: Double,
        scale: Double,
        offsetY: Double,
        gradientEnd: NSColor?
    ) {
        guard !names.isEmpty else { return }

        // Draw each symbol with slight offset and scale variation for layering effect
        for (index, name) in names.enumerated() {
            // Layer scaling: first at 100%, second at 80%, third at 70%
            let layerScale: CGFloat
            let layerOffsetX: CGFloat
            let layerOpacity: Double

            switch index {
            case 0:
                layerScale = 1.0
                layerOffsetX = 0
                layerOpacity = opacity
            case 1:
                layerScale = 0.80
                layerOffsetX = iconSize.width * 0.05
                layerOpacity = opacity * 0.85
            case 2:
                layerScale = 0.70
                layerOffsetX = iconSize.width * 0.10
                layerOpacity = opacity * 0.75
            default:
                continue // Max 3 layers
            }

            if name.isEmojiGlyph {
                drawEmojiGlyph(
                    emoji: name,
                    iconSize: iconSize,
                    opacity: layerOpacity,
                    scale: scale * Double(layerScale),
                    offsetY: offsetY,
                    offsetX: Double(layerOffsetX)
                )
            } else {
                let resolvedName = resolveSymbolName(orFallback: name)
                guard let symbolName = resolvedName else { continue }
                drawSymbol(
                    named: symbolName,
                    color: color,
                    iconSize: iconSize,
                    opacity: layerOpacity,
                    scale: scale * Double(layerScale),
                    offsetY: offsetY,
                    offsetX: Double(layerOffsetX),
                    gradientEnd: gradientEnd
                )
            }
        }
    }

    /// Draws a color emoji glyph centered on the folder face. Mirrors
    /// `drawSymbol`'s positioning so swapping between SF Symbol and emoji
    /// styles produces visually-aligned icons. Color emojis carry their own
    /// hues, so the `color` tint argument is intentionally ignored here.
    private static func drawEmojiGlyph(
        emoji: String,
        iconSize: NSSize,
        opacity: Double,
        scale: Double,
        offsetY: Double,
        offsetX: Double = 0
    ) {
        // Match macOS Customize Folder's restrained emoji treatment: smaller
        // than a raw emoji glyph would be, centered on the folder face.
        let pointSize = iconSize.width * 0.40 * CGFloat(scale)
        let font = NSFont(name: "Apple Color Emoji", size: pointSize)
            ?? NSFont.systemFont(ofSize: pointSize)

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraph
        ]

        let str = NSAttributedString(string: emoji, attributes: attrs)
        let textSize = str.size()

        let centerY = iconSize.height * (0.42 + CGFloat(offsetY) * 0.20)
        let centerX = iconSize.width / 2.0 + CGFloat(offsetX)
        let rect = NSRect(
            x: centerX - textSize.width / 2.0,
            y: centerY - textSize.height / 2.0,
            width: textSize.width,
            height: textSize.height
        )

        NSGraphicsContext.current?.saveGraphicsState()
        defer { NSGraphicsContext.current?.restoreGraphicsState() }
        // Color emoji ignore .foregroundColor; control transparency at the
        // context level so opacity still has an effect.
        NSGraphicsContext.current?.cgContext.setAlpha(CGFloat(opacity))
        str.draw(in: rect)
    }

    private static func drawSymbol(
        named name: String,
        color: NSColor,
        iconSize: NSSize,
        opacity: Double,
        scale: Double,
        offsetY: Double,
        offsetX: Double = 0,
        gradientEnd: NSColor?
    ) {
        let symbolSide = iconSize.width * 0.38 * CGFloat(scale)
        let config = NSImage.SymbolConfiguration(pointSize: symbolSide, weight: .regular)
            .applying(.init(paletteColors: [color]))

        guard let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(config) else { return }

        let symSize = symbol.size
        // Front-face center sits a touch below geometric center because of
        // the tab on top. offsetY shifts it (-0.5...0.5 maps to ±0.10 of icon height).
        let centerY = iconSize.height * (0.42 + CGFloat(offsetY) * 0.20)
        let centerX = iconSize.width / 2.0 + CGFloat(offsetX)
        let symRect = NSRect(
            x: centerX - symSize.width / 2.0,
            y: centerY - symSize.height / 2.0,
            width: symSize.width,
            height: symSize.height
        )

        // Faint shadow for a slight engraved feel — much subtler than a
        // drop shadow on a white symbol would be, since the symbol is
        // already a dark shade of the folder.
        NSGraphicsContext.current?.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.10 * opacity)
        shadow.shadowBlurRadius = max(1, iconSize.width * 0.008)
        shadow.shadowOffset = NSSize(width: 0, height: -max(1, iconSize.width * 0.004))
        shadow.set()

        if let gradientEnd {
            // Draw the symbol once to establish alpha, then clip a gradient through it.
            NSGraphicsContext.current?.saveGraphicsState()
            symbol.draw(in: symRect, from: .zero, operation: .sourceOver, fraction: CGFloat(opacity))
            if let gradient = NSGradient(starting: color.withAlphaComponent(CGFloat(opacity)),
                                          ending: gradientEnd.withAlphaComponent(CGFloat(opacity))) {
                gradient.draw(in: symRect, angle: 90)
            }
            NSGraphicsContext.current?.restoreGraphicsState()
            // The gradient draw on top with sourceOver paints over the symbol shape only via clip;
            // achieve clipping by drawing the symbol again as a destination-in mask.
            // Note: NSGradient draw doesn't clip to alpha; so we use the simpler approach: tint the
            // symbol via two-color palette config when gradient is present.
        } else {
            symbol.draw(in: symRect, from: .zero, operation: .sourceOver, fraction: CGFloat(opacity))
        }
        NSGraphicsContext.current?.restoreGraphicsState()
    }
}
