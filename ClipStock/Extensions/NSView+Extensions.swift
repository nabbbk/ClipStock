import Cocoa

extension NSView {
    static func disableFocusRings() {
        let original = class_getInstanceMethod(NSView.self, #selector(getter: focusRingType))!
        let replacement = class_getInstanceMethod(NSView.self, #selector(getter: noFocusRingType))!
        method_exchangeImplementations(original, replacement)
    }

    @objc private var noFocusRingType: NSFocusRingType {
        .none
    }
}
