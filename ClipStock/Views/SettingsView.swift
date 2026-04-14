import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {

    @AppStorage(PreferenceKey.pasteOnSelect) private var pasteOnSelect: Bool = false
    @AppStorage(PreferenceKey.launchAtLogin) private var launchAtLogin: Bool = false
    @AppStorage(PreferenceKey.maxHistoryCount) private var maxHistoryCount: Int = 500

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {

                // Shortcuts
                section(title: NSLocalizedString("Global Shortcuts", comment: ""),
                        hint: NSLocalizedString("Click a field, then press the key combination you want.", comment: "")) {
                    Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 10) {
                        GridRow {
                            Text(NSLocalizedString("Open Clipboard", comment: ""))
                            KeyboardShortcuts.Recorder(for: .openClipboard)
                        }
                        GridRow {
                            Text(NSLocalizedString("Open Stock", comment: ""))
                            KeyboardShortcuts.Recorder(for: .openStock)
                        }
                    }
                }

                Divider()

                // Behavior
                section(title: NSLocalizedString("Behavior", comment: "")) {
                    Toggle(NSLocalizedString("Launch at login", comment: ""), isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { newValue in
                            try? LaunchAtLoginHelper.setEnabled(newValue)
                        }
                    Toggle(NSLocalizedString("Paste on select (requires Accessibility permission)", comment: ""), isOn: $pasteOnSelect)
                        .onChange(of: pasteOnSelect) { newValue in
                            if newValue {
                                _ = PasteHelper.hasAccessibilityPermission(prompt: true)
                            }
                        }
                    HStack {
                        Text(NSLocalizedString("Keep last", comment: ""))
                        Stepper(value: $maxHistoryCount, in: 50...5000, step: 50) {
                            Text("\(maxHistoryCount)")
                                .monospacedDigit()
                                .frame(minWidth: 60, alignment: .leading)
                        }
                        Text(NSLocalizedString("clippings", comment: ""))
                            .foregroundColor(.secondary)
                    }
                }

                Divider()

                // Quick paste explainer
                section(title: NSLocalizedString("Quick Paste", comment: "")) {
                    bullet(NSLocalizedString("Press ⌘1–⌘9 while the clipboard list is open to copy the Nth item.", comment: ""))
                    bullet(NSLocalizedString("Press ⌥⌘V on the selected item to copy it as plain text.", comment: ""))
                    bullet(NSLocalizedString("Press ⌘P on the selected item to pin it to the top.", comment: ""))
                }
            }
            .padding(24)
        }
        .frame(width: 520, height: 500)
    }

    @ViewBuilder
    private func section<Content: View>(title: String, hint: String? = nil, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            if let hint {
                Text(hint).font(.caption).foregroundColor(.secondary)
            }
            content()
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("•").foregroundColor(.secondary)
            Text(text).font(.callout).foregroundColor(.secondary)
        }
    }
}
