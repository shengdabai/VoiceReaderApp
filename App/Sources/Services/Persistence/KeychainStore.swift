import Foundation
import Security

/// Minimal Keychain wrapper for storing sensitive strings (e.g. the remote
/// TTS API key) outside of UserDefaults, where they would otherwise be written
/// in plaintext to a sandbox plist readable on a jailbroken device.
///
/// Uses `kSecClassGenericPassword`. Values are device-only and not synced to
/// iCloud Keychain (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`).
struct KeychainStore {
    private let service: String

    init(service: String = "com.shengdabai.VoiceReaderApp") {
        self.service = service
    }

    /// Stores `value` under `key`, or deletes the entry when `value` is nil/empty.
    @discardableResult
    func set(_ value: String?, for key: String) -> Bool {
        guard let value, !value.isEmpty else {
            return delete(key)
        }
        guard let data = value.data(using: .utf8) else { return false }

        var query = baseQuery(for: key)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return true
        }
        if updateStatus == errSecItemNotFound {
            query.merge(attributes) { _, new in new }
            return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
        }
        return false
    }

    /// Reads the string stored under `key`, or nil when absent.
    func string(for key: String) -> String? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }

    @discardableResult
    func delete(_ key: String) -> Bool {
        let status = SecItemDelete(baseQuery(for: key) as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    private func baseQuery(for key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
    }
}
