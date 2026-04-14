import Foundation
import ServiceManagement

enum LaunchAtLoginHelper {

    static var isEnabled: Bool {
        if #available(macOS 13, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    static func setEnabled(_ enabled: Bool) throws {
        guard #available(macOS 13, *) else { return }
        if enabled {
            if SMAppService.mainApp.status != .enabled {
                try SMAppService.mainApp.register()
            }
        } else {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
        }
    }

    /// Mirror the stored preference into the actual login-item state on launch.
    static func applyStoredPreference() {
        let stored = UserDefaults.standard.bool(forKey: PreferenceKey.launchAtLogin)
        if stored != isEnabled {
            try? setEnabled(stored)
        }
    }
}
