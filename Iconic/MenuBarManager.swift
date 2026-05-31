//
//  MenuBarManager.swift
//  Iconic
//
//  Manages the menu bar icon and menu.
//

import AppKit
import SwiftUI
import Combine

@MainActor
final class MenuBarManager: ObservableObject {

    private var statusItem: NSStatusItem?
    @Published var isMenuBarMode: Bool = false

    init() {
        loadPreference()
    }

    func setup() {
        guard statusItem == nil else { return }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "folder.badge.gearshape", accessibilityDescription: "Iconic")
            button.image?.isTemplate = true
            button.target = self
            button.action = #selector(statusBarButtonClicked)
        }

        updateMenu()
    }

    @objc private func statusBarButtonClicked() {
        // Show menu
        statusItem?.menu?.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    func updateMenu() {
        let menu = NSMenu()

        let showWindowItem = NSMenuItem(title: "Show Window", action: #selector(showMainWindow), keyEquivalent: "")
        showWindowItem.target = self
        menu.addItem(showWindowItem)
        menu.addItem(NSMenuItem.separator())

        let autoWatchItem = NSMenuItem(title: "Background Monitoring", action: #selector(toggleBackgroundMonitoring), keyEquivalent: "")
        autoWatchItem.target = self
        autoWatchItem.state = BackgroundMonitoringStore.isEnabled ? .on : .off
        menu.addItem(autoWatchItem)

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

    @objc func showMainWindow() {
        NSApp.sendAction(#selector(AppDelegate.showMainWindow), to: nil, from: self)
    }

    @objc func showPreferences() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func toggleBackgroundMonitoring() {
        NSApp.sendAction(#selector(AppDelegate.toggleBackgroundMonitoring), to: nil, from: self)
        updateMenu()
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    func enable() {
        setup()
        isMenuBarMode = true
        savePreference()
    }

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
