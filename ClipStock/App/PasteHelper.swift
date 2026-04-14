import Cocoa
import Carbon.HIToolbox

enum PasteHelper {

    /// Simulates ⌘V in the currently frontmost app.
    /// Requires Accessibility permission granted to ClipStock in
    /// System Settings → Privacy & Security → Accessibility.
    static func simulatePaste() {
        guard hasAccessibilityPermission(prompt: false) else {
            requestAccessibilityAlert()
            return
        }
        let source = CGEventSource(stateID: .combinedSessionState)
        let vDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        vDown?.flags = .maskCommand
        let vUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        vUp?.flags = .maskCommand
        vDown?.post(tap: .cgAnnotatedSessionEventTap)
        vUp?.post(tap: .cgAnnotatedSessionEventTap)
    }

    static func hasAccessibilityPermission(prompt: Bool) -> Bool {
        let options: [String: Any] = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    private static var didPromptForAccessibility = false

    private static func requestAccessibilityAlert() {
        guard !didPromptForAccessibility else { return }
        didPromptForAccessibility = true
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("Accessibility permission required", comment: "")
            alert.informativeText = NSLocalizedString(
                "Paste on select needs permission to send keystrokes. Enable ClipStock in System Settings → Privacy & Security → Accessibility.",
                comment: "")
            alert.addButton(withTitle: NSLocalizedString("Open System Settings", comment: ""))
            alert.addButton(withTitle: NSLocalizedString("Later", comment: ""))
            if alert.runModal() == .alertFirstButtonReturn {
                _ = hasAccessibilityPermission(prompt: true)
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
}
