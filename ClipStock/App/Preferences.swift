import Foundation

enum PreferenceKey {
    static let pasteOnSelect = "pref.pasteOnSelect"
    static let launchAtLogin = "pref.launchAtLogin"
    static let maxHistoryCount = "pref.maxHistoryCount"
}

enum Preferences {
    static var pasteOnSelect: Bool {
        UserDefaults.standard.bool(forKey: PreferenceKey.pasteOnSelect)
    }

    static var maxHistoryCount: Int {
        let value = UserDefaults.standard.integer(forKey: PreferenceKey.maxHistoryCount)
        return value > 0 ? value : 500
    }
}
