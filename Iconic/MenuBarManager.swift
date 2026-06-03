//
// SPDX-License-Identifier: MIT
//  MenuBarManager.swift
//  Iconic
//
//  Manages the menu bar icon and menu.
//

import AppKit
import SwiftUI
import Combine

/// Owns the menu bar (status bar) item shown when "Keep app in menu bar"
/// is enabled in Preferences. Builds the dropdown menu, toggles the
/// background-monitoring state, and bridges clicks to `AppDelegate`.
@MainActor
final class MenuBarManager: ObservableObject {

    private var statusItem: NSStatusItem?
    @Published var isMenuBarMode: Bool = false
    private var isMonitoringActive: Bool = false

    /// Loads the persisted menu-bar preference and, if enabled, installs the
    /// status item immediately.
    init() {
        loadPreference()
    }

    /// Creates the `NSStatusItem` (no-op if already installed), wires up its
    /// button, and renders the initial menu based on the current monitoring state.
    func setup() {
        guard statusItem == nil else { return }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "folder.badge.gearshape", accessibilityDescription: "Iconic")
            button.image?.isTemplate = true
            button.target = self
            button.action = #selector(statusBarButtonClicked)
        }

        // Reflect current monitoring state in icon and menu
        isMonitoringActive = BackgroundMonitoringStore.isEnabled
        updateMenuBarIcon()
        updateMenu()
    }

    @objc private func statusBarButtonClicked() {
        // Show menu
        statusItem?.menu?.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    /// Updates the cached monitoring state and re-renders the icon and menu
    /// to reflect it. Call this whenever background monitoring is toggled.
    /// - Parameter active: Whether background monitoring is currently enabled.
    func updateMonitoringStatus(_ active: Bool) {
        isMonitoringActive = active
        updateMenuBarIcon()
        updateMenu()
    }

    private func updateMenuBarIcon() {
        guard let button = statusItem?.button else { return }

        if isMonitoringActive {
            // Active monitoring - filled icon
            button.image = NSImage(systemSymbolName: "folder.badge.gearshape", accessibilityDescription: "Iconic - Monitoring Active")
        } else {
            // Inactive - outlined icon
            button.image = NSImage(systemSymbolName: "folder.badge.gearshape", accessibilityDescription: "Iconic")
        }
        button.image?.isTemplate = true
    }

    /// Rebuilds and installs the dropdown menu on the current status item.
    /// Includes a status header, Show Window, background-monitoring toggle,
    /// Preferences…, and Quit.
    func updateMenu() {
        let menu = NSMenu()

        // Status header
        let statusHeaderItem = NSMenuItem(title: isMonitoringActive ? "\u{25CF} Monitoring Active" : "\u{25CB} Monitoring Inactive", action: nil, keyEquivalent: "")
        statusHeaderItem.isEnabled = false
        menu.addItem(statusHeaderItem)
        menu.addItem(NSMenuItem.separator())

        let showWindowItem = NSMenuItem(title: "Show Window", action: #selector(showMainWindow), keyEquivalent: "")
        showWindowItem.target = self
        menu.addItem(showWindowItem)

        menu.addItem(NSMenuItem.separator())

        let monitoringItem = NSMenuItem(
            title: isMonitoringActive ? "Disable Background Monitoring" : "Enable Background Monitoring",
            action: #selector(toggleBackgroundMonitoring),
            keyEquivalent: ""
        )
        monitoringItem.target = self
        monitoringItem.state = isMonitoringActive ? .on : .off
        menu.addItem(monitoringItem)

        if isMonitoringActive {
            // Show monitored count if active
            let count = BackgroundMonitoringStore.monitoredLocations.count
            let countItem = NSMenuItem(
                title: "  Monitoring \(count) location\(count == 1 ? "" : "s")",
                action: nil,
                keyEquivalent: ""
            )
            countItem.isEnabled = false
            menu.addItem(countItem)
        }

        menu.addItem(NSMenuItem.separator())

        let prefsItem = NSMenuItem(title: "Preferences...", action: #selector(showPreferences), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit Iconic", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    /// Menu action: brings the main window to the front via `AppDelegate`.
    @objc func showMainWindow() {
        NSApp.sendAction(#selector(AppDelegate.showMainWindow), to: nil, from: self)
    }

    /// Menu action: opens the Preferences window and activates the app.
    @objc func showPreferences() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Menu action: asks `AppDelegate` to flip background monitoring.
    /// `AppDelegate` is expected to call back into `updateMonitoringStatus(_:)`
    /// so the icon and menu refresh.
    @objc func toggleBackgroundMonitoring() {
        NSApp.sendAction(#selector(AppDelegate.toggleBackgroundMonitoring), to: nil, from: self)
        // AppDelegate will call updateMonitoringStatus(_:) to refresh icon/menu
    }

    /// Menu action: terminates the app.
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    /// Installs the status item (if not already) and persists the
    /// "menu bar mode enabled" preference.
    func enable() {
        setup()
        isMenuBarMode = true
        savePreference()
    }

    /// Removes the status item and persists the disabled preference.
    func disable() {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
        isMenuBarMode = false
        savePreference()
    }

    private func loadPreference() {
        isMenuBarMode = UserDefaults.standard.bool(forKey: "iconic.menuBar.enabled")
        if isMenuBarMode {
            setup()
        }
    }

    private func savePreference() {
        UserDefaults.standard.set(isMenuBarMode, forKey: "iconic.menuBar.enabled")
    }
}
