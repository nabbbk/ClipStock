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
            } else {
                clipTextEnc = nil
                clipTextHash = nil
            }
            clipText = nil
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
            } else {
                clipImageDataEnc = nil
            }
            clipImageData = nil
        }
    }
}
