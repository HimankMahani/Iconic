//
//  FolderRowView.swift
//  Iconic
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct FolderRowView: View {

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
        HStack(spacing: 12) {
            preview
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
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
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
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
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("More options (or right-click row)")
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
                RoundedRectangle(cornerRadius: 6)
                    .fill(.quaternary)
                glyphView(item.symbolName, size: 22)
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
            HStack(spacing: 4) {
                Text(glyph)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                matchSourceDot
            }
        } else {
            HStack(spacing: 4) {
                Image(systemName: glyph)
                    .font(.caption2)
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
            .frame(width: 6, height: 6)
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
            Label("Applied", systemImage: "checkmark.circle.fill")
                .labelStyle(.iconOnly)
                .foregroundStyle(.green)
                .help("Icon applied")
        case .restored:
            Label("Restored", systemImage: "arrow.uturn.backward.circle.fill")
                .labelStyle(.iconOnly)
                .foregroundStyle(.blue)
                .help("Default icon restored")
        case .failed(let msg):
            Label("Error", systemImage: "exclamationmark.triangle.fill")
                .labelStyle(.iconOnly)
                .foregroundStyle(.red)
                .help(msg)
        }
    }

    /// Single tap target for the two color swatches. Tapping opens the unified
    /// edit popover (which is where the color pickers actually live).
    @ViewBuilder
    private var swatchButton: some View {
        Button {
            showingEditPopover = true
        } label: {
            HStack(spacing: 4) {
                colorSwatch(color: item.folderColor, help: "Folder color")
                colorSwatch(color: item.symbolColor, help: "Symbol color")
            }
        }
        .buttonStyle(.plain)
        .help("Edit colors")
    }

    @ViewBuilder
    private func colorSwatch(color: NSColor?, help: String) -> some View {
        Circle()
            .fill(swatchFill(color: color))
            .frame(width: 12, height: 12)
            .overlay(
                Circle()
                    .stroke(Color.primary.opacity(0.25), lineWidth: 0.5)
            )
            .help(color == nil ? "\(help) (default)" : help)
    }

    private func swatchFill(color: NSColor?) -> Color {
        if let ns = color {
            return Color(nsColor: ns)
        }
        return Color.gray.opacity(0.25)
    }

    // MARK: - Unified edit popover (symbol + adjustments + colors + layers + custom image)

    @ViewBuilder
    private var editPopover: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
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
            .padding(14)
        }
        .frame(width: 340, height: 480)
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
        VStack(alignment: .leading, spacing: 6) {
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
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("Adjustments")
            adjustmentRow(label: "Size", binding: Binding(
                get: { item.symbolScale },
                set: { item.symbolScale = $0; onAdjust() }
            ), range: 0.4...1.6, format: { "\(Int($0 * 100))%" })
            adjustmentRow(label: "Opacity", binding: Binding(
                get: { item.symbolOpacity },
                set: { item.symbolOpacity = $0; onAdjust() }
            ), range: 0.1...1.0, format: { "\(Int($0 * 100))%" })
            adjustmentRow(label: "Offset Y", binding: Binding(
                get: { item.symbolOffsetY },
                set: { item.symbolOffsetY = $0; onAdjust() }
            ), range: -0.5...0.5, format: { String(format: "%+.2f", $0) })
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
            Text(format(binding.wrappedValue))
                .font(.caption)
                .frame(width: 50, alignment: .trailing)
                .monospacedDigit()
        }
    }

    @ViewBuilder
    private var layersSection: some View {
        VStack(alignment: .leading, spacing: 6) {
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
        VStack(alignment: .leading, spacing: 6) {
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
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("Gradient")
            HStack {
                Toggle("Enabled", isOn: Binding(
                    get: { item.symbolGradientEnd != nil },
                    set: { enabled in
                        if enabled {
                            item.symbolGradientEnd = (item.symbolColor ?? .systemBlue).blended(withFraction: 0.4, of: .black)
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
                    .frame(width: 28)
                }
            }
        }
    }

    @ViewBuilder
    private var customImageSection: some View {
        VStack(alignment: .leading, spacing: 6) {
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
        HStack(spacing: 8) {
            Text(label)
                .frame(width: 70, alignment: .leading)
            ColorPicker("", selection: color, supportsOpacity: false)
                .labelsHidden()
                .frame(width: 28)
            if isSet {
                Button {
                    onClear()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Reset to default")
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
            .frame(width: 240)
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
            VStack(alignment: .leading, spacing: 6) {
                Text("Suggestions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    ForEach(suggestions, id: \.self) { symbol in
                        Button {
                            draftSymbol = symbol
                        } label: {
                            HStack(spacing: 4) {
                                glyphView(symbol, size: 12)
                                Text(symbol)
                                    .font(.caption2)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
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
        NSColor(calibratedRed: 0.30, green: 0.55, blue: 0.95, alpha: 1.0)
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
        item.symbolScale = 1.0
        item.symbolOpacity = 1.0
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

        for i in stride(from: 0, to: pixelCount, by: 10) {
            let offset = i * samplesPerPixel
            guard offset + 2 < bitmap.bytesPerRow * bitmap.pixelsHigh else { continue }

            let red = CGFloat(data[offset]) / 255.0
            let green = CGFloat(data[offset + 1]) / 255.0
            let blue = CGFloat(data[offset + 2]) / 255.0

            let brightness = (red + green + blue) / 3.0
            if brightness > 0.2 && brightness < 0.9 {
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
        return NSColor(hue: h, saturation: min(1, s * 1.2), brightness: max(0, b * 0.6), alpha: 0.9)
    }
}
