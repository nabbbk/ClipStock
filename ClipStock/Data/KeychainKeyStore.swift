import Foundation
import CryptoKit
import Security

enum KeychainKeyStoreError: Error {
    case unexpectedStatus(OSStatus)
    case dataConversion
}

/// Keychain-backed 256-bit symmetric key for ClipStock's at-rest encryption.
/// Auto-generated on first access. Never leaves the Keychain.
enum KeychainKeyStore {

    private static let service = "com.nabbbk.ClipStock"
    private static let account = "clip-master-key"

    static func loadOrCreateKey() throws -> SymmetricKey {
        if let existing = try loadKey() {
            return existing
        }
        let fresh = SymmetricKey(size: .bits256)
        try store(fresh)
        return fresh
    }

    private static func loadKey() throws -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data else { throw KeychainKeyStoreError.dataConversion }
            return SymmetricKey(data: data)
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainKeyStoreError.unexpectedStatus(status)
        }
    }

    private static func store(_ key: SymmetricKey) throws {
        let data = key.withUnsafeBytes { Data($0) }
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            // Unlocked-only: a locked screen blocks background clipboard saves. That's intentional.
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
            kSecAttrSynchronizable as String: false,
            kSecValueData as String: data
        ]
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainKeyStoreError.unexpectedStatus(status)
        }
    }
}
