import Cocoa

// MARK: - Tag Formatting

enum TagFormatter {
    static func forStorage(_ raw: String) -> String? {
        guard !raw.isEmpty else { return nil }
        return raw.split(separator: ",")
            .map { t in
                let trimmed = t.trimmingCharacters(in: .whitespaces)
                return trimmed.hasPrefix("#") ? trimmed : "#\(trimmed)"
            }
            .joined(separator: ",")
    }

    static func forDisplay(_ stored: String?) -> String {
        (stored ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "#", with: "") }
            .joined(separator: ", ")
    }
}

// MARK: - Popover Window Helper

func popoverWindow() -> NSWindow? {
    NSApplication.shared.windows.first { $0.isVisible && $0.className.contains("Popover") }
    ?? NSApplication.shared.keyWindow
}

// MARK: - Edit Item Dialog

func presentEditItemDialog(for item: StockItem) {
    let dialog = NSAlert()
    dialog.messageText = NSLocalizedString("Edit item details", comment: "")

    let stack = NSStackView(frame: NSRect(x: 0, y: 0, width: 260, height: 140))
    stack.orientation = .vertical
    stack.spacing = 8

    let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 260, height: 100))
    let titleField = DialogTextView(frame: scrollView.contentView.bounds)
    titleField.string = item.itemName ?? ""
    titleField.isEditable = true
    titleField.isRichText = false
    titleField.font = .systemFont(ofSize: 13)
    titleField.autoresizingMask = [.width, .height]
    titleField.isVerticallyResizable = true
    titleField.textContainer?.widthTracksTextView = true
    scrollView.documentView = titleField
    scrollView.hasVerticalScroller = true
    scrollView.borderType = .bezelBorder

    let tagField = DialogTagField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
    tagField.stringValue = TagFormatter.forDisplay(item.itemTag)
    tagField.placeholderString = "Tag"
    tagField.font = .systemFont(ofSize: 13)

    stack.addArrangedSubview(scrollView)
    stack.addArrangedSubview(tagField)
    dialog.accessoryView = stack

    if let iconData = item.itemIconData {
        dialog.icon = NSImage(data: iconData)
    }

    let okButton = dialog.addButton(withTitle: "OK")
    okButton.keyEquivalent = ""
    let cancelButton = dialog.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
    cancelButton.keyEquivalent = "\u{1b}"

    titleField.alert = dialog
    titleField.tabTarget = tagField
    tagField.alert = dialog

    let buttons = dialog.buttons
    tagField.nextKeyView = buttons.first
    if buttons.count > 1 {
        for i in 0..<buttons.count - 1 {
            buttons[i].nextKeyView = buttons[i + 1]
        }
    }
    buttons.last?.nextKeyView = titleField

    guard let window = popoverWindow() else { return }
    DispatchQueue.main.async { window.attachedSheet?.makeFirstResponder(titleField) }
    dialog.beginSheetModal(for: window) { response in
        window.makeKey()
        guard response == .alertFirstButtonReturn, !titleField.string.isEmpty else { return }
        item.itemName = titleField.string
        item.itemTag = TagFormatter.forStorage(tagField.stringValue)
        try? StorageHelper.shared.storageContext.save()
    }
}

// MARK: - Deadline Dialog

func presentDeadlineDialog(for item: StockItem) {
    let dialog = NSAlert()
    dialog.messageText = NSLocalizedString("Add a due date for this item.", comment: "")
    let picker = DialogDatePicker(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
    picker.dateValue = item.dueDate ?? Date()
    picker.datePickerStyle = .textFieldAndStepper
    dialog.accessoryView = picker
    let setButton = dialog.addButton(withTitle: NSLocalizedString("Set deadline", comment: ""))
    setButton.keyEquivalent = "\r"
    if item.dueDate != nil {
        dialog.addButton(withTitle: NSLocalizedString("Remove", comment: ""))
    }
    let cancelButton = dialog.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
    cancelButton.keyEquivalent = "\u{1b}"
    guard let window = popoverWindow() else { return }
    DispatchQueue.main.async { window.attachedSheet?.makeFirstResponder(picker) }
    dialog.beginSheetModal(for: window) { response in
        window.makeKey()
        if response == .alertFirstButtonReturn {
            item.dueDate = picker.dateValue
            try? StorageHelper.shared.storageContext.save()
        } else if response == .alertSecondButtonReturn && item.dueDate != nil {
            item.dueDate = nil
            try? StorageHelper.shared.storageContext.save()
        }
    }
}
