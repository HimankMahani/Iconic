//
//  ContentView.swift
//  Iconic
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {

    @EnvironmentObject private var vm: IconicViewModel
    @EnvironmentObject private var templatesStore: TemplatesStore
    @EnvironmentObject private var backupStore: BackupStore
    @State private var isDropTargeted = false
    @State private var showingShortcutsHelp = false
    @State private var showingRestoreConfirm = false
    @State private var recentFolders: [RecentFolder] = []
    @State private var favoriteFolders: [FavoriteFolder] = []
    @State private var showingExportSheet = false
    @State private var exportFormat: IconMapExportFormat = .markdown
    @State private var exportDocument: IconMapDocument?
    @State private var showingConflictAlert = false
    @State private var conflictedFolders: [FolderItem] = []
    @State private var showingSaveTemplate = false
    @State private var newTemplateName = ""
    @State private var templateSourceItem: FolderItem?
    @State private var showingBackups = false
    @State private var newBackupName = ""
    @State private var comparisonItem: FolderItem? = nil
    @FocusState private var listFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(minWidth: 720, minHeight: 520)
        .onAppear {
            vm.restoreLastFolderIfAvailable()
            reloadFolderLists()
        }
        .onChange(of: vm.rootURLs) { _, _ in reloadFolderLists() }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers: providers)
        }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.accentColor, lineWidth: 3)
                    .padding(4)
                    .allowsHitTesting(false)
            }
        }
        .background(hiddenShortcuts)
        .sheet(isPresented: $showingShortcutsHelp) {
            KeyboardShortcutsView()
        }
        .fileExporter(
            isPresented: $showingExportSheet,
            document: exportDocument,
            contentType: exportFormat.contentType,
            defaultFilename: exportFilename
        ) { result in
            exportDocument = nil
            if case .failure(let err) = result {
                vm.lastError = "Export failed: \(err.localizedDescription)"
            }
        }
        .confirmationDialog(
            "Restore default icons for \(vm.batchTargets.count) folder\(vm.batchTargets.count == 1 ? "" : "s")?",
            isPresented: $showingRestoreConfirm,
            titleVisibility: .visible
        ) {
            Button("Restore", role: .destructive) { vm.restoreAll() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This removes the custom icons Iconic applied and reverts to the system folder icon. You can re-apply them later.")
        }
        .alert(
            "\(conflictedFolders.count) folder\(conflictedFolders.count == 1 ? "" : "s") already ha\(conflictedFolders.count == 1 ? "s" : "ve") a custom icon",
            isPresented: $showingConflictAlert
        ) {
            Button("Overwrite All") {
                vm.applyAll()
                conflictedFolders = []
            }
            Button("Skip Conflicts") {
                let conflictIDs = Set(conflictedFolders.map { $0.id })
                for item in vm.batchTargets where conflictIDs.contains(item.id) {
                    item.status = .applied // mark to skip
                }
                vm.applyAll()
                conflictedFolders = []
            }
            Button("Cancel", role: .cancel) {
                conflictedFolders = []
            }
        } message: {
            let preview = conflictedFolders.prefix(5).map { $0.displayName }.joined(separator: ", ")
            let suffix = conflictedFolders.count > 5 ? "…" : ""
            Text("These folders already have custom icons set: \(preview)\(suffix). Overwriting will replace them.")
        }
        .sheet(isPresented: $showingSaveTemplate) {
            VStack(spacing: 16) {
                Text("Save as Template")
                    .font(.headline)
                if let source = templateSourceItem, let preview = source.preview {
                    Image(nsImage: preview)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 64, height: 64)
                }
                TextField("Template name", text: $newTemplateName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 300)
                HStack {
                    Button("Cancel") {
                        showingSaveTemplate = false
                        newTemplateName = ""
                        templateSourceItem = nil
                    }
                    .keyboardShortcut(.cancelAction)
                    Button("Save") {
                        if let source = templateSourceItem {
                            let template = TemplatesStore.capture(from: source, name: newTemplateName.isEmpty ? source.displayName : newTemplateName)
                            templatesStore.add(template)
                        }
                        showingSaveTemplate = false
                        newTemplateName = ""
                        templateSourceItem = nil
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(24)
            .frame(width: 380, height: 220)
        }
        .sheet(isPresented: $showingBackups) {
            backupsSheet
        }
        .sheet(item: $comparisonItem) { item in
            ComparisonView(item: item)
        }
    }

    private func reloadFolderLists() {
        recentFolders = RecentFoldersStore.load()
        favoriteFolders = FavoritesStore.load()
    }

    private var exportFilename: String {
        let base = vm.rootURL?.lastPathComponent ?? "icon-map"
        return "\(base)-iconic.\(exportFormat.fileExtension)"
    }

    private func prepareExportDocument() {
        let entries = IconMapExporter.entries(from: vm.items)
        guard let data = IconMapExporter.export(entries, as: exportFormat) else {
            vm.lastError = "Failed to prepare export."
            return
        }
        exportDocument = IconMapDocument(data: data)
        showingExportSheet = true
    }

    private func formattedTime(_ seconds: TimeInterval) -> String {
        let s = Int(seconds.rounded())
        if s < 60 { return "\(s)s" }
        let minutes = s / 60
        let secs = s % 60
        return secs == 0 ? "\(minutes)m" : "\(minutes)m \(secs)s"
    }

    /// Invisible buttons that capture keyboard shortcuts for actions that
    /// don't belong to a visible control. Placed in a hidden background
    /// so they participate in the responder chain without taking up layout.
    private var hiddenShortcuts: some View {
        ZStack {
            Button("Undo") { vm.performUndo() }
                .keyboardShortcut("z", modifiers: [.command])
                .disabled(!vm.undoManager.canUndo)
            Button("Redo") { vm.performRedo() }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(!vm.undoManager.canRedo)
            Button("Select All") { vm.selectAllVisible() }
                .keyboardShortcut("a", modifiers: [.command])
            Button("Show All") { vm.statusFilter = .all }
                .keyboardShortcut("1", modifiers: [.command])
            Button("Show Applied") { vm.statusFilter = .applied }
                .keyboardShortcut("2", modifiers: [.command])
            Button("Show Restored") { vm.statusFilter = .restored }
                .keyboardShortcut("3", modifiers: [.command])
            Button("Show Failed") { vm.statusFilter = .failed }
                .keyboardShortcut("4", modifiers: [.command])
            Button("Show Pending") { vm.statusFilter = .pending }
                .keyboardShortcut("5", modifiers: [.command])
            Button("Toggle Preview Mode") {
                vm.isDryRunMode.toggle()
            }
            .keyboardShortcut("p", modifiers: [.command])
            .disabled(vm.items.isEmpty || vm.isApplying)
            Button("Apply All") { vm.applyAll() }
                .keyboardShortcut("a", modifiers: [.command, .shift])
                .disabled(vm.items.isEmpty || vm.isApplying)
            Button("Restore All") { vm.restoreAll() }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(vm.items.isEmpty || vm.isApplying)
            Button("Shortcuts Help") { showingShortcutsHelp = true }
                .keyboardShortcut("/", modifiers: [.command])
            Button("Copy Icon Settings") {
                if let item = vm.focusedItem {
                    vm.copyIconSettings(from: item)
                }
            }
            .keyboardShortcut("c", modifiers: [.command])
            .disabled(vm.focusedItem == nil)
            Button("Paste Icon Settings") {
                if !vm.selectedItems.isEmpty {
                    vm.pasteIconSettingsToSelected()
                } else if let item = vm.focusedItem {
                    vm.pasteIconSettings(to: item)
                }
            }
            .keyboardShortcut("v", modifiers: [.command])
            .disabled(!IconClipboard.hasContent() || (vm.focusedItem == nil && vm.selectedItems.isEmpty))
        }
        .opacity(0)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }

    // MARK: - Sections

    private var header: some View {
        let folderCount = vm.rootURLs.count
        let hasMultipleFolders = folderCount > 1

        return HStack(spacing: 12) {
            Image(systemName: "folder.badge.gearshape")
                .font(.title2)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("Iconic")
                    .font(.headline)
                if hasMultipleFolders {
                    HStack(spacing: 4) {
                        Text("\(folderCount) folders selected")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button {
                            NSWorkspace.shared.activateFileViewerSelecting(vm.rootURLs)
                        } label: {
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Reveal in Finder")
                    }
                } else if let root = vm.rootURL {
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([root])
                    } label: {
                        HStack(spacing: 4) {
                            Text(root.path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .help("Reveal in Finder")
                } else {
                    Text("No folder selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()

            if hasMultipleFolders {
                HStack(spacing: 4) {
                    Image(systemName: "folder.badge.plus")
                        .font(.caption)
                    Text("\(folderCount)")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.15))
                .foregroundStyle(.primary)
                .cornerRadius(6)
            }

            recentsAndFavoritesMenu

            Button {
                showingBackups = true
            } label: {
                Image(systemName: "clock.arrow.2.circlepath")
            }
            .buttonStyle(.borderless)
            .help("Backups")

            Menu {
                ForEach(IconMapExportFormat.allCases) { format in
                    Button("Export as \(format.rawValue)") {
                        exportFormat = format
                        prepareExportDocument()
                    }
                }
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Export icon map")
            .disabled(vm.items.isEmpty)

            Button {
                showingShortcutsHelp = true
            } label: {
                Image(systemName: "questionmark.circle")
            }
            .buttonStyle(.borderless)
            .help("Keyboard Shortcuts (⌘?)")

            Button {
                vm.chooseFolder()
            } label: {
                Label("Choose Folders…", systemImage: "folder")
            }
            .keyboardShortcut("o", modifiers: [.command])
        }
        .padding(12)
    }

    private var recentsAndFavoritesMenu: some View {
        Menu {
            if !favoriteFolders.isEmpty {
                Section("Favorites") {
                    ForEach(favoriteFolders) { fav in
                        Button(fav.effectiveName) { openFavorite(fav) }
                    }
                }
            }
            if !recentFolders.isEmpty {
                Section("Recent") {
                    ForEach(recentFolders.prefix(8)) { recent in
                        Button(recent.displayName) { openRecent(recent) }
                    }
                }
            }
            if let root = vm.rootURL {
                Divider()
                if FavoritesStore.isFavorited(root) {
                    Button("Remove Current from Favorites") {
                        // Find and remove by URL
                        if let match = FavoritesStore.load().first(where: { fav in
                            FavoritesStore.resolve(fav)?.url.path == root.path
                        }) {
                            FavoritesStore.remove(match.id)
                            reloadFolderLists()
                        }
                    }
                } else {
                    Button("Add Current to Favorites") {
                        FavoritesStore.add(root)
                        reloadFolderLists()
                    }
                }
            }
            if recentFolders.isEmpty && favoriteFolders.isEmpty && vm.rootURL == nil {
                Text("No recent folders yet")
            }
        } label: {
            Image(systemName: "clock.arrow.circlepath")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Recent folders and favorites")
    }

    private func openRecent(_ recent: RecentFolder) {
        guard let resolved = RecentFoldersStore.resolve(recent) else {
            vm.lastError = "Couldn't resolve folder — it may have moved."
            return
        }
        vm.adoptRoot(resolved.url)
    }

    private func openFavorite(_ favorite: FavoriteFolder) {
        guard let resolved = FavoritesStore.resolve(favorite) else {
            vm.lastError = "Couldn't resolve favorite — it may have moved."
            return
        }
        vm.adoptRoot(resolved.url)
    }

    @ViewBuilder
    private var content: some View {
        if vm.isScanning {
            VStack(spacing: 10) {
                ProgressView()
                Text("Scanning…")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                if vm.scanFoundCount > 0 {
                    Text("\(vm.scanFoundCount) folder\(vm.scanFoundCount == 1 ? "" : "s") found")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if !vm.scanCurrentPath.isEmpty {
                    Text(vm.scanCurrentPath)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 480)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if vm.items.isEmpty {
            emptyState
        } else {
            VStack(spacing: 0) {
                searchAndFilterBar
                Divider()
                list
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("Pick folders to get started")
                .font(.headline)
            Text("Iconic scans subfolders and matches each name to an SF Symbol. Select multiple folders to process them all at once.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Choose Folders…") { vm.chooseFolder() }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    private var searchAndFilterBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 13))
                TextField("Search folders...", text: $vm.searchText)
                    .textFieldStyle(.plain)
                if !vm.searchText.isEmpty {
                    Button {
                        vm.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 13))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)
            .frame(maxWidth: 280)

            Text("Filter:")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                ForEach(IconicViewModel.StatusFilter.allCases, id: \.self) { filter in
                    Button {
                        vm.statusFilter = filter
                    } label: {
                        Text(filter.rawValue)
                            .font(.caption)
                            .fontWeight(vm.statusFilter == filter ? .semibold : .regular)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(vm.statusFilter == filter ? Color.accentColor.opacity(0.15) : Color.clear)
                    .foregroundStyle(vm.statusFilter == filter ? .primary : .secondary)
                    .cornerRadius(4)
                }
            }

            Spacer()

            if !vm.selectedItemIDs.isEmpty {
                Text("\(vm.selectedItemIDs.count) selected")
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
                Button("Apply") { vm.applySelected() }
                    .controlSize(.small)
                    .disabled(vm.isDryRunMode || vm.isApplying)
                Button("Restore") { vm.restoreSelected() }
                    .controlSize(.small)
                    .disabled(vm.isDryRunMode || vm.isApplying)
                Button("Clear") { vm.clearSelection() }
                    .controlSize(.small)
                    .keyboardShortcut("d", modifiers: [.command])
            } else {
                Text("\(vm.filteredItems.count) result\(vm.filteredItems.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var list: some View {
        ScrollViewReader { proxy in
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(vm.filteredItems) { item in
                    FolderRowView(
                        item: item,
                        isDryRunMode: vm.isDryRunMode,
                        isSelected: vm.selectedItemIDs.contains(item.id),
                        onApply: { vm.apply(item) },
                        onRestore: { vm.restore(item) },
                        onSymbolEdit: { newSymbol in
                            item.symbolNames = [newSymbol]
                            vm.rerender(item)
                        },
                        onColorChange: { newColor in
                            item.symbolColor = newColor
                            vm.rerender(item)
                        },
                        onFolderColorChange: { newColor in
                            item.folderColor = newColor
                            vm.rerender(item)
                        },
                        onSelect: { vm.selectOnly(item) },
                        onToggleSelect: { vm.toggleSelection(item) },
                        onExtendSelect: { vm.extendSelection(to: item) },
                        onReveal: {
                            NSWorkspace.shared.activateFileViewerSelecting([item.url])
                        },
                        onCopyPath: {
                            let pb = NSPasteboard.general
                            pb.clearContents()
                            pb.setString(item.url.path, forType: .string)
                        },
                        onAddExcludePattern: {
                            ExcludePatternsStore.add(item.url.lastPathComponent)
                        },
                        onCopySettings: {
                            vm.copyIconSettings(from: item)
                        },
                        onPasteSettings: {
                            vm.pasteIconSettings(to: item)
                        },
                        onAdjust: {
                            vm.rerender(item)
                        },
                        onSaveAsTemplate: {
                            templateSourceItem = item
                            newTemplateName = item.displayName
                            showingSaveTemplate = true
                        },
                        templates: templatesStore.templates,
                        onApplyTemplate: { template in
                            TemplatesStore.apply(template, to: item)
                            vm.rerender(item)
                        },
                        onShowComparison: {
                            comparisonItem = item
                        }
                    )
                    .id(item.id)
                    Divider()
                }
            }
        }
        .focusable()
        .focused($listFocused)
        .onAppear { listFocused = true }
        .onKeyPress(.upArrow) {
            if let moved = vm.moveSelection(by: -1) {
                withAnimation(.easeOut(duration: 0.1)) { proxy.scrollTo(moved.id, anchor: .center) }
            }
            return .handled
        }
        .onKeyPress(.downArrow) {
            if let moved = vm.moveSelection(by: 1) {
                withAnimation(.easeOut(duration: 0.1)) { proxy.scrollTo(moved.id, anchor: .center) }
            }
            return .handled
        }
        .onKeyPress(.return) {
            if !vm.isDryRunMode, !vm.selectedItems.isEmpty {
                vm.applySelected()
                return .handled
            } else if let item = vm.focusedItem, !vm.isDryRunMode {
                vm.apply(item)
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.delete) {
            if !vm.selectedItems.isEmpty {
                vm.restoreSelected()
                return .handled
            } else if let item = vm.focusedItem {
                vm.restore(item)
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.space) {
            vm.isDryRunMode.toggle()
            return .handled
        }
        }
    }

    private var footer: some View {
        VStack(spacing: 0) {
            if vm.isDryRunMode {
                dryRunBanner
                Divider()
            }

            HStack(spacing: 10) {
                matchingModeBadge

                if vm.isApplying {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            ProgressView(value: vm.progress)
                                .progressViewStyle(.linear)
                                .frame(maxWidth: 180)
                            Text("\(vm.currentProcessingIndex + 1) / \(vm.totalProcessingCount)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                            if let remaining = vm.estimatedRemainingSeconds {
                                Text("· ~\(formattedTime(remaining)) left")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if !vm.currentProcessingPath.isEmpty {
                            Text(vm.currentProcessingPath)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .frame(maxWidth: 320, alignment: .leading)
                        }
                    }
                    Button("Cancel") { vm.cancelBatch() }
                        .controlSize(.small)
                        .keyboardShortcut(".", modifiers: [.command])
                } else if let err = vm.lastError {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(1)
                } else if vm.isDryRunMode {
                    dryRunSummary
                } else {
                    Text("\(vm.items.count) folder\(vm.items.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()

                if vm.isDryRunMode {
                    Button {
                        vm.isDryRunMode = false
                    } label: {
                        Label("Cancel Preview", systemImage: "xmark")
                    }
                    .disabled(vm.isApplying)

                    Button {
                        vm.isDryRunMode = false
                        vm.applyAll()
                    } label: {
                        Label("Looks Good? Apply Now", systemImage: "checkmark.circle.fill")
                    }
                    .keyboardShortcut(.return, modifiers: [.command])
                    .buttonStyle(.borderedProminent)
                    .disabled(vm.items.isEmpty || vm.isApplying || vm.pendingItemsCount == 0)
                } else {
                    Button {
                        vm.isDryRunMode = true
                    } label: {
                        Label("Preview Mode", systemImage: "eye")
                    }
                    .disabled(vm.items.isEmpty || vm.isApplying)

                    if vm.rootURLs.count == 1 {
                        Toggle(isOn: Binding(
                            get: { vm.isWatching },
                            set: { enabled in
                                if enabled {
                                    vm.startWatching()
                                } else {
                                    vm.stopWatching()
                                }
                            }
                        )) {
                            Label("Auto-Watch", systemImage: "eye.circle")
                        }
                        .disabled(vm.items.isEmpty || vm.isApplying)
                        .help("Automatically detect and process new folders")
                    }

                    Button {
                        showingRestoreConfirm = true
                    } label: {
                        Label(vm.hasActiveFilter ? "Restore Filtered (\(vm.batchTargets.count))" : "Restore Defaults",
                              systemImage: "arrow.uturn.backward")
                    }
                    .disabled(vm.items.isEmpty || vm.isApplying)

                    Button {
                        let conflicts = vm.foldersWithExistingIcons
                        if conflicts.isEmpty {
                            backupStore.capture(name: "Auto-snapshot \(Date())", items: vm.items, rootURL: vm.rootURL)
                            vm.applyAll()
                        } else {
                            conflictedFolders = conflicts
                            showingConflictAlert = true
                        }
                    } label: {
                        Label(vm.hasActiveFilter ? "Apply Filtered (\(vm.batchTargets.count))" : "Apply All",
                              systemImage: "checkmark.circle.fill")
                    }
                    .keyboardShortcut(.return, modifiers: [.command])
                    .buttonStyle(.borderedProminent)
                    .disabled(vm.items.isEmpty || vm.isApplying)
                }
            }
            .padding(12)
        }
    }

    private var dryRunBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "eye.fill")
                .font(.caption)
            Text("Preview Mode")
                .font(.caption)
                .fontWeight(.semibold)
            Text("Review changes before applying")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color.blue.opacity(0.1))
    }

    private var dryRunSummary: some View {
        HStack(spacing: 4) {
            if vm.pendingItemsCount > 0 {
                Text("Ready to apply icons to \(vm.pendingItemsCount) folder\(vm.pendingItemsCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
            if vm.alreadyAppliedCount > 0 {
                Text("(\(vm.alreadyAppliedCount) already applied)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var matchingModeBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: vm.matchingMode == .ai ? "sparkles" : "book.closed")
                .font(.caption)
            Text(vm.matchingMode == .ai ? "AI" : "Local")
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(vm.matchingMode == .ai ? Color.purple.opacity(0.15) : Color.gray.opacity(0.15))
        .foregroundStyle(vm.matchingMode == .ai ? .purple : .secondary)
        .cornerRadius(6)
    }

    // MARK: - Drag and Drop

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard !providers.isEmpty else { return false }

        var validURLs: [URL] = []
        let group = DispatchGroup()

        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, error in
                defer { group.leave() }
                guard error == nil,
                      let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else {
                    return
                }

                // Verify it's a directory
                var isDirectory: ObjCBool = false
                guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
                      isDirectory.boolValue else {
                    return
                }

                validURLs.append(url)
            }
        }

        group.notify(queue: .main) {
            if validURLs.isEmpty {
                vm.lastError = "Please drop folders, not files"
            } else {
                vm.adoptRoots(validURLs)
            }
        }

        return true
    }

    // MARK: - Backups Sheet

    private var backupsSheet: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Backups")
                    .font(.headline)
                Spacer()
            }

            HStack(spacing: 8) {
                TextField("Snapshot name", text: $newBackupName)
                    .textFieldStyle(.roundedBorder)
                Button("Create Snapshot") {
                    let name = newBackupName.isEmpty ? "Manual snapshot \(Date())" : newBackupName
                    backupStore.capture(name: name, items: vm.items, rootURL: vm.rootURL)
                    newBackupName = ""
                }
                .disabled(vm.items.isEmpty)
            }

            Divider()

            if backupStore.snapshots.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.arrow.2.circlepath")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No snapshots yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(backupStore.snapshots) { snapshot in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(snapshot.name)
                                    .font(.headline)
                                HStack(spacing: 8) {
                                    Text(snapshot.createdAt, style: .date)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(snapshot.createdAt, style: .time)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("·")
                                        .foregroundStyle(.secondary)
                                    Text("\(snapshot.entries.count) folder\(snapshot.entries.count == 1 ? "" : "s")")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if !snapshot.rootPath.isEmpty {
                                    Text(snapshot.rootPath)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                            }
                            Spacer()
                            Button("Restore") {
                                backupStore.restore(snapshot, into: vm.items)
                                for item in vm.items {
                                    vm.rerender(item)
                                }
                            }
                            .controlSize(.small)
                            .disabled(vm.items.isEmpty)
                            Button {
                                backupStore.remove(id: snapshot.id)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .controlSize(.small)
                            .buttonStyle(.borderless)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            HStack {
                Spacer()
                Button("Done") {
                    showingBackups = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 600, height: 400)
    }
}

#Preview {
    let mappings = CustomMappingsStore()
    let rules = RulesStore()
    let templates = TemplatesStore()
    let backups = BackupStore()
    let analytics = AnalyticsStore()
    return ContentView()
        .environmentObject(IconicViewModel(mappings: mappings, rulesStore: rules, analyticsStore: analytics))
        .environmentObject(mappings)
        .environmentObject(rules)
        .environmentObject(templates)
        .environmentObject(backups)
        .environmentObject(analytics)
}
