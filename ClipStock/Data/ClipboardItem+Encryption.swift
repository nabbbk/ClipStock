import Foundation
import CoreData

extension ClipboardItem {

    /// Decrypted clipboard text. Reads the encrypted column; falls back to the
    /// legacy plaintext column for rows that haven't migrated yet. Setting this
    /// populates the encrypted + hash columns and nulls the legacy column.
    var plainText: String? {
        get {
            if let enc = clipTextEnc, let decrypted = ClipCrypto.decryptString(enc) {
                return decrypted
            }
            return clipText
        }
        set {
            if let newValue {
                clipTextEnc = ClipCrypto.encryptString(newValue)
                clipTextHash = ClipCrypto.hashString(newValue)
                // Trade-off: if encryption failed, keep the value in the legacy
                // plaintext column (data preserved in plaintext rather than lost);
                // migrateLegacyPlaintextIfNeeded re-encrypts it on a later launch.
                clipText = clipTextEnc == nil ? newValue : nil
            } else {
                clipTextEnc = nil
                clipTextHash = nil
                clipText = nil
            }
        }
    }

    /// Decrypted image bytes. Same legacy-fallback pattern as plainText.
    var plainImage: Data? {
        get {
            if let enc = clipImageDataEnc, let decrypted = ClipCrypto.decrypt(enc) {
                return decrypted
            }
            return clipImageData
        }
        set {
            if let newValue {
                clipImageDataEnc = ClipCrypto.encrypt(newValue)
                // Trade-off: if encryption failed, keep the bytes in the legacy
                // plaintext column (data preserved in plaintext rather than lost);
                // migrateLegacyPlaintextIfNeeded re-encrypts them on a later launch.
                clipImageData = clipImageDataEnc == nil ? newValue : nil
            } else {
                clipImageDataEnc = nil
                clipImageData = nil
            }
        }
    }
}
