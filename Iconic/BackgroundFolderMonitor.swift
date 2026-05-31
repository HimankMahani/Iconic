//
//  BackgroundFolderMonitor.swift
//  Iconic
//
//  Monitors user's home directory for new folders and auto-applies icons.
//

import Foundation
import AppKit
import UserNotifications

@MainActor
final class BackgroundFolderMonitor {

    private var watchers: [FolderWatcher] = []
    private let rulesStore: RulesStore
    private let analyticsStore: AnalyticsStore
    private let suggestionsStore: SmartSuggestionsStore

    init() {
        // Load stores
        self.rulesStore = RulesStore()
        self.analyticsStore = AnalyticsStore()
        self.suggestionsStore = SmartSuggestionsStore()
    }

    func start() {
        stop() // Clear any existing watchers

        let locations = BackgroundMonitoringStore.monitoredLocations

        for location in locations {
            let watcher = FolderWatcher()
            watcher.start(watching: location) { [weak self] newFolderURL in
                Task { @MainActor [weak self] in
                    await self?.handleNewFolder(newFolderURL)
                }
            }
            watchers.append(watcher)
        }
    }

    func stop() {
        for watcher in watchers {
            watcher.stop()
        }
        watchers.removeAll()
    }

    private func handleNewFolder(_ url: URL) async {
        let name = url.lastPathComponent

        // Skip hidden folders
        guard !name.hasPrefix(".") else { return }

        // Check if any auto-apply rule matches
        guard let rule = rulesStore.firstMatch(for: name), rule.autoApply else {
            return
        }

        // Apply the icon
        let symbol = rule.symbol
        let symbolColor = rule.symbolColor ?? ColorPreferences.getDefaultColor()
        let folderColor = rule.folderColor

        do {
            let icon = IconRenderer.makeIcon(
                symbolName: symbol,
                tint: symbolColor,
                folderTint: folderColor
            )
            try IconApplier.apply(icon, to: url)

            // Record analytics
            analyticsStore.recordApply(symbolName: symbol)
            suggestionsStore.recordChoice(folderName: name, symbolName: symbol)

            // Show notification
            await showNotification(folderName: name, symbol: symbol)

        } catch {
            print("Failed to apply icon to \(name): \(error)")
        }
    }

    private func showNotification(folderName: String, symbol: String) async {
        guard BackgroundMonitoringStore.notificationsEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "Icon Applied"
        content.body = "Applied \(symbol) to \"\(folderName)\""
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        try? await UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - Background Monitoring Store

enum BackgroundMonitoringStore {
    private static let enabledKey = "iconic.backgroundMonitoring.enabled"
    private static let notificationsKey = "iconic.backgroundMonitoring.notifications"
    private static let locationsKey = "iconic.backgroundMonitoring.locations"

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: enabledKey)
    }

    static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: enabledKey)
    }

    static var notificationsEnabled: Bool {
        get {
            // Default to true if not set
            if UserDefaults.standard.object(forKey: notificationsKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: notificationsKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: notificationsKey)
        }
    }

    static var monitoredLocations: [URL] {
        get {
            guard let data = UserDefaults.standard.data(forKey: locationsKey),
                  let paths = try? JSONDecoder().decode([String].self, from: data) else {
                // Default to common locations
                return defaultLocations
            }
            return paths.map { URL(fileURLWithPath: $0) }
        }
        set {
            let paths = newValue.map { $0.path }
            if let data = try? JSONEncoder().encode(paths) {
                UserDefaults.standard.set(data, forKey: locationsKey)
            }
        }
    }

    static var defaultLocations: [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            home.appendingPathComponent("Desktop"),
            home.appendingPathComponent("Documents"),
            home.appendingPathComponent("Downloads")
        ]
    }

    static func addLocation(_ url: URL) {
        var locations = monitoredLocations
        if !locations.contains(where: { $0.path == url.path }) {
            locations.append(url)
            monitoredLocations = locations
        }
    }

    static func removeLocation(_ url: URL) {
        var locations = monitoredLocations
        locations.removeAll { $0.path == url.path }
        monitoredLocations = locations
    }
}
