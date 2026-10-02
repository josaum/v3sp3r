import Foundation
import Security

/// Keychain-backed storage for the LLM provider API key.
///
/// The key previously lived in `UserDefaults`, which is a plaintext plist on
/// disk. This stores it in the login Keychain instead and migrates any existing
/// plaintext value on first read, so upgrading users do not lose their key.
///
/// Non-secret settings intentionally stay in `UserDefaults` — see `Settings`.
enum SecretStore {
    private static let service = "com.ferriteos.suite"
    private static let legacyDefaultsKey = "openRouterApiKey"

    /// Reads the API key, migrating a legacy plaintext `UserDefaults` value if
    /// one is present. Returns "" when no key is stored anywhere.
    static func apiKey(defaults: UserDefaults) -> String {
        if let key = read(account: "openRouterApiKey"), !key.isEmpty {
            return key
        }
        // Migrate: plaintext UserDefaults -> Keychain, then scrub the original.
        guard let legacy = defaults.string(forKey: legacyDefaultsKey), !legacy.isEmpty else {
            return ""
        }
        if write(legacy, account: "openRouterApiKey") {
            defaults.removeObject(forKey: legacyDefaultsKey)
        }
        return legacy
    }

    /// Persists the API key to the Keychain. Also clears any legacy plaintext copy.
    static func setAPIKey(_ key: String, defaults: UserDefaults) {
        if key.isEmpty {
            delete(account: "openRouterApiKey")
        } else {
            write(key, account: "openRouterApiKey")
        }
        defaults.removeObject(forKey: legacyDefaultsKey)
    }

    // MARK: - Keychain primitives

    private static func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    private static func read(account: String) -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8)
        else { return nil }
        return value
    }

    @discardableResult
    private static func write(_ value: String, account: String) -> Bool {
        let data = Data(value.utf8)
        let query = baseQuery(account: account)

        let attributes: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecSuccess { return true }

        if status == errSecItemNotFound {
            var insert = query
            insert[kSecValueData as String] = data
            insert[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
            return SecItemAdd(insert as CFDictionary, nil) == errSecSuccess
        }
        return false
    }

    private static func delete(account: String) {
        SecItemDelete(baseQuery(account: account) as CFDictionary)
    }
}
