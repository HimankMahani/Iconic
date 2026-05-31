//
//  PreferencesView.swift
//  Iconic
//
//  Settings scene: edit custom keyword → SF Symbol overrides.
//

import SwiftUI
import AppKit

struct PreferencesView: View {

    @EnvironmentObject private var mappings: CustomMappingsStore
    @EnvironmentObject private var vm: IconicViewModel
    @EnvironmentObject private var rulesStore: RulesStore
    @EnvironmentObject private var templatesStore: TemplatesStore
    @EnvironmentObject private var analyticsStore: AnalyticsStore
    @EnvironmentObject private var menuBarManager: MenuBarManager
    @StateObject private var settingsVM = SettingsViewModel()
    @StateObject private var presetsStore = PresetsStore()

    @State private var newKeyword: String = ""
    @State private var newSymbol: String = ""
    @State private var smartDetectionEnabled: Bool = SmartContentDetectionStore.isEnabled
    @State private var seasonalThemeEnabled: Bool = SeasonalThemeStore.isEnabled
    @State private var backgroundMonitoringEnabled: Bool = BackgroundMonitoringStore.isEnabled
    @State private var notificationsEnabled: Bool = BackgroundMonitoringStore.notificationsEnabled
    @State private var menuBarEnabled: Bool = false
    @State private var aiContentAnalysisEnabled: Bool = AIContentAnalysisStore.isEnabled

    @State private var settingsSearchText: String = ""
    @State private var isSearching: Bool = false

    // Map of search keywords to tabs
    private let settingsKeywords: [(keyword: String, tab: String)] = [
        ("api", "Gemini AI"),
        ("key", "Gemini AI"),
        ("gemini", "Gemini AI"),
        ("ai", "Gemini AI"),
        ("color", "Appearance"),
        ("theme", "Appearance"),
        ("palette", "Appearance"),
        ("season", "Appearance"),
        ("appearance", "Appearance"),
        ("background", "Background"),
        ("menubar", "Background"),
        ("menu bar", "Background"),
        ("monitor", "Background"),
        ("notification", "Background"),
        ("auto", "Background"),
        ("mapping", "Mappings"),
        ("keyword", "Mappings"),
        ("custom", "Mappings"),
        ("rule", "Rules"),
        ("pattern", "Rules"),
        ("regex", "Rules"),
        ("glob", "Rules"),
        ("template", "Templates"),
        ("style", "Templates"),
        ("detection", "Detection"),
        ("smart", "Detection"),
        ("git", "Detection"),
        ("xcode", "Detection"),
        ("preset", "Presets"),
        ("save", "Presets"),
        ("import", "Presets"),
        ("export", "Presets"),
        ("analytics", "Analytics"),
        ("stats", "Analytics"),
        ("usage", "Analytics"),
    ]

    private var matchingTabs: Set<String> {
        let query = settingsSearchText.lowercased()
        guard !query.isEmpty else { return [] }
        return Set(settingsKeywords
            .filter { $0.keyword.contains(query) }
            .map { $0.tab })
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search settings...", text: $settingsSearchText)
                    .textFieldStyle(.plain)
                    .onTapGesture {
                        isSearching = true
                    }
                if !settingsSearchText.isEmpty {
                    Button {
                        settingsSearchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .textBackgroundColor).opacity(0.5))

            // Search suggestions when focused but empty
            if isSearching && settingsSearchText.isEmpty {
                HStack(spacing: 8) {
                    Text("Try:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(["API key", "color", "monitor", "rule"], id: \.self) { suggestion in
                        Button(suggestion) {
                            settingsSearchText = suggestion
                        }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(4)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }

            // Search results indicator
            if !settingsSearchText.isEmpty {
                if matchingTabs.isEmpty {
                    Text("No settings found for '\(settingsSearchText)'")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                } else {
                    HStack(spacing: 4) {
                        Text("Found in:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ForEach(Array(matchingTabs).sorted(), id: \.self) { tab in
                            Text(tab)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                }
                Divider()
            }

            TabView {
                geminiTab
                    .tabItem { Label("Gemini AI", systemImage: "sparkles") }
                    .padding(16)

                appearanceTab
                    .tabItem { Label("Appearance", systemImage: "paintpalette") }
                    .padding(16)

                backgroundTab
                    .tabItem { Label("Background", systemImage: "menubar.rectangle") }
                    .padding(16)

                mappingsTab
                    .tabItem { Label("Mappings", systemImage: "list.bullet.rectangle") }
                    .padding(16)

                rulesTab
                    .tabItem { Label("Rules", systemImage: "wand.and.stars") }
                    .padding(16)

                templatesTab
                    .tabItem { Label("Templates", systemImage: "square.grid.2x2") }
                    .padding(16)

                detectionTab
                    .tabItem { Label("Detection", systemImage: "magnifyingglass") }
                    .padding(16)

                presetsTab
                    .tabItem { Label("Presets", systemImage: "square.stack.3d.up") }
                    .padding(16)

                analyticsTab
                    .tabItem { Label("Analytics", systemImage: "chart.bar") }
                    .padding(16)
            }
        }
        .frame(width: 620, height: 580)
        .onAppear {
            settingsVM.loadState()
            smartDetectionEnabled = SmartContentDetectionStore.isEnabled
            seasonalThemeEnabled = SeasonalThemeStore.isEnabled
            backgroundMonitoringEnabled = BackgroundMonitoringStore.isEnabled
            notificationsEnabled = BackgroundMonitoringStore.notificationsEnabled
            menuBarEnabled = menuBarManager.isMenuBarMode
            aiContentAnalysisEnabled = AIContentAnalysisStore.isEnabled
        }
    }

    // MARK: - Gemini Tab

    private var geminiTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Gemini AI Integration")
                .font(.headline)
            Text("Use Google's Gemini AI for intelligent folder icon matching. Requires a free API key from Google AI Studio.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            if settingsVM.hasStoredKey {
                storedKeySection
            } else {
                newKeySection
            }

            Divider()

            Toggle("Use AI matching (requires API key)", isOn: Binding(
                get: { settingsVM.isAIEnabled },
                set: { settingsVM.toggleAI($0) }
            ))
            .disabled(!settingsVM.hasStoredKey)

            if !settingsVM.hasStoredKey {
                Text("Save an API key above to enable AI matching")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            Toggle("Analyze folder contents for better AI matching", isOn: $aiContentAnalysisEnabled)
                .onChange(of: aiContentAnalysisEnabled) { _, newValue in
                    AIContentAnalysisStore.isEnabled = newValue
                }
                .disabled(!settingsVM.isAIEnabled)

            if !settingsVM.isAIEnabled {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                    Text("Enable 'Use AI matching' above to use this feature")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                .padding(.leading, 20)
            }

            Text("When enabled, AI considers folder contents (file types, project markers) in addition to folder names for more accurate suggestions. May be slower for large folders.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 20)

            Spacer()

            Link("Get a free API key from Google AI Studio →", destination: URL(string: "https://aistudio.google.com/apikey")!)
                .font(.caption)
        }
    }

    private var storedKeySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("API key stored securely in Keychain")
                    .font(.subheadline)
            }

            HStack(spacing: 8) {
                Button {
                    settingsVM.testAPIKey()
                } label: {
                    if settingsVM.isTesting {
                        ProgressView().controlSize(.small)
                        Text("Testing...")
                    } else {
                        Text("Test Key")
                    }
                }
                .disabled(settingsVM.isTesting)

                Button("Remove Key") {
                    settingsVM.removeAPIKey()
                }
                .foregroundStyle(.red)
            }

            if let result = settingsVM.testResult {
                switch result {
                case .success:
                    Label("API key is valid", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                case .failure(let msg):
                    Label(msg, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
    }

    private var newKeySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Gemini API Key")
                .font(.subheadline)
            SecureField("Paste your API key here", text: $settingsVM.apiKeyInput)
                .textFieldStyle(.roundedBorder)
                .onSubmit { settingsVM.saveAPIKey() }

            HStack(spacing: 8) {
                Button("Save") {
                    settingsVM.saveAPIKey()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(settingsVM.apiKeyInput.trimmingCharacters(in: .whitespaces).isEmpty)

                Button {
                    settingsVM.testAPIKey()
                } label: {
                    if settingsVM.isTesting {
                        ProgressView().controlSize(.small)
                        Text("Testing...")
                    } else {
                        Text("Test Key")
                    }
                }
                .disabled(settingsVM.apiKeyInput.trimmingCharacters(in: .whitespaces).isEmpty || settingsVM.isTesting)
            }

            if let result = settingsVM.testResult {
                switch result {
                case .success:
                    Label("API key is valid! Click Save to store it.", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                case .failure(let msg):
                    Label(msg, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
    }

    // MARK: - Background Tab


    private var backgroundTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Background Monitoring")
                .font(.headline)
            Text("Keep Iconic running in the menu bar and automatically apply icons to new folders.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Toggle("Keep app in menu bar when window closes", isOn: $menuBarEnabled)
                    .onChange(of: menuBarEnabled) { _, newValue in
                        if newValue {
                            menuBarManager.enable()
                        } else {
                            menuBarManager.disable()
                        }
                    }

                Text("When enabled, closing the window keeps Iconic running in the menu bar. Access it from the menu bar icon.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 20)

                Divider()

                Toggle("Monitor folders for new subfolders", isOn: $backgroundMonitoringEnabled)
                    .onChange(of: backgroundMonitoringEnabled) { _, newValue in
                        BackgroundMonitoringStore.setEnabled(newValue)
                        if newValue {
                            NSApp.sendAction(#selector(AppDelegate.toggleBackgroundMonitoring), to: nil, from: nil)
                        }
                    }

                Text("Automatically detect new folders in monitored locations and apply icons based on your rules.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 20)

                if backgroundMonitoringEnabled && rulesStore.rules.filter({ $0.autoApply }).isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                        VStack(alignment: .leading) {
                            Text("No auto-apply rules configured")
                                .font(.caption)
                                .foregroundStyle(.orange)
                            Text("Create rules with 'Auto-Apply' enabled in the Rules tab for monitoring to work")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.leading, 20)
                }

                if backgroundMonitoringEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Monitored Locations:")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        ForEach(BackgroundMonitoringStore.monitoredLocations, id: \.path) { location in
                            HStack {
                                Image(systemName: "folder")
                                    .foregroundStyle(.secondary)
                                Text(location.path)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                                Button {
                                    BackgroundMonitoringStore.removeLocation(location)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(6)
                        }

                        Button("Add Location...") {
                            let panel = NSOpenPanel()
                            panel.canChooseFiles = false
                            panel.canChooseDirectories = true
                            panel.allowsMultipleSelection = false
                            panel.prompt = "Add Location"
                            if panel.runModal() == .OK, let url = panel.url {
                                BackgroundMonitoringStore.addLocation(url)
                            }
                        }
                        .controlSize(.small)
                    }
                    .padding(.leading, 20)
                }

                Divider()

                Toggle("Show notifications when icons are applied", isOn: $notificationsEnabled)
                    .onChange(of: notificationsEnabled) { _, newValue in
                        BackgroundMonitoringStore.notificationsEnabled = newValue
                    }
                    .disabled(!backgroundMonitoringEnabled)

                if !backgroundMonitoringEnabled {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                        Text("Enable 'Monitor folders' above to use notifications")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    .padding(.leading, 20)
                }

                Text("Get notified when Iconic automatically applies an icon to a new folder.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 20)
            }

            Spacer()

            if backgroundMonitoringEnabled {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.blue)
                    Text("Background monitoring only works with auto-apply rules. Create rules in the Rules tab and enable \"Auto-Apply\".")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }

    // MARK: - Appearance Tab

    private var appearanceTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Symbol Colors")
                .font(.headline)
            Text("Customize how colors are applied to folder icons.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Toggle("Automatically assign beautiful colors", isOn: Binding(
                    get: { AutoColorStore.isEnabled },
                    set: { enabled in
                        AutoColorStore.isEnabled = enabled
                        if enabled {
                            // Trigger rescan to apply colors
                            if let root = vm.rootURL {
                                Task { await vm.scan(root) }
                            }
                        }
                    }
                ))

                Text("When enabled, Iconic automatically assigns beautiful colors based on folder names and categories (e.g., blue for code, green for nature, purple for creative).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 20)

                Toggle("Use seasonal palette (\(Season.current().displayName))", isOn: $seasonalThemeEnabled)
                    .onChange(of: seasonalThemeEnabled) { _, newValue in
                        SeasonalThemeStore.isEnabled = newValue
                        if AutoColorStore.isEnabled, let root = vm.rootURL {
                            Task { await vm.scan(root) }
                        }
                    }
                    .disabled(!AutoColorStore.isEnabled)

                if !AutoColorStore.isEnabled {
                    Text("Enable 'Automatically assign beautiful colors' above to use seasonal themes")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(.leading, 20)
                }

                Text("Override category colors with a seasonal palette (Spring, Summer, Autumn, Winter). Updates automatically based on the current date.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 20)
            }

            Divider()

            Text("Default Symbol Color")
                .font(.headline)
            Text("Choose the default color for SF Symbols when auto-color is disabled. You can override this per-folder using the color picker in the main list.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                ColorPicker("Default Color", selection: Binding(
                    get: { Color(ColorPreferences.getDefaultColor()) },
                    set: { newColor in
                        let nsColor = NSColor(newColor)
                        ColorPreferences.setDefaultColor(nsColor)
                        rerenderAll()
                    }
                ))
                .frame(maxWidth: 200)

                Button("Reset to White") {
                    ColorPreferences.setDefaultColor(.white)
                    rerenderAll()
                }
                .buttonStyle(.bordered)
            }

            Spacer()
        }
    }

    // MARK: - Matching Priority Banner

    private var matchingPriorityBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text("Matching Priority")
                    .font(.caption)
                    .fontWeight(.semibold)
                Text("Rules → Smart Detection → Custom Mappings → AI → Built-in Dictionary")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(10)
        .background(Color.blue.opacity(0.08))
        .cornerRadius(6)
    }

    // MARK: - Mappings Tab

    private var mappingsTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Custom Keyword Mappings")
                .font(.headline)
            Text("Custom mappings override the built-in dictionary. Keyword matching is case-insensitive.")
                .font(.caption)
                .foregroundStyle(.secondary)

            matchingPriorityBanner

            addRow

            Divider()

            if mappings.mappings.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text("No custom mappings yet")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(mappings.mappings) { m in
                        MappingRow(mapping: m)
                    }
                    .onDelete { offsets in
                        mappings.remove(at: offsets)
                        rerenderAll()
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    private var addRow: some View {
        HStack(spacing: 8) {
            TextField("Keyword (e.g. clients)", text: $newKeyword)
                .textFieldStyle(.roundedBorder)
            Image(systemName: "arrow.right")
                .foregroundStyle(.secondary)
            TextField("SF Symbol (e.g. person.2.fill)", text: $newSymbol)
                .textFieldStyle(.roundedBorder)
            symbolValidityIndicator(for: newSymbol)
            Button("Add") {
                let k = newKeyword.trimmingCharacters(in: .whitespaces)
                let s = newSymbol.trimmingCharacters(in: .whitespaces)
                guard !k.isEmpty, !s.isEmpty else { return }
                mappings.add(CustomMapping(keyword: k, symbol: s))
                newKeyword = ""
                newSymbol = ""
                rerenderAll()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(newKeyword.trimmingCharacters(in: .whitespaces).isEmpty
                      || newSymbol.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    @ViewBuilder
    private func symbolValidityIndicator(for name: String) -> some View {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            EmptyView()
        } else if NSImage(systemSymbolName: trimmed, accessibilityDescription: nil) != nil {
            Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
        } else {
            Image(systemName: "questionmark.circle").foregroundStyle(.orange)
        }
    }

    private func rerenderAll() {
        for item in vm.items { vm.refreshSymbol(for: item) }
    }

    // MARK: - Rules Tab

    @State private var newRulePattern: String = ""
    @State private var newRuleSymbol: String = ""
    @State private var newRuleMatchType: RuleMatchType = .contains

    private var rulesTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Matching Rules")
                .font(.headline)
            Text("Rules take priority over all other matching. Higher-priority rules apply first. Enable Auto-Apply to apply matching icons immediately after scan.")
                .font(.caption)
                .foregroundStyle(.secondary)

            matchingPriorityBanner

            VStack(alignment: .leading, spacing: 4) {
                Text("Match Types:")
                    .font(.caption)
                    .fontWeight(.semibold)
                Text("• Contains: matches if pattern appears anywhere in folder name")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("• Exact: matches only if folder name equals pattern")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("• Glob: use * and ? wildcards (e.g. \"client-*\")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("• Regex: use regular expressions for complex patterns")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(8)
            .background(Color.gray.opacity(0.08))
            .cornerRadius(6)

            HStack(spacing: 6) {
                TextField("Pattern", text: $newRulePattern)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 160)
                Picker("", selection: $newRuleMatchType) {
                    ForEach(RuleMatchType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 130)
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                TextField("SF Symbol", text: $newRuleSymbol)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 140)
                Button("Add") {
                    let p = newRulePattern.trimmingCharacters(in: .whitespaces)
                    let s = newRuleSymbol.trimmingCharacters(in: .whitespaces)
                    guard !p.isEmpty, !s.isEmpty else { return }
                    rulesStore.add(IconRule(
                        name: p,
                        pattern: p,
                        matchType: newRuleMatchType,
                        symbol: s,
                        priority: rulesStore.rules.count
                    ))
                    newRulePattern = ""
                    newRuleSymbol = ""
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newRulePattern.trimmingCharacters(in: .whitespaces).isEmpty
                          || newRuleSymbol.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            Divider()

            if rulesStore.rules.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "wand.and.stars")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text("No rules yet")
                        .foregroundStyle(.secondary)
                    Text("Rules let you map folder name patterns to specific icons.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(rulesStore.rules) { rule in
                        RuleRow(rule: rule, onUpdate: { updated in
                            rulesStore.update(updated)
                            rerenderAll()
                        })
                    }
                    .onDelete { offsets in
                        rulesStore.remove(at: offsets)
                        rerenderAll()
                    }
                    .onMove { source, dest in
                        rulesStore.move(from: source, to: dest)
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    // MARK: - Templates Tab

    private var templatesTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Icon Templates")
                .font(.headline)
            Text("Templates bundle a symbol, colors, opacity, scale, and position. Use them to apply consistent themes across folders.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            if templatesStore.templates.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "square.grid.2x2")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text("No templates yet")
                        .foregroundStyle(.secondary)
                    Text("Right-click a folder in the main view → \"Save as Template\" to create one.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(templatesStore.templates) { template in
                        HStack(spacing: 10) {
                            ZStack {
                                if let folderColor = template.folderColor {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color(folderColor))
                                        .frame(width: 36, height: 36)
                                } else {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(.quaternary)
                                        .frame(width: 36, height: 36)
                                }
                                Image(systemName: NSImage(systemSymbolName: template.symbol, accessibilityDescription: nil) != nil ? template.symbol : "questionmark")
                                    .foregroundStyle(template.symbolColor.map { Color($0) } ?? .secondary)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(template.name)
                                    .font(.body)
                                Text(template.symbol)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if !vm.selectedItems.isEmpty {
                                Button("Apply to \(vm.selectedItems.count) selected") {
                                    for item in vm.selectedItems {
                                        TemplatesStore.apply(template, to: item)
                                        vm.rerender(item)
                                    }
                                }
                                .controlSize(.small)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .onDelete { offsets in
                        templatesStore.remove(at: offsets)
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    // MARK: - Detection Tab

    private var detectionTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Smart Content Detection")
                .font(.headline)
            Text("Analyze folder contents to automatically detect special types like git repos, Xcode projects, and media folders.")
                .font(.caption)
                .foregroundStyle(.secondary)

            matchingPriorityBanner

            Divider()

            Toggle("Enable smart content detection", isOn: $smartDetectionEnabled)
                .onChange(of: smartDetectionEnabled) { _, newValue in
                    SmartContentDetectionStore.isEnabled = newValue
                }

            if smartDetectionEnabled {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Detected folder types:")
                        .font(.subheadline)
                        .padding(.top, 8)

                    detectionTypeRow(icon: "arrow.triangle.branch", label: "Git repositories", description: "Folders containing .git")
                    detectionTypeRow(icon: "hammer.fill", label: "Xcode projects", description: "Folders containing .xcodeproj")
                    detectionTypeRow(icon: "cube.fill", label: "Node.js projects", description: "Folders containing package.json")
                    detectionTypeRow(icon: "chevron.left.forwardslash.chevron.right", label: "Python projects", description: "Folders with requirements.txt or setup.py")
                    detectionTypeRow(icon: "shippingbox.fill", label: "Docker projects", description: "Folders containing Dockerfile")
                    detectionTypeRow(icon: "photo.stack", label: "Photo folders", description: "Folders with mostly image files")
                    detectionTypeRow(icon: "film.stack.fill", label: "Video folders", description: "Folders with mostly video files")
                }
                .padding(.leading, 20)
            }

            Spacer()

            Text("Note: Content detection takes priority over custom mappings and AI suggestions when enabled.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func detectionTypeRow(icon: String, label: String, description: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.body)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Presets Tab

    private var presetsTab: some View {
        PresetsTabView(
            presetsStore: presetsStore,
            mappings: mappings,
            settingsVM: settingsVM,
            onPresetLoaded: { rerenderAll() }
        )
    }

    // MARK: - Analytics Tab

    private var analyticsTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Usage Analytics")
                .font(.headline)
            Text("All analytics data is stored locally on your device. Nothing is sent to external servers.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total Folders Iconified")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("\(analyticsStore.stats.totalFoldersIconified)")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Icons Applied")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("\(analyticsStore.stats.totalIconsApplied)")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Icons Restored")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("\(analyticsStore.stats.totalIconsRestored)")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sessions")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("\(analyticsStore.stats.sessionCount)")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Member Since")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(analyticsStore.stats.firstLaunchDate, style: .date)
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Last Used")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(analyticsStore.stats.lastUsedDate, style: .date)
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
            }

            Divider()

            Text("Most Used Symbols")
                .font(.headline)

            if analyticsStore.stats.mostUsedSymbols.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "chart.bar")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text("No symbols used yet")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(analyticsStore.stats.mostUsedSymbols.sorted { $0.value > $1.value }.prefix(10)), id: \.key) { symbol, count in
                            HStack(spacing: 12) {
                                Image(systemName: symbol)
                                    .frame(width: 24)
                                    .foregroundStyle(.blue)
                                Text(symbol)
                                    .font(.system(.body, design: .monospaced))
                                Spacer()
                                Text("\(count)")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .frame(maxHeight: 180)
            }

            Spacer()

            Button("Reset Analytics") {
                analyticsStore.reset()
            }
            .buttonStyle(.bordered)
            .foregroundStyle(.red)
        }
    }
}

private struct RuleRow: View {
    let rule: IconRule
    let onUpdate: (IconRule) -> Void

    @State private var isEditing = false
    @State private var draftPattern: String = ""
    @State private var draftSymbol: String = ""
    @State private var draftMatchType: RuleMatchType = .contains

    var body: some View {
        HStack(spacing: 8) {
            Toggle("", isOn: Binding(
                get: { rule.enabled },
                set: { var copy = rule; copy.enabled = $0; onUpdate(copy) }
            ))
            .labelsHidden()

            Image(systemName: NSImage(systemSymbolName: rule.symbol, accessibilityDescription: nil) != nil ? rule.symbol : "questionmark")
                .frame(width: 22)

            if isEditing {
                TextField("Pattern", text: $draftPattern)
                    .textFieldStyle(.roundedBorder)
                Picker("", selection: $draftMatchType) {
                    ForEach(RuleMatchType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 130)
                TextField("Symbol", text: $draftSymbol)
                    .textFieldStyle(.roundedBorder)
                Button("Save") {
                    var updated = rule
                    updated.pattern = draftPattern
                    updated.matchType = draftMatchType
                    updated.symbol = draftSymbol
                    onUpdate(updated)
                    isEditing = false
                }
                .keyboardShortcut(.defaultAction)
                Button("Cancel") { isEditing = false }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(rule.pattern)
                        .font(.body)
                    HStack(spacing: 6) {
                        Text(rule.matchType.displayName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("→")
                            .foregroundStyle(.secondary)
                        Text(rule.symbol)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Toggle("Auto", isOn: Binding(
                    get: { rule.autoApply },
                    set: { var copy = rule; copy.autoApply = $0; onUpdate(copy) }
                ))
                .toggleStyle(.checkbox)
                .help("Auto-apply this rule's icon when scanning")

                Button {
                    draftPattern = rule.pattern
                    draftSymbol = rule.symbol
                    draftMatchType = rule.matchType
                    isEditing = true
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct MappingRow: View {
    @EnvironmentObject private var mappings: CustomMappingsStore
    @EnvironmentObject private var vm: IconicViewModel

    let mapping: CustomMapping

    @State private var keyword: String = ""
    @State private var symbol: String = ""
    @State private var isEditing = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: NSImage(systemSymbolName: mapping.symbol, accessibilityDescription: nil) != nil ? mapping.symbol : "questionmark")
                .frame(width: 22)

            if isEditing {
                TextField("Keyword", text: $keyword)
                    .textFieldStyle(.roundedBorder)
                TextField("Symbol", text: $symbol)
                    .textFieldStyle(.roundedBorder)
                Button("Save") {
                    mappings.update(id: mapping.id, keyword: keyword, symbol: symbol)
                    isEditing = false
                    for item in vm.items { vm.refreshSymbol(for: item) }
                }
                .keyboardShortcut(.defaultAction)
                Button("Cancel") { isEditing = false }
            } else {
                Text(mapping.keyword)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("→").foregroundStyle(.secondary)
                Text(mapping.symbol)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    keyword = mapping.keyword
                    symbol = mapping.symbol
                    isEditing = true
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Presets Tab View

private struct PresetsTabView: View {
    @ObservedObject var presetsStore: PresetsStore
    @ObservedObject var mappings: CustomMappingsStore
    @ObservedObject var settingsVM: SettingsViewModel

    let onPresetLoaded: () -> Void

    @State private var newPresetName: String = ""
    @State private var showingSaveSheet = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var editingPresetId: UUID?
    @State private var editingName: String = ""
    @State private var showingImportPicker = false
    @State private var showingExportPicker = false
    @State private var presetToExport: Preset?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Configuration Presets")
                .font(.headline)
            Text("Save and load complete configurations including custom mappings and AI settings.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button {
                    showingSaveSheet = true
                } label: {
                    Label("Save Current as Preset", systemImage: "square.and.arrow.down")
                }

                Button {
                    showingImportPicker = true
                } label: {
                    Label("Import", systemImage: "square.and.arrow.down.on.square")
                }
            }

            Divider()

            if presetsStore.presets.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "square.stack.3d.up")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text("No presets saved yet")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(presetsStore.presets) { preset in
                        PresetRow(
                            preset: preset,
                            isEditing: editingPresetId == preset.id,
                            editingName: $editingName,
                            onLoad: {
                                loadPreset(preset)
                            },
                            onExport: {
                                presetToExport = preset
                                showingExportPicker = true
                            },
                            onEdit: {
                                editingPresetId = preset.id
                                editingName = preset.name
                            },
                            onSaveEdit: {
                                do {
                                    try presetsStore.rename(id: preset.id, newName: editingName)
                                    editingPresetId = nil
                                } catch {
                                    errorMessage = error.localizedDescription
                                    showingError = true
                                }
                            },
                            onCancelEdit: {
                                editingPresetId = nil
                            }
                        )
                    }
                    .onDelete { offsets in
                        presetsStore.delete(at: offsets)
                    }
                }
                .listStyle(.inset)
            }
        }
        .sheet(isPresented: $showingSaveSheet) {
            SavePresetSheet(
                presetName: $newPresetName,
                onSave: {
                    saveCurrentPreset()
                },
                onCancel: {
                    showingSaveSheet = false
                    newPresetName = ""
                }
            )
        }
        .fileImporter(
            isPresented: $showingImportPicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .fileExporter(
            isPresented: $showingExportPicker,
            document: presetToExport.map { PresetDocument(preset: $0) },
            contentType: .json,
            defaultFilename: presetToExport.map { "\($0.name).iconic.json" }
        ) { result in
            handleExport(result)
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { showingError = false }
        } message: {
            Text(errorMessage)
        }
    }

    private func saveCurrentPreset() {
        do {
            try presetsStore.saveCurrentAsPreset(
                name: newPresetName,
                mappings: mappings.mappings,
                aiEnabled: settingsVM.isAIEnabled
            )
            showingSaveSheet = false
            newPresetName = ""
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    private func loadPreset(_ preset: Preset) {
        let config = presetsStore.loadPreset(preset)

        // Clear existing mappings
        let allIndices = IndexSet(integersIn: 0..<mappings.mappings.count)
        mappings.remove(at: allIndices)

        // Add preset mappings
        for mapping in config.customMappings {
            mappings.add(mapping)
        }

        // Update AI setting
        settingsVM.toggleAI(config.aiEnabled)

        // Refresh all icons
        onPresetLoaded()
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                try presetsStore.importPreset(from: url)
            } catch {
                errorMessage = "Failed to import preset: \(error.localizedDescription)"
                showingError = true
            }
        case .failure(let error):
            errorMessage = "Failed to select file: \(error.localizedDescription)"
            showingError = true
        }
    }

    private func handleExport(_ result: Result<URL, Error>) {
        presetToExport = nil
        switch result {
        case .success:
            break // File saved successfully
        case .failure(let error):
            errorMessage = "Failed to export preset: \(error.localizedDescription)"
            showingError = true
        }
    }
}

// MARK: - Preset Row

private struct PresetRow: View {
    let preset: Preset
    let isEditing: Bool
    @Binding var editingName: String

    let onLoad: () -> Void
    let onExport: () -> Void
    let onEdit: () -> Void
    let onSaveEdit: () -> Void
    let onCancelEdit: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "square.stack.3d.up.fill")
                .foregroundStyle(.blue)
                .frame(width: 22)

            if isEditing {
                TextField("Preset name", text: $editingName)
                    .textFieldStyle(.roundedBorder)
                Button("Save") {
                    onSaveEdit()
                }
                .keyboardShortcut(.defaultAction)
                Button("Cancel") {
                    onCancelEdit()
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.name)
                        .font(.body)
                    HStack(spacing: 8) {
                        Label("\(preset.customMappings.count) mappings", systemImage: "list.bullet")
                        if preset.aiEnabled {
                            Label("AI enabled", systemImage: "sparkles")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    onLoad()
                } label: {
                    Label("Load", systemImage: "arrow.down.circle")
                }
                .buttonStyle(.borderless)

                Button {
                    onExport()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .buttonStyle(.borderless)
                .help("Export preset")

                Button {
                    onEdit()
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)
                .help("Rename preset")
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Save Preset Sheet

private struct SavePresetSheet: View {
    @Binding var presetName: String
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Save Current Configuration")
                .font(.headline)

            TextField("Preset name", text: $presetName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)
                .onSubmit {
                    if !presetName.trimmingCharacters(in: .whitespaces).isEmpty {
                        onSave()
                    }
                }

            HStack(spacing: 12) {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Button("Save") {
                    onSave()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(presetName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 400, height: 150)
    }
}

// MARK: - Preset Document (for file export)

import UniformTypeIdentifiers

private struct PresetDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    let preset: Preset

    init(preset: Preset) {
        self.preset = preset
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        preset = try decoder.decode(Preset.self, from: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(preset)
        return FileWrapper(regularFileWithContents: data)
    }
}

#Preview {
    let m = CustomMappingsStore()
    let r = RulesStore()
    let t = TemplatesStore()
    let a = AnalyticsStore()
    let v = IconicViewModel(mappings: m, rulesStore: r, analyticsStore: a)
    return PreferencesView()
        .environmentObject(m)
        .environmentObject(v)
        .environmentObject(r)
        .environmentObject(t)
        .environmentObject(a)
}
