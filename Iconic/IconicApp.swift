//
//  IconicApp.swift
//  Iconic
//

import SwiftUI

@main
struct IconicApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var mappings: CustomMappingsStore
    @StateObject private var vm: IconicViewModel
    @StateObject private var rulesStore: RulesStore
    @StateObject private var templatesStore: TemplatesStore
    @StateObject private var backupStore: BackupStore
    @StateObject private var analyticsStore: AnalyticsStore
    @StateObject private var suggestionsStore: SmartSuggestionsStore
    @StateObject private var learningStore: AILearningStore

    @AppStorage("iconic.onboardingCompleted") private var onboardingCompleted = false

    init() {
        let m = CustomMappingsStore()
        let r = RulesStore()
        let t = TemplatesStore()
        let b = BackupStore()
        let a = AnalyticsStore()
        let s = SmartSuggestionsStore()
        let l = AILearningStore()
        _mappings = StateObject(wrappedValue: m)
        _rulesStore = StateObject(wrappedValue: r)
        _templatesStore = StateObject(wrappedValue: t)
        _backupStore = StateObject(wrappedValue: b)
        _analyticsStore = StateObject(wrappedValue: a)
        _suggestionsStore = StateObject(wrappedValue: s)
        _learningStore = StateObject(wrappedValue: l)
        _vm = StateObject(wrappedValue: IconicViewModel(mappings: m, rulesStore: r, analyticsStore: a, suggestionsStore: s, learningStore: l))
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
                .environmentObject(learningStore)
                .environmentObject(appDelegate.menuBarManager)
                .sheet(isPresented: Binding(
                    get: { !onboardingCompleted },
                    set: { newValue in if !newValue { onboardingCompleted = true } }
                )) {
                    OnboardingView()
                }
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
                .environmentObject(learningStore)
                .environmentObject(appDelegate.menuBarManager)
        }
    }
}
