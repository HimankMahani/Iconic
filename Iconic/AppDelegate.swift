//
//  AppDelegate.swift
//  Iconic
//
//  Handles app lifecycle, menu bar, and background monitoring.
//

import AppKit
import SwiftUI
import UserNotifications
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {

    @Published var menuBarManager: MenuBarManager!
    var backgroundMonitor: BackgroundFolderMonitor?

    private var mainWindow: NSWindow?
    private var preferencesWindow: NSWindow?

    override init() {
        super.init()
        menuBarManager = MenuBarManager()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }

        // Setup menu bar if enabled
        if menuBarManager.isMenuBarMode {
            menuBarManager.setup()
        }

        // Start background monitoring if enabled
        if BackgroundMonitoringStore.isEnabled {
            startBackgroundMonitoring()
        }
        menuBarManager.updateMonitoringStatus(BackgroundMonitoringStore.isEnabled)

        // Find main window
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            if let window = NSApplication.shared.windows.first(where: { $0.title == "Iconic" }) {
                self?.mainWindow = window
                window.delegate = self
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Don't quit when window closes if menu bar mode is enabled
        return !menuBarManager.isMenuBarMode
    }

    @objc func showMainWindow() {
        if let window = mainWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            // Window was closed, need to recreate it
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @objc func showPreferences() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func toggleBackgroundMonitoring() {
        let newState = !BackgroundMonitoringStore.isEnabled
        BackgroundMonitoringStore.setEnabled(newState)

        if newState {
            startBackgroundMonitoring()
        } else {
            stopBackgroundMonitoring()
        }

        menuBarManager.updateMonitoringStatus(newState)
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    private func startBackgroundMonitoring() {
        guard backgroundMonitor == nil else { return }

        backgroundMonitor = BackgroundFolderMonitor()
        backgroundMonitor?.start()
    }

    private func stopBackgroundMonitoring() {
        backgroundMonitor?.stop()
        backgroundMonitor = nil
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // Keep app running in menu bar if enabled
        if menuBarManager.isMenuBarMode {
            mainWindow = notification.object as? NSWindow
        }
    }
}
