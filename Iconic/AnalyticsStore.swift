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

struct AnalyticsStats: Codable {
    var totalFoldersIconified: Int = 0
    var totalIconsApplied: Int = 0
    var totalIconsRestored: Int = 0
    var mostUsedSymbols: [String: Int] = [:]
    var sessionCount: Int = 0
    var firstLaunchDate: Date = Date()
    var lastUsedDate: Date = Date()
}

@MainActor
final class AnalyticsStore: ObservableObject {
    @Published private(set) var stats: AnalyticsStats

    private let key = "iconic.analytics.v1"

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

    func recordApply(symbolName: String) {
        stats.totalIconsApplied += 1
        stats.totalFoldersIconified += 1
        stats.mostUsedSymbols[symbolName, default: 0] += 1
        save()
    }

    func recordRestore() {
        stats.totalIconsRestored += 1
        save()
    }

    func recordSession() {
        stats.sessionCount += 1
        stats.lastUsedDate = Date()
        save()
    }

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
