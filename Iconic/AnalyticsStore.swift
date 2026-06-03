//
// SPDX-License-Identifier: MIT
//  AnalyticsStore.swift
//  Iconic
//
//  Privacy-focused local analytics tracking. All data stays on device.
//

import Foundation
import SwiftUI
import Combine

/// Aggregated, on-device usage counters displayed in the Analytics preferences tab.
/// Persists to `UserDefaults`; never leaves the machine.
struct AnalyticsStats: Codable {
    var totalFoldersIconified: Int = 0
    var totalIconsApplied: Int = 0
    var totalIconsRestored: Int = 0
    var mostUsedSymbols: [String: Int] = [:]
    var sessionCount: Int = 0
    var firstLaunchDate: Date = Date()
    var lastUsedDate: Date = Date()
}

/// Observable wrapper around `AnalyticsStats` that loads from disk on init
/// and persists every mutation. All data is local — nothing is sent off-device.
@MainActor
final class AnalyticsStore: ObservableObject {
    @Published private(set) var stats: AnalyticsStats

    private let key = "iconic.analytics.v1"

    /// Loads any previously-saved stats from `UserDefaults`, then bumps the
    /// session count and refreshes `lastUsedDate`.
    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(AnalyticsStats.self, from: data) {
            stats = decoded
        } else {
            stats = AnalyticsStats()
        }

        stats.sessionCount += 1
        stats.lastUsedDate = Date()
        save()
    }

    /// Records that an icon was successfully applied to a folder.
    /// - Parameter symbolName: The SF Symbol (or emoji) name that was applied.
    func recordApply(symbolName: String) {
        stats.totalIconsApplied += 1
        stats.totalFoldersIconified += 1
        stats.mostUsedSymbols[symbolName, default: 0] += 1
        save()
    }

    /// Records that a folder's icon was restored to the system default.
    func recordRestore() {
        stats.totalIconsRestored += 1
        save()
    }

    /// Bumps the session counter and updates `lastUsedDate` without
    /// recording an apply/restore. Useful for cold-launch bookkeeping.
    func recordSession() {
        stats.sessionCount += 1
        stats.lastUsedDate = Date()
        save()
    }

    /// Wipes all analytics back to zero and persists.
    func reset() {
        stats = AnalyticsStats()
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(stats) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
