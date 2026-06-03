//
// SPDX-License-Identifier: MIT
//  FolderRowView.swift
//  Iconic
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct FolderRowView: View {

    // MARK: - Layout constants

    private enum K {
        // Row body
        static let rowSpacing: CGFloat = 12
        static let previewSize: CGFloat = 44
        static let titleStackSpacing: CGFloat = 2
        static let rowHorizontalPadding: CGFloat = 12
        static let rowVerticalPadding: CGFloat = 8
        static let selectionBackgroundOpacity: Double = 0.18

        // More-options menu + placeholder
        static let moreMenuIconSize: CGFloat = 14
        static let placeholderCornerRadius: CGFloat = 6
        static let placeholderGlyphSize: CGFloat = 22
        static let tightSpacing: CGFloat = 4

        // Match-source dot + swatches
        static let matchSourceDotSize: CGFloat = 6
        static let colorSwatchSize: CGFloat = 12
        static let swatchBorderOpacity: Double = 0.25
        static let swatchBorderLineWidth: CGFloat = 0.5
        static let defaultSwatchOpacity: Double = 0.25

        // Popover shell
        static let popoverSectionSpacing: CGFloat = 14
        static let popoverSubSectionSpacing: CGFloat = 6
        static let popoverPadding: CGFloat = 14
        static let popoverSize: CGSize = .init(width: 340, height: 480)

        // Sliders
        static let sizeSliderRange: ClosedRange<Double> = 0.4...1.6
        static let opacitySliderRange: ClosedRange<Double> = 0.1...1.0
        static let offsetYSliderRange: ClosedRange<Double> = -0.5...0.5

        // Adjustment row
        static let adjustmentLabelWidth: CGFloat = 70
        static let adjustmentValueWidth: CGFloat = 50

        // Color picker
        static let colorPickerWidth: CGFloat = 28
        static let colorRowSpacing: CGFloat = 8
        static let colorRowLabelWidth: CGFloat = 70
        static let gradientStartBlendFraction: CGFloat = 0.4

        // Symbol input + suggestions
        static let symbolInputFieldWidth: CGFloat = 240
        static let suggestionsRowSpacing: CGFloat = 6
        static let suggestionButtonSpacing: CGFloat = 4
        static let suggestionButtonHorizontalPadding: CGFloat = 8
        static let suggestionButtonVerticalPadding: CGFloat = 4

        // Default folder swatch color (UI stub; the actual default render
        // color comes from ColorPreferences.getDefaultColor())
        static let defaultFolderSwatchRGB: (r: CGFloat, g: CGFloat, b: CGFloat) = (0.30, 0.55, 0.95)

        // Dominant color extraction (the importFinderIcon helper)
        static let dominantColorSampleStride: Int = 10
        static let dominantColorMinBrightness: Double = 0.2
        static let dominantColorMaxBrightness: Double = 0.9

        // contrastingColor helper
        static let contrastingSaturationBoost: Double = 1.2
        static let contrastingBrightnessFactor: Double = 0.6
        static let contrastingAlpha: Double = 0.9
    }

    @ObservedObject var item: FolderItem
    @EnvironmentObject private var suggestionsStore: SmartSuggestionsStore
    let isSelected: Bool
    let onApply: () -> Void
    let onRestore: () -> Void
    let onSymbolEdit: (String) -> Void
    let onColorChange: (NSColor?) -> Void
    let onFolderColorChange: (NSColor?) -> Void
    let onSelect: () -> Void
    let onToggleSelect: () -> Void
    let onExtendSelect: () -> Void
    let onReveal: () -> Void
    let onCopyPath: () -> Void
    let onAddExcludePattern: () -> Void
    let onCopySettings: () -> Void
    let onPasteSettings: () -> Void
    let onAdjust: () -> Void
    let onSaveAsTemplate: () -> Void
    let templates: [IconTemplate]
    let onApplyTemplate: (IconTemplate) -> Void
    let onShowComparison: () -> Void
    let onQuickLook: () -> Void
    let onRetry: () -> Void

    @State private var draftSymbol: String = ""
    @State private var showingEditPopover = false
    @State private var showingSymbolBrowser = false
    @State private var showingEmojiBrowser = false
    @State private var newLayerSymbol: String = ""
    @FocusState private var symbolFieldFocused: Bool

    var body: some View {
        HStack(spacing: K.rowSpacing) {
            preview
                .frame(width: K.previewSize, height: K.previewSize)

            VStack(alignment: .leading, spacing: K.titleStackSpacing) {
                Text(item.displayName)
                    .font(.body)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if !item.symbolName.isEmpty {
                    glyphLabel(item.symbolName)
                } else {
                    Text("No symbol match — folder left as system default")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            statusBadge

            swatchButton

            Button {
                draftSymbol = item.symbolName
                showingEditPopover = true
                DispatchQueue.main.async { symbolFieldFocused = true }
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
            .help(item.isUnassigned
                  ? "Pick a symbol for this folder"
                  : "Edit symbol, size, colors, and more")
            .accessibilityLabel(item.isUnassigned
                                ? "Pick a symbol for \(item.displayName)"
                                : "Edit icon for \(item.displayName)")
            .accessibilityHint("Opens the symbol, colors, and adjustments editor")
            .popover(isPresented: $showingEditPopover, arrowEdge: .bottom) {
                editPopover
            }

            moreOptionsMenu

            Button("Apply") { onApply() }
                .buttonStyle(.borderedProminent)
                .disabled(item.isUnassigned || item.symbolNames.isEmpty)
                .help(item.isUnassigned
                      ? "No symbol match for this folder. Pick one with the pencil button, or change the matching mode in Settings."
                      : "Apply the current icon to this folder")
        }
        .padding(.horizontal, K.rowHorizontalPadding)
        .padding(.vertical, K.rowVerticalPadding)
        .background(isSelected ? Color.accentColor.opacity(K.selectionBackgroundOpacity) : Color.clear)
        .contentShape(Rectangle())
        .gesture(
            TapGesture().modifiers(.shift).onEnded { onExtendSelect() }
        )
        .simultaneousGesture(
            TapGesture().modifiers(.command).onEnded { onToggleSelect() }
        )
        .simultaneousGesture(
            TapGesture().onEnded { onSelect() }
        )
        .contextMenu { rowMenuItems }
    }

    // MARK: - Unified menu (used by both 3-dots button and right-click)

    @ViewBuilder
    private var rowMenuItems: some View {
        Button("Apply Icon") { onApply() }
            .disabled(item.isUnassigned || item.symbolNames.isEmpty)
        Button("Restore Default") { onRestore() }
        Divider()
        Button("Re-match Folder") { onRetry() }
            .disabled(!canRematch)
        Divider()
        Button("Reveal in Finder") { onReveal() }
        Button("Copy Path") { onCopyPath() }
        Divider()
        Button("Copy Icon Settings") { onCopySettings() }
        Button("Paste Icon Settings") { onPasteSettings() }
            .disabled(!IconClipboard.hasContent())
        Divider()
        Button("Save as Template…") { onSaveAsTemplate() }
        if !templates.isEmpty {
            Menu("Apply Template") {
                ForEach(templates) { template in
                    Button(template.name) { onApplyTemplate(template) }
                }
            }
        }
        Button("Compare Before/After") { onShowComparison() }
        Button("Quick Look Preview") { onQuickLook() }
            .disabled(item.preview == nil)
        Button("Import Current Finder Icon") { importFinderIcon() }
        Button("Add to Exclude Patterns") { onAddExcludePattern() }
    }

    private var canRematch: Bool {
        if case .failed = item.status { return true }
        return item.isUnassigned
    }

    private var moreOptionsMenu: some View {
        Menu { rowMenuItems } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: K.moreMenuIconSize))
                .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("More options (or right-click row)")
        .accessibilityLabel("More options for \(item.displayName)")
    }

    @ViewBuilder
    private var preview: some View {
        if let img = item.preview {
            Image(nsImage: img)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: K.placeholderCornerRadius)
                    .fill(.quaternary)
                glyphView(item.symbolName, size: K.placeholderGlyphSize)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func glyphView(_ glyph: String, size: CGFloat) -> some View {
        if glyph.isEmojiGlyph {
            Text(glyph)
                .font(.system(size: size))
        } else {
            Image(systemName: glyph)
                .font(.system(size: size))
        }
    }

    @ViewBuilder
    private func glyphLabel(_ glyph: String) -> some View {
        if glyph.isEmojiGlyph {
            HStack(spacing: K.tightSpacing) {
                Text(glyph)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                matchSourceDot
            }
        } else {
            HStack(spacing: K.tightSpacing) {
                Image(systemName: glyph)
                    .font(.caption)
                Text(glyph)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                matchSourceDot
            }
        }
    }

    /// Tiny colored dot indicating how the icon was matched. Full label is
    /// in the tooltip so we save a whole row of vertical chrome.
    @ViewBuilder
    private var matchSourceDot: some View {
        Circle()
            .fill(item.matchSource.color)
            .frame(width: K.matchSourceDotSize, height: K.matchSourceDotSize)
            .help("Matched by: \(item.matchSource.displayName)")
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch item.status {
        case .pending:
            EmptyView()
        case .applying:
            ProgressView().controlSize(.small)
        case .applied:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .accessibilityLabel("Icon applied to \(item.displayName)")
        case .restored:
            Image(systemName: "arrow.uturn.backward.circle.fill")
                .foregroundStyle(.blue)
                .accessibilityLabel("Default icon restored for \(item.displayName)")
        case .failed(let msg):
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .accessibilityLabel("Error: \(msg)")
        }
    }

    /// Single tap target for the two color swatches. Tapping opens the unified
    /// edit popover (which is where the color pickers actually live).
    @ViewBuilder
    private var swatchButton: some View {
        Button {
            showingEditPopover = true
        } label: {
            HStack(spacing: K.tightSpacing) {
                colorSwatch(color: item.folderColor, help: "Folder color")
                colorSwatch(color: item.symbolColor, help: "Symbol color")
            }
        }
        .buttonStyle(.plain)
        .help("Edit colors")
        .accessibilityLabel("Edit colors for \(item.displayName)")
    }

    @ViewBuilder
    private func colorSwatch(color: NSColor?, help: String) -> some View {
        Circle()
            .fill(swatchFill(color: color))
            .frame(width: K.colorSwatchSize, height: K.colorSwatchSize)
            .overlay(
                Circle()
                    .stroke(Color.primary.opacity(K.swatchBorderOpacity), lineWidth: K.swatchBorderLineWidth)
            )
            .help(color == nil ? "\(help) (default)" : help)
    }

    private func swatchFill(color: NSColor?) -> Color {
        if let ns = color {
            return Color(nsColor: ns)
        }
        return Color.gray.opacity(K.defaultSwatchOpacity)
    }

    // MARK: - Unified edit popover (symbol + adjustments + colors + layers + custom image)

    @ViewBuilder
    private var editPopover: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: K.popoverSectionSpacing) {
                Text(editPopoverTitle)
                    .font(.headline)

                symbolSection
                Divider()
                adjustmentsSection
                Divider()
                layersSection
                Divider()
                colorsSection
                Divider()
                gradientSection
                Divider()
                customImageSection

                HStack {
                    Button("Reset") { resetAdjustments() }
                    Spacer()
                    Button("Done") { showingEditPopover = false }
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(K.popoverPadding)
        }
        .frame(width: K.popoverSize.width, height: K.popoverSize.height)
        .sheet(isPresented: $showingSymbolBrowser) {
            SymbolBrowserView { symbol in
                draftSymbol = symbol
                showingSymbolBrowser = false
            }
        }
        .sheet(isPresented: $showingEmojiBrowser) {
            EmojiBrowserView { emoji in
                draftSymbol = emoji
                showingEmojiBrowser = false
            }
        }
    }

    private var editPopoverTitle: String {
        if item.isUnassigned {
            return "Pick a symbol for this folder"
        }
        return "Edit Icon"
    }

    @ViewBuilder
    private var symbolSection: some View {
        VStack(alignment: .leading, spacing: K.popoverSubSectionSpacing) {
            sectionHeader("Symbol")
            if item.isUnassigned {
                symbolInputRow
                browserButton
                if !suggestions.isEmpty {
                    suggestionsSection
                }
            } else {
                if !suggestions.isEmpty {
                    suggestionsSection
                }
                symbolInputRow
                browserButton
            }
            HStack {
                if isValidDraftGlyph {
                    Label("Valid", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                } else {
                    Label(IconStyleStore.current == .emoji ? "Enter an emoji" : "Unknown symbol", systemImage: "questionmark.circle")
                        .foregroundStyle(.orange)
                        .font(.caption)
                }
                Spacer()
                Button("Apply") { commit() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValidDraftGlyph)
            }
        }
    }

    @ViewBuilder
    private var adjustmentsSection: some View {
        VStack(alignment: .leading, spacing: K.popoverSubSectionSpacing) {
            sectionHeader("Adjustments")
            adjustmentRow(label: "Size", binding: Binding(
                get: { item.symbolScale },
                set: { item.symbolScale = $0; onAdjust() }
            ), range: K.sizeSliderRange, format: { "\(Int($0 * 100))%" })
            adjustmentRow(label: "Opacity", binding: Binding(
                get: { item.symbolOpacity },
                set: { item.symbolOpacity = $0; onAdjust() }
            ), range: K.opacitySliderRange, format: { "\(Int($0 * 100))%" })
            adjustmentRow(label: "Offset Y", binding: Binding(
                get: { item.symbolOffsetY },
                set: { item.symbolOffsetY = $0; onAdjust() }
            ), range: K.offsetYSliderRange, format: { String(format: "%+.2f", $0) })
        }
    }

    @ViewBuilder
    private func adjustmentRow(
        label: String,
        binding: Binding<Double>,
        range: ClosedRange<Double>,
        format: @escaping (Double) -> String
    ) -> some View {
        HStack {
            Text(label)
                .frame(width: 70, alignment: .leading)
            Slider(value: binding, in: range)
                .accessibilityValue("\(Int(binding.wrappedValue * 100)) percent")
                .accessibilityAdjustableAction { direction in
                    let step = 0.05
                    switch direction {
                    case .increment:
                        binding.wrappedValue = min(range.upperBound, binding.wrappedValue + step)
                    case .decrement:
                        binding.wrappedValue = max(range.lowerBound, binding.wrappedValue - step)
                    @unknown default:
                        break
                    }
                }
            Text(format(binding.wrappedValue))
                .font(.caption)
                .frame(width: 50, alignment: .trailing)
                .monospacedDigit()
        }
    }

    @ViewBuilder
    private var layersSection: some View {
        VStack(alignment: .leading, spacing: K.popoverSubSectionSpacing) {
            sectionHeader("Layers")
            if item.symbolNames.count > 1 {
                VStack(spacing: 4) {
                    ForEach(Array(item.symbolNames.enumerated()), id: \.offset) { index, symbolName in
                        HStack(spacing: 8) {
                            glyphView(symbolName, size: 12)
                            Text(symbolName)
                                .font(.caption)
                                .lineLimit(1)
                            Spacer()
                            Button {
                                removeLayer(at: index)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove layer \(symbolName)")
                            .disabled(item.symbolNames.count <= 1)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                    }
                }
            }
            if item.symbolNames.count < 3 {
                HStack {
                    TextField(IconStyleStore.current == .emoji ? "Add emoji layer" : "Add symbol layer", text: $newLayerSymbol)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                    Button {
                        addLayer()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.green)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add layer")
                    .disabled(newLayerSymbol.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } else {
                Text("Maximum 3 layers")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var colorsSection: some View {
        VStack(alignment: .leading, spacing: K.popoverSubSectionSpacing) {
            sectionHeader("Colors")
            colorRow(
                label: "Folder",
                color: Binding(
                    get: { Color(item.folderColor ?? defaultFolderSwatchColor) },
                    set: { onFolderColorChange(NSColor($0)) }
                ),
                isSet: item.folderColor != nil,
                onClear: { onFolderColorChange(nil) }
            )
            colorRow(
                label: "Symbol",
                color: Binding(
                    get: { Color(item.symbolColor ?? defaultSymbolSwatchColor) },
                    set: { onColorChange(NSColor($0)) }
                ),
                isSet: item.symbolColor != nil,
                onClear: { onColorChange(nil) }
            )
        }
    }

    @ViewBuilder
    private var gradientSection: some View {
        VStack(alignment: .leading, spacing: K.popoverSubSectionSpacing) {
            sectionHeader("Gradient")
            HStack {
                Toggle("Enabled", isOn: Binding(
                    get: { item.symbolGradientEnd != nil },
                    set: { enabled in
                        if enabled {
                            item.symbolGradientEnd = (item.symbolColor ?? .systemBlue).blended(withFraction: K.gradientStartBlendFraction, of: .black)
                        } else {
                            item.symbolGradientEnd = nil
                        }
                        onAdjust()
                    }
                ))
                Spacer()
                if item.symbolGradientEnd != nil {
                    ColorPicker("", selection: Binding(
                        get: { Color(item.symbolGradientEnd ?? .black) },
                        set: { newColor in
                            item.symbolGradientEnd = NSColor(newColor)
                            onAdjust()
                        }
                    ))
                    .labelsHidden()
                    .frame(width: K.colorPickerWidth)
                    .accessibilityLabel("Gradient end color")
                }
            }
        }
    }

    @ViewBuilder
    private var customImageSection: some View {
        VStack(alignment: .leading, spacing: K.popoverSubSectionSpacing) {
            sectionHeader("Custom Image")
            HStack {
                Text(item.customImage == nil ? "None" : "Image set")
                    .font(.caption)
                    .foregroundStyle(item.customImage == nil ? .secondary : .primary)
                Spacer()
                if item.customImage != nil {
                    Button("Remove") {
                        item.customImage = nil
                        onAdjust()
                    }
                    .controlSize(.small)
                }
                Button(item.customImage == nil ? "Choose…" : "Replace") {
                    chooseCustomImage()
                }
                .controlSize(.small)
            }
        }
    }

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func colorRow(
        label: String,
        color: Binding<Color>,
        isSet: Bool,
        onClear: @escaping () -> Void
    ) -> some View {
        HStack(spacing: K.colorRowSpacing) {
            Text(label)
                .frame(width: K.colorRowLabelWidth, alignment: .leading)
            ColorPicker("", selection: color, supportsOpacity: false)
                .labelsHidden()
                .frame(width: K.colorPickerWidth)
                .accessibilityLabel(label)
            if isSet {
                Button {
                    onClear()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Reset to default")
                .accessibilityLabel("Reset \(label) color to default")
            } else {
                Text("default")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var symbolInputRow: some View {
        TextField(IconStyleStore.current == .emoji ? "e.g. 🎵" : "e.g. music.note", text: $draftSymbol)
            .textFieldStyle(.roundedBorder)
            .frame(width: K.symbolInputFieldWidth)
            .focused($symbolFieldFocused)
            .onSubmit { commit() }
    }

    @ViewBuilder
    private var browserButton: some View {
        if IconStyleStore.current == .sfSymbol {
            Button {
                showingSymbolBrowser = true
            } label: {
                Label("Browse Symbols…", systemImage: "square.grid.3x3")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        } else {
            Button {
                showingEmojiBrowser = true
            } label: {
                Label("Browse Emoji…", systemImage: "face.smiling")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    @ViewBuilder
    private var suggestionsSection: some View {
        if !suggestions.isEmpty {
            VStack(alignment: .leading, spacing: K.popoverSubSectionSpacing) {
                Text("Suggestions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: K.suggestionsRowSpacing) {
                    ForEach(suggestions, id: \.self) { symbol in
                        Button {
                            draftSymbol = symbol
                        } label: {
                            HStack(spacing: K.suggestionButtonSpacing) {
                                glyphView(symbol, size: 12)
                                Text(symbol)
                                    .font(.caption2)
                            }
                            .padding(.horizontal, K.suggestionButtonHorizontalPadding)
                            .padding(.vertical, K.suggestionButtonVerticalPadding)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
    }

    private var suggestions: [String] {
        IconStyleStore.current == .sfSymbol ? suggestionsStore.getSuggestions(for: item.displayName) : []
    }

    private var defaultFolderSwatchColor: NSColor {
        NSColor(calibratedRed: K.defaultFolderSwatchRGB.r, green: K.defaultFolderSwatchRGB.g, blue: K.defaultFolderSwatchRGB.b, alpha: 1.0)
    }

    private var defaultSymbolSwatchColor: NSColor {
        .white
    }

    // MARK: - Mutations

    private func commit() {
        let trimmed = draftSymbol.trimmingCharacters(in: .whitespaces)
        guard isValidGlyph(trimmed) else { return }
        onSymbolEdit(trimmed)
        showingEditPopover = false
    }

    private func addLayer() {
        let trimmed = newLayerSymbol.trimmingCharacters(in: .whitespaces)
        guard isValidGlyph(trimmed), item.symbolNames.count < 3 else { return }
        item.symbolNames.append(trimmed)
        newLayerSymbol = ""
        onAdjust()
    }

    private func removeLayer(at index: Int) {
        guard item.symbolNames.count > 1, index < item.symbolNames.count else { return }
        item.symbolNames.remove(at: index)
        onAdjust()
    }

    private func resetAdjustments() {
        // TODO: use FolderItem.defaultSymbolScale
        item.symbolScale = 1.0
        // TODO: use FolderItem.defaultSymbolOpacity
        item.symbolOpacity = 1.0
        // TODO: use FolderItem.defaultSymbolOffsetY
        item.symbolOffsetY = 0.0
        item.symbolGradientEnd = nil
        item.customImage = nil
        onColorChange(nil)
        onFolderColorChange(nil)
        onAdjust()
    }

    private var isValidDraftGlyph: Bool {
        isValidGlyph(draftSymbol.trimmingCharacters(in: .whitespaces))
    }

    private func isValidGlyph(_ glyph: String) -> Bool {
        guard !glyph.isEmpty else { return false }
        switch IconStyleStore.current {
        case .emoji:
            return glyph.isEmojiGlyph
        case .sfSymbol:
            return NSImage(systemSymbolName: glyph, accessibilityDescription: nil) != nil
        }
    }

    private func chooseCustomImage() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.png, .jpeg, .gif, .tiff, .bmp, .svg]
        panel.message = "Choose an image to use as the folder icon overlay."
        if panel.runModal() == .OK, let url = panel.url, let img = NSImage(contentsOf: url) {
            item.customImage = img
            onAdjust()
        }
    }

    private func importFinderIcon() {
        let currentIcon = NSWorkspace.shared.icon(forFile: item.url.path)

        if let tiffData = currentIcon.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData),
           let dominantColor = extractDominantColor(from: bitmap) {
            item.folderColor = dominantColor
            item.symbolColor = contrastingColor(for: dominantColor)
        }

        item.customImage = currentIcon
        onAdjust()
    }

    private func extractDominantColor(from bitmap: NSBitmapImageRep) -> NSColor? {
        guard let data = bitmap.bitmapData else { return nil }

        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        var count = 0
        let pixelCount = bitmap.pixelsWide * bitmap.pixelsHigh
        let samplesPerPixel = bitmap.samplesPerPixel

        for i in stride(from: 0, to: pixelCount, by: K.dominantColorSampleStride) {
            let offset = i * samplesPerPixel
            guard offset + 2 < bitmap.bytesPerRow * bitmap.pixelsHigh else { continue }

            let red = CGFloat(data[offset]) / 255.0
            let green = CGFloat(data[offset + 1]) / 255.0
            let blue = CGFloat(data[offset + 2]) / 255.0

            let brightness = (red + green + blue) / 3.0
            if brightness > K.dominantColorMinBrightness && brightness < K.dominantColorMaxBrightness {
                r += red
                g += green
                b += blue
                count += 1
            }
        }

        guard count > 0 else { return nil }
        return NSColor(red: r / CGFloat(count), green: g / CGFloat(count), blue: b / CGFloat(count), alpha: 1.0)
    }

    private func contrastingColor(for color: NSColor) -> NSColor {
        guard let rgb = color.usingColorSpace(.sRGB) else { return .white }
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        rgb.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return NSColor(hue: h, saturation: min(1, s * K.contrastingSaturationBoost), brightness: max(0, b * K.contrastingBrightnessFactor), alpha: K.contrastingAlpha)
    }
}
