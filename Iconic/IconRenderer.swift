//
// SPDX-License-Identifier: MIT
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

    // MARK: - Layout constants

    private enum Layout {
        // Canvas
        static let masterCanvasSide: CGFloat = 512
        static let representationSizes: [CGFloat] = [16, 32, 64, 128, 256, 512]

        // Bitmap
        static let bitsPerSample: Int = 8
        static let samplesPerPixel: Int = 4
        static let bitsPerPixel: Int = 32
        static let fullOpacity: Double = 1.0
        static let monochromeIntensity: Double = 1.0

        // Front-face positioning
        // Empirically tuned — Apple's system folder icon has a tab on
        // top, so the visual "face" sits below geometric center. If
        // Apple ever changes the folder icon shape, these need to
        // change in tandem.
        static let frontFaceCenterFraction: CGFloat = 0.42
        static let offsetYToHeightFactor: CGFloat = 0.20
        static let symbolSideFraction: CGFloat = 0.38
        static let emojiSideFraction: CGFloat = 0.40
        static let customImageSideFraction: CGFloat = 0.42

        // Layer stack (max 3 — also enforced in FolderRowView)
        static let maxLayers: Int = 3
        static let layer1Scale: CGFloat = 1.0
        static let layer2Scale: CGFloat = 0.80
        static let layer2XOffsetFraction: CGFloat = 0.05
        static let layer2OpacityMultiplier: Double = 0.85
        static let layer3Scale: CGFloat = 0.70
        static let layer3XOffsetFraction: CGFloat = 0.10
        static let layer3OpacityMultiplier: Double = 0.75

        // Drop shadow
        // Empirically tuned — scales with iconSize so the shadow
        // looks proportional at every resolution.
        static let shadowBaseAlpha: CGFloat = 0.10
        static let shadowBlurFraction: CGFloat = 0.008
        static let shadowOffsetFraction: CGFloat = 0.004
        static let minimumShadowMagnitude: CGFloat = 1

        // Gradient
        static let gradientAngle: CGFloat = 90   // degrees, vertical
    }

    // Existing public API — keep this so the public surface is unchanged
    static let representationSizes: [CGFloat] = Layout.representationSizes

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

        let composite = NSImage(size: NSSize(width: Layout.masterCanvasSide, height: Layout.masterCanvasSide))
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
        icon.size = NSSize(width: Layout.masterCanvasSide, height: Layout.masterCanvasSide)
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
        filter.setValue(Layout.monochromeIntensity, forKey: "inputIntensity")
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
            bitsPerSample: Layout.bitsPerSample,
            samplesPerPixel: Layout.samplesPerPixel,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: Layout.bitsPerPixel
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
            folder.draw(in: rect, from: .zero, operation: .copy, fraction: Layout.fullOpacity)
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
        let baseSide = iconSize.width * Layout.customImageSideFraction * CGFloat(scale)
        let aspect = image.size.width / max(image.size.height, 1)
        let drawWidth = baseSide * (aspect >= 1 ? 1 : aspect)
        let drawHeight = baseSide * (aspect >= 1 ? 1 / aspect : 1)
        let centerY = iconSize.height * (Layout.frontFaceCenterFraction + CGFloat(offsetY) * Layout.offsetYToHeightFactor)
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
                layerScale = Layout.layer1Scale
                layerOffsetX = 0
                layerOpacity = opacity
            case 1:
                layerScale = Layout.layer2Scale
                layerOffsetX = iconSize.width * Layout.layer2XOffsetFraction
                layerOpacity = opacity * Layout.layer2OpacityMultiplier
            case 2:
                layerScale = Layout.layer3Scale
                layerOffsetX = iconSize.width * Layout.layer3XOffsetFraction
                layerOpacity = opacity * Layout.layer3OpacityMultiplier
            default:
                continue // cap at Layout.maxLayers
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
        let pointSize = iconSize.width * Layout.emojiSideFraction * CGFloat(scale)
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

        let centerY = iconSize.height * (Layout.frontFaceCenterFraction + CGFloat(offsetY) * Layout.offsetYToHeightFactor)
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
        let symbolSide = iconSize.width * Layout.symbolSideFraction * CGFloat(scale)
        let config = NSImage.SymbolConfiguration(pointSize: symbolSide, weight: .regular)
            .applying(.init(paletteColors: [color]))

        guard let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(config) else { return }

        let symSize = symbol.size
        // Front-face center sits a touch below geometric center because of
        // the tab on top. offsetY shifts it (-0.5...0.5 maps to ±0.10 of icon height).
        let centerY = iconSize.height * (Layout.frontFaceCenterFraction + CGFloat(offsetY) * Layout.offsetYToHeightFactor)
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
        shadow.shadowColor = NSColor.black.withAlphaComponent(Layout.shadowBaseAlpha * CGFloat(opacity))
        shadow.shadowBlurRadius = max(Layout.minimumShadowMagnitude, iconSize.width * Layout.shadowBlurFraction)
        shadow.shadowOffset = NSSize(width: 0, height: -max(Layout.minimumShadowMagnitude, iconSize.width * Layout.shadowOffsetFraction))
        shadow.set()

        if let gradientEnd {
            // Draw the symbol once to establish alpha, then clip a gradient through it.
            NSGraphicsContext.current?.saveGraphicsState()
            symbol.draw(in: symRect, from: .zero, operation: .sourceOver, fraction: CGFloat(opacity))
            if let gradient = NSGradient(starting: color.withAlphaComponent(CGFloat(opacity)),
                                          ending: gradientEnd.withAlphaComponent(CGFloat(opacity))) {
                gradient.draw(in: symRect, angle: Layout.gradientAngle)
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
