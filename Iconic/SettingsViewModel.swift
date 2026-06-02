//
// SPDX-License-Identifier: MIT
//  SettingsViewModel.swift
//  Iconic
//
//  Manages Gemini API key state, validation, and enable/disable toggle.
//

import Foundation
import Combine

@MainActor
final class SettingsViewModel: ObservableObject {

    @Published var apiKeyInput: String = ""
    @Published var isAIEnabled: Bool = false
    @Published var isTesting: Bool = false
    @Published var testResult: TestResult?
    @Published var hasStoredKey: Bool = false

    enum TestResult {
        case success
        case failure(String)
    }

    init() {
        loadState()
    }

    func loadState() {
        hasStoredKey = KeychainHelper.hasAPIKey()
        isAIEnabled = hasStoredKey && UserDefaults.standard.bool(forKey: "iconic.aiEnabled")
    }

    func saveAPIKey() {
        let trimmed = apiKeyInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        do {
            try KeychainHelper.saveAPIKey(trimmed)
            hasStoredKey = true
            apiKeyInput = ""
            testResult = nil
        } catch {
            testResult = .failure("Failed to save: \(error.localizedDescription)")
        }
    }

    func removeAPIKey() {
        do {
            try KeychainHelper.deleteAPIKey()
            hasStoredKey = false
            isAIEnabled = false
            apiKeyInput = ""
            testResult = nil
            UserDefaults.standard.set(false, forKey: "iconic.aiEnabled")
        } catch {
            testResult = .failure("Failed to remove: \(error.localizedDescription)")
        }
    }

    func testAPIKey() {
        let keyToTest: String
        if !apiKeyInput.trimmingCharacters(in: .whitespaces).isEmpty {
            keyToTest = apiKeyInput.trimmingCharacters(in: .whitespaces)
        } else if let stored = try? KeychainHelper.loadAPIKey() {
            keyToTest = stored
        } else {
            testResult = .failure("No API key to test")
            return
        }

        isTesting = true
        testResult = nil

        Task {
            do {
                try await GeminiService.testAPIKey(keyToTest)
                await MainActor.run {
                    isTesting = false
                    testResult = .success
                }
            } catch {
                await MainActor.run {
                    isTesting = false
                    testResult = .failure(error.localizedDescription)
                }
            }
        }
    }

    func toggleAI(_ enabled: Bool) {
        isAIEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "iconic.aiEnabled")
    }

    /// Returns the stored API key if AI is enabled and key exists.
    static func getAPIKeyIfEnabled() -> String? {
        guard UserDefaults.standard.bool(forKey: "iconic.aiEnabled"),
              let key = try? KeychainHelper.loadAPIKey() else {
            return nil
        }
        return key
    }
}
