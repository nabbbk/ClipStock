import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    var body: some View {
        Form {
            Section(header: Text(NSLocalizedString("Global Shortcuts", comment: ""))) {
                KeyboardShortcuts.Recorder(
                    NSLocalizedString("Open Clipboard:", comment: ""),
                    name: .openClipboard)
                KeyboardShortcuts.Recorder(
                    NSLocalizedString("Open Stock:", comment: ""),
                    name: .openStock)
            }
            Section(header: Text(NSLocalizedString("Quick Paste", comment: ""))) {
                Text(NSLocalizedString("Press ⌘1–⌘9 while the clipboard list is open to copy the Nth item.", comment: ""))
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440, height: 260)
    }
}
