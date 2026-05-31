//
//  KeychainHelper.swift
//  Iconic
//
//  Secure storage for Gemini API key using Keychain Services.
//  Never logs key values.
//

import Foundation
import Security

enum KeychainHelper {

    private static let service = "com.app.Iconic.gemini"
    private static let account = "gemini-api-key"

    enum KeychainError: LocalizedError {
        case saveFailed(OSStatus)
        case loadFailed(OSStatus)
        case deleteFailed(OSStatus)
        case unexpectedData

        var errorDescription: String? {
            switch self {
            case .saveFailed(let status):
                return "Failed to save API key to Keychain (status: \(status))"
            case .loadFailed(let status):
                return "Failed to load API key from Keychain (status: \(status))"
            case .deleteFailed(let status):
                return "Failed to delete API key from Keychain (status: \(status))"
            case .unexpectedData:
                return "Keychain returned unexpected data format"
            }
        }
    }

    /// Saves the API key to Keychain. Overwrites if already exists.
    static func saveAPIKey(_ key: String) throws {
        guard let data = key.data(using: .utf8) else {
            throw KeychainError.unexpectedData
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]

        // Try to delete existing first
        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    /// Loads the API key from Keychain. Returns nil if not found.
    static func loadAPIKey() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw KeychainError.loadFailed(status)
        }

        guard let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            throw KeychainError.unexpectedData
        }

        return key
    }

    /// Deletes the API key from Keychain.
    static func deleteAPIKey() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    /// Returns true if an API key exists in Keychain.
    static func hasAPIKey() -> Bool {
        (try? loadAPIKey()) != nil
    }
}
