import Sparkle
import SwiftUI

final class UpdaterManager: ObservableObject {

    static let shared = UpdaterManager()

    private let controller: SPUStandardUpdaterController

    @Published var canCheckForUpdates = false

    private init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        // Observe Sparkle's canCheckForUpdates KVO property
        controller.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
