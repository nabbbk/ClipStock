import Foundation
import CryptoKit
import os.log

enum ClipCryptoError: Error {
    case keyUnavailable
    case encryptionFailed
    case decryptionFailed
}

/// AES-GCM encryption + HMAC-SHA256 hashing for ClipboardItem content.
/// Uses a single 256-bit key from KeychainKeyStore — HMAC subkey is derived via HKDF
/// so the same master key never directly signs and encrypts with the same material.
enum ClipCrypto {

    private static let log = Logger(subsystem: "com.nabbbk.ClipStock", category: "crypto")

    private static let hmacSubkeyInfo = Data("clipstock.hmac.v1".utf8)

    private static var masterKey: SymmetricKey? = {
        do {
            return try KeychainKeyStore.loadOrCreateKey()
        } catch {
            log.error("Keychain key unavailable: \(String(describing: error), privacy: .public)")
            return nil
        }
    }()

    private static var hmacKey: SymmetricKey? {
        guard let masterKey else { return nil }
        return HKDF<SHA256>.deriveKey(inputKeyMaterial: masterKey, info: hmacSubkeyInfo, outputByteCount: 32)
    }

    static var isAvailable: Bool { masterKey != nil }

    static func encrypt(_ plaintext: Data) -> Data? {
        guard let masterKey else { return nil }
        do {
            let sealed = try AES.GCM.seal(plaintext, using: masterKey)
            return sealed.combined
        } catch {
            log.error("encrypt failed: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    static func decrypt(_ ciphertext: Data) -> Data? {
        guard let masterKey else { return nil }
        do {
            let box = try AES.GCM.SealedBox(combined: ciphertext)
            return try AES.GCM.open(box, using: masterKey)
        } catch {
            log.error("decrypt failed: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    static func hash(_ data: Data) -> Data? {
        guard let hmacKey else { return nil }
        let code = HMAC<SHA256>.authenticationCode(for: data, using: hmacKey)
        return Data(code)
    }

    static func encryptString(_ s: String) -> Data? { encrypt(Data(s.utf8)) }

    static func decryptString(_ d: Data) -> String? {
        guard let plain = decrypt(d) else { return nil }
        return String(data: plain, encoding: .utf8)
    }

    static func hashString(_ s: String) -> Data? { hash(Data(s.utf8)) }
}
