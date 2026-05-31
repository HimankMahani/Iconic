//
//  IconicApp.swift
//  Iconic
//

import SwiftUI

@main
struct IconicApp: App {

    @StateObject private var mappings: CustomMappingsStore
    @StateObject private var vm: IconicViewModel
    @StateObject private var rulesStore: RulesStore
    @StateObject private var templatesStore: TemplatesStore
    @StateObject private var backupStore: BackupStore
    @StateObject private var analyticsStore: AnalyticsStore
    @StateObject private var suggestionsStore: SmartSuggestionsStore

    init() {
        let m = CustomMappingsStore()
        let r = RulesStore()
        let t = TemplatesStore()
        let b = BackupStore()
        let a = AnalyticsStore()
        let s = SmartSuggestionsStore()
        _mappings = StateObject(wrappedValue: m)
        _rulesStore = StateObject(wrappedValue: r)
        _templatesStore = StateObject(wrappedValue: t)
        _backupStore = StateObject(wrappedValue: b)
        _analyticsStore = StateObject(wrappedValue: a)
        _suggestionsStore = StateObject(wrappedValue: s)
        _vm = StateObject(wrappedValue: IconicViewModel(mappings: m, rulesStore: r, analyticsStore: a, suggestionsStore: s))
    }

    var body: some Scene {
        WindowGroup("Iconic") {
            ContentView()
                .environmentObject(mappings)
                .environmentObject(vm)
                .environmentObject(rulesStore)
                .environmentObject(templatesStore)
                .environmentObject(backupStore)
                .environmentObject(analyticsStore)
                .environmentObject(suggestionsStore)
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }

        Settings {
            PreferencesView()
                .environmentObject(mappings)
                .environmentObject(vm)
                .environmentObject(rulesStore)
                .environmentObject(templatesStore)
                .environmentObject(backupStore)
                .environmentObject(analyticsStore)
                .environmentObject(suggestionsStore)
        }
    }
}
