import SwiftUI

@main
struct ClipStockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No visible window — the entire UI lives in the menu bar popover.
        Settings { EmptyView() }
    }
}
