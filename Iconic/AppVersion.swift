//
//  AppVersion.swift
//  Iconic
//
// SPDX-License-Identifier: MIT
//
//  Runtime version information, sourced from Bundle.main.infoDictionary
//  (populated from the Xcode build settings MARKETING_VERSION,
//  CURRENT_PROJECT_VERSION, and the optional GIT_COMMIT_SHA which a
//  Run Script Phase injects via UserDefaults). Surface this from the
//  "About Iconic" sheet so users can report the exact build they're on.
//

import Foundation

enum AppVersion {

    /// Marketing version (e.g. "1.0"). From MARKETING_VERSION in pbxproj.
    static let marketing: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"

    /// Build number (e.g. "1"). From CURRENT_PROJECT_VERSION in pbxproj.
    static let build: String = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"

    /// Short commit SHA (e.g. "a1b2c3d"). Set by the optional
    /// Scripts/inject-git-sha.sh run-script phase, if present. Falls
    /// back to "unknown" when the phase hasn't run (e.g. local dev
    /// builds without the phase installed).
    // TODO: add a Run Script Phase that exports GIT_COMMIT_SHA
    static let commitSHA: String = ProcessInfo.processInfo.environment["GIT_COMMIT_SHA"]
        ?? Bundle.main.infoDictionary?["GitCommitSHA"] as? String
        ?? "unknown"

    /// "1.0 (1)" or "1.0 (1) · a1b2c3d" when commit SHA is available.
    static var displayString: String {
        let base = "\(marketing) (\(build))"
        if commitSHA == "unknown" || commitSHA.isEmpty {
            return base
        }
        return "\(base) · \(commitSHA)"
    }

    /// True when this is a Debug configuration (no commit SHA injected
    /// and MARKETING_VERSION ends in "-dev" or matches "Debug"). Used
    /// by AboutView to show a "Development build" badge.
    static var isDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
}
