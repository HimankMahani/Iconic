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
    let isDryRunMode: Bool
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

    @State private var showingSymbolEditor = false
    @State private var draftSymbol: String = ""
    @State private var showingAdjustPopover = false
    @State private var showingImagePicker = false
    @State private var showingSymbolBrowser = false
    @State private var newLayerSymbol: String = ""

    var body: some View {
        HStack(spacing: 12) {
            preview
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .font(.body)
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack(spacing: 4) {
                    Image(systemName: item.symbolName)
                        .font(.caption2)
                    Text(item.symbolName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                matchSourceBadge
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            statusBadge

            ColorPicker("", selection: Binding(
                get: {
                    if let folder = item.folderColor {
                        return Color(folder)
                    }
                    return Color(NSColor.systemBlue)
                },
                set: { newColor in
                    let nsColor = NSColor(newColor)
                    item.folderColor = nsColor
                    onFolderColorChange(nsColor)
                }
            ))
            .labelsHidden()
            .frame(width: 28)
            .help("Choose folder color")

            ColorPicker("", selection: Binding(
                get: { Color(item.symbolColor ?? ColorPreferences.getDefaultColor()) },
                set: { newColor in
                    let nsColor = NSColor(newColor)
                    item.symbolColor = nsColor
                    onColorChange(nsColor)
                }
            ))
            .labelsHidden()
            .frame(width: 28)
            .help("Choose symbol color")

            Button {
                draftSymbol = item.symbolName
                showingSymbolEditor = true
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
            .help("Edit SF Symbol for this folder")
            .popover(isPresented: $showingSymbolEditor, arrowEdge: .bottom) {
                symbolEditor
            }

            Button {
                showingAdjustPopover = true
            } label: {
                Image(systemName: "slider.horizontal.3")
            }
            .buttonStyle(.borderless)
            .help("Adjust size, opacity, position, gradient")
            .popover(isPresented: $showingAdjustPopover, arrowEdge: .bottom) {
                adjustPopover
            }

            Button {
                onShowComparison()
            } label: {
                Image(systemName: "arrow.left.and.right")
            }
            .buttonStyle(.borderless)
            .help("Compare before/after")

            moreOptionsMenu

            Button("Restore") { onRestore() }
                .buttonStyle(.bordered)
                .disabled(isDryRunMode)
            Button(isDryRunMode ? "Preview" : "Apply") {
                if !isDryRunMode {
                    onApply()
                }
            }
                .buttonStyle(.borderedProminent)
                .disabled(isDryRunMode)
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
        .contextMenu {
            Button("Apply Icon") { onApply() }
                .disabled(isDryRunMode)
            Button("Restore Default") { onRestore() }
                .disabled(isDryRunMode)
            Divider()
            Button("Copy Icon Settings") { onCopySettings() }
            Button("Paste Icon Settings") { onPasteSettings() }
                .disabled(!IconClipboard.hasContent())
            Divider()
            Button("Import Current Finder Icon") {
                importFinderIcon()
            }
            Button("Save as Template…") { onSaveAsTemplate() }
            if !templates.isEmpty {
                Menu("Apply Template") {
                    ForEach(templates) { template in
                        Button(template.name) { onApplyTemplate(template) }
                    }
                }
            }
            Divider()
            Button("Reveal in Finder") { onReveal() }
            Button("Copy Path") { onCopyPath() }
            Divider()
            Button("Add \"\(item.displayName)\" to Exclude Patterns") { onAddExcludePattern() }
        }
    }

    private var moreOptionsMenu: some View {
        Menu {
            Button {
                onReveal()
            } label: {
                Label("Reveal in Finder", systemImage: "folder")
            }

            Button {
                onCopyPath()
            } label: {
                Label("Copy Path", systemImage: "doc.on.doc")
            }

            Divider()

            Button {
                onCopySettings()
            } label: {
                Label("Copy Icon Settings", systemImage: "doc.on.clipboard")
            }

            Button {
                onPasteSettings()
            } label: {
                Label("Paste Icon Settings", systemImage: "clipboard")
            }
            .disabled(!IconClipboard.hasContent())

            Divider()

            Button {
                onSaveAsTemplate()
            } label: {
                Label("Save as Template", systemImage: "square.and.arrow.down")
            }

            if !templates.isEmpty {
                Menu("Apply Template") {
                    ForEach(templates) { template in
                        Button(template.name) {
                            onApplyTemplate(template)
                        }
                    }
                }
            }

            Divider()

            Button {
                onShowComparison()
            } label: {
                Label("Compare Before/After", systemImage: "rectangle.split.2x1")
            }

            Button {
                onAddExcludePattern()
            } label: {
                Label("Add to Exclude Patterns", systemImage: "minus.circle")
            }
        } label: {
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
                Image(systemName: item.symbolName)
                    .font(.system(size: 22))
                    .foregroundStyle(.secondary)
            }
        }
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

    private var matchSourceBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: item.matchSource.icon)
                .font(.caption2)
            Text(item.matchSource.displayName)
                .font(.caption2)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(item.matchSource.color.opacity(0.15))
        .foregroundStyle(item.matchSource.color)
        .cornerRadius(4)
        .help("How this icon was matched")
    }

    private var symbolEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SF Symbol name")
                .font(.headline)

            // Suggestions section
            let suggestions = suggestionsStore.getSuggestions(for: item.displayName)
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
                                    Image(systemName: symbol)
                                        .font(.caption)
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

            TextField("e.g. music.note", text: $draftSymbol)
                .textFieldStyle(.roundedBorder)
                .frame(width: 240)
                .onSubmit { commit() }

            Button {
                showingSymbolBrowser = true
            } label: {
                Label("Browse Symbols…", systemImage: "square.grid.3x3")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            HStack {
                if NSImage(systemSymbolName: draftSymbol, accessibilityDescription: nil) != nil {
                    Label("Valid", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                } else {
                    Label("Unknown symbol", systemImage: "questionmark.circle")
                        .foregroundStyle(.orange)
                        .font(.caption)
                }
                Spacer()
                Button("Cancel") { showingSymbolEditor = false }
                Button("Apply") { commit() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(draftSymbol.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(14)
        .sheet(isPresented: $showingSymbolBrowser) {
            SymbolBrowserView { symbol in
                draftSymbol = symbol
                showingSymbolBrowser = false
            }
        }
    }

    private var adjustPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Icon Adjustments")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Size")
                        .frame(width: 60, alignment: .leading)
                    Slider(value: Binding(
                        get: { item.symbolScale },
                        set: { newValue in
                            item.symbolScale = newValue
                            onAdjust()
                        }
                    ), in: 0.4...1.6)
                    Text("\(Int(item.symbolScale * 100))%")
                        .font(.caption)
                        .frame(width: 40, alignment: .trailing)
                        .monospacedDigit()
                }

                HStack {
                    Text("Opacity")
                        .frame(width: 60, alignment: .leading)
                    Slider(value: Binding(
                        get: { item.symbolOpacity },
                        set: { newValue in
                            item.symbolOpacity = newValue
                            onAdjust()
                        }
                    ), in: 0.1...1.0)
                    Text("\(Int(item.symbolOpacity * 100))%")
                        .font(.caption)
                        .frame(width: 40, alignment: .trailing)
                        .monospacedDigit()
                }

                HStack {
                    Text("Offset Y")
                        .frame(width: 60, alignment: .leading)
                    Slider(value: Binding(
                        get: { item.symbolOffsetY },
                        set: { newValue in
                            item.symbolOffsetY = newValue
                            onAdjust()
                        }
                    ), in: -0.5...0.5)
                    Text(String(format: "%+.2f", item.symbolOffsetY))
                        .font(.caption)
                        .frame(width: 40, alignment: .trailing)
                        .monospacedDigit()
                }
            }

            Divider()

            // Layers section
            VStack(alignment: .leading, spacing: 8) {
                Text("Layers")
                    .font(.subheadline)
                    .fontWeight(.medium)

                if item.symbolNames.count > 1 {
                    VStack(spacing: 4) {
                        ForEach(Array(item.symbolNames.enumerated()), id: \.offset) { index, symbolName in
                            HStack(spacing: 8) {
                                Image(systemName: symbolName)
                                    .font(.caption)
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
                        TextField("Add symbol layer", text: $newLayerSymbol)
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

            Divider()

            HStack {
                Text("Gradient")
                Toggle("", isOn: Binding(
                    get: { item.symbolGradientEnd != nil },
                    set: { enabled in
                        if enabled {
                            // Default to a slightly different shade
                            item.symbolGradientEnd = (item.symbolColor ?? .systemBlue).blended(withFraction: 0.4, of: .black)
                        } else {
                            item.symbolGradientEnd = nil
                        }
                        onAdjust()
                    }
                ))
                .labelsHidden()
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

            Divider()

            HStack {
                Text("Custom Image")
                Spacer()
                if item.customImage != nil {
                    Button("Remove") {
                        item.customImage = nil
                        onAdjust()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                Button(item.customImage == nil ? "Choose..." : "Replace") {
                    chooseCustomImage()
                }
                .controlSize(.small)
            }

            Divider()

            HStack {
                Button("Reset") {
                    item.symbolScale = 1.0
                    item.symbolOpacity = 1.0
                    item.symbolOffsetY = 0.0
                    item.symbolGradientEnd = nil
                    item.customImage = nil
                    onAdjust()
                }
                Spacer()
                Button("Done") { showingAdjustPopover = false }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(14)
        .frame(width: 320)
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
        // Get the current icon from Finder
        let currentIcon = NSWorkspace.shared.icon(forFile: item.url.path)

        // Try to extract the dominant color from the icon
        if let tiffData = currentIcon.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData),
           let dominantColor = extractDominantColor(from: bitmap) {
            item.folderColor = dominantColor
            // Set symbol color to a contrasting shade
            item.symbolColor = contrastingColor(for: dominantColor)
        }

        // Store the icon as a custom image so it can be reapplied
        item.customImage = currentIcon

        onAdjust()
    }

    private func extractDominantColor(from bitmap: NSBitmapImageRep) -> NSColor? {
        guard let data = bitmap.bitmapData else { return nil }

        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        var count = 0
        let pixelCount = bitmap.pixelsWide * bitmap.pixelsHigh
        let samplesPerPixel = bitmap.samplesPerPixel

        // Sample every 10th pixel for performance
        for i in stride(from: 0, to: pixelCount, by: 10) {
            let offset = i * samplesPerPixel
            guard offset + 2 < bitmap.bytesPerRow * bitmap.pixelsHigh else { continue }

            let red = CGFloat(data[offset]) / 255.0
            let green = CGFloat(data[offset + 1]) / 255.0
            let blue = CGFloat(data[offset + 2]) / 255.0

            // Skip very dark or very light pixels (likely shadows/highlights)
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
        // Return a darker, more saturated version for contrast
        return NSColor(hue: h, saturation: min(1, s * 1.2), brightness: max(0, b * 0.6), alpha: 0.9)
    }

    private func commit() {
        let trimmed = draftSymbol.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        onSymbolEdit(trimmed)
        showingSymbolEditor = false
    }

    private func addLayer() {
        let trimmed = newLayerSymbol.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, item.symbolNames.count < 3 else { return }
        item.symbolNames.append(trimmed)
        newLayerSymbol = ""
        onAdjust()
    }

    private func removeLayer(at index: Int) {
        guard item.symbolNames.count > 1, index < item.symbolNames.count else { return }
        item.symbolNames.remove(at: index)
        onAdjust()
    }
}
