import SwiftUI

/// Returns the popover's window to present sheets on.
private func popoverWindow() -> NSWindow? {
    NSApplication.shared.windows.first { $0.isVisible && $0.className.contains("Popover") }
    ?? NSApplication.shared.keyWindow
}

struct ItemViewCard: View {

    @ObservedObject var itemObject: StockItem

    var body: some View {
        HStack(spacing: 8) {

            // Unread badge
            if itemObject.itemUnread {
                Circle()
                    .fill(.blue)
                    .frame(width: 8, height: 8)
            }

            // Icon
            if let data = itemObject.itemIconData, let img = NSImage(data: data) {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                    .cornerRadius(6)
                    .shadow(radius: 2)
            } else {
                Image(systemName: "doc.text")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundColor(.secondary)
            }

            // Title, URL, tag, due date
            VStack(alignment: .leading, spacing: 2) {
                Text(itemObject.itemName?.prefix(200).description ?? "Unknown item")
                    .font(.headline)
                    .lineLimit(2)

                if let url = itemObject.itemURL {
                    Text(url.absoluteString.prefix(100).description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                if let tag = itemObject.itemTag {
                    TagView(tagContent: tag)
                }

                if let due = itemObject.dueDate {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundColor(due < Date() ? .red : .blue)
                        Text(due, style: .date)
                            .font(.caption2)
                    }
                }
            }

            Spacer()

            // Action menu
            Menu {
                // iCloud link (for files in iCloud Drive)
                if let url = itemObject.itemURL, url.isFileURL,
                   FileManager.default.isUbiquitousItem(at: url) {
                    Button(NSLocalizedString("Copy iCloud link", comment: "")) {
                        actionGetiCloudLink()
                    }
                }

                // Share URL (for web links)
                if let url = itemObject.itemURL, !url.isFileURL {
                    Button(NSLocalizedString("Share URL", comment: "")) {
                        actionOpenShareMenu()
                    }
                }

                Button(itemObject.itemUnread
                       ? NSLocalizedString("Mark as read", comment: "")
                       : NSLocalizedString("Mark as unread", comment: "")) {
                    actionMarkAsRead()
                }

                Button(NSLocalizedString("Edit", comment: "")) {
                    actionPresentEditDialog()
                }

                Button(NSLocalizedString("Add deadline", comment: "")) {
                    actionEditDueDate()
                }

                if itemObject.dueDate != nil {
                    Button(NSLocalizedString("Remove deadline", comment: "")) {
                        itemObject.dueDate = nil
                        try? StorageHelper.shared.storageContext.save()
                    }
                }

                Button(NSLocalizedString("Delete", comment: ""), role: .destructive) {
                    actionDelete()
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .fixedSize()
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor)))
        .contentShape(Rectangle())
        .onTapGesture { actionOpen() }
        .onDrag {
            if let url = itemObject.itemURL {
                return url.isFileURL
                    ? NSItemProvider(object: url.path as NSString)
                    : NSItemProvider(object: url as NSURL)
            }
            return NSItemProvider(object: (itemObject.itemName ?? "") as NSString)
        }
    }

    // MARK: - Actions

    private func actionOpen() {
        itemObject.itemUnread = false
        try? StorageHelper.shared.storageContext.save()

        // Copy content to clipboard
        ClipboardMonitor.shared.ignoreSelfCopy()
        NSPasteboard.general.clearContents()
        if let url = itemObject.itemURL {
            NSPasteboard.general.setString(url.absoluteString, forType: .string)
        } else {
            NSPasteboard.general.setString(itemObject.itemName ?? "", forType: .string)
        }

        // Show "Copied!" toast
        ToastState.shared.show(NSLocalizedString("Copied!", comment: ""))
    }

    private func actionGetiCloudLink() {
        guard let url = itemObject.itemURL,
              let shareURL = try? FileManager.default.url(
                forPublishingUbiquitousItemAt: url, expiration: nil) else { return }
        ClipboardMonitor.shared.ignoreSelfCopy()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(shareURL.absoluteString, forType: .string)
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Share with iCloud", comment: "")
        alert.informativeText = NSLocalizedString(
            "The iCloud sharing link has been copied to your pasteboard.", comment: "")
        alert.addButton(withTitle: "OK")
        for button in alert.buttons { button.focusRingType = .none }
        if let window = popoverWindow() {
            alert.beginSheetModal(for: window) { _ in window.makeKey() }
        }
    }

    private func actionOpenShareMenu() {
        guard let url = itemObject.itemURL else { return }
        let picker = NSSharingServicePicker(items: [url])
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate,
           let view = appDelegate.popoverContentView {
            picker.show(relativeTo: .zero, of: view, preferredEdge: .minX)
        }
    }

    private func actionMarkAsRead() {
        itemObject.itemUnread.toggle()
        try? StorageHelper.shared.storageContext.save()
    }

    private func actionPresentEditDialog() {
        let dialog = NSAlert()
        dialog.messageText = NSLocalizedString("Edit item details", comment: "")

        let stack = NSStackView(frame: NSRect(x: 0, y: 0, width: 260, height: 140))
        stack.orientation = .vertical
        stack.spacing = 8

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 260, height: 100))
        let titleField = DialogTextView(frame: scrollView.contentView.bounds)
        titleField.string = itemObject.itemName ?? ""
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
        tagField.stringValue = (itemObject.itemTag ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "#", with: "") }
            .joined(separator: ", ")
        tagField.placeholderString = "Tag"
        tagField.font = .systemFont(ofSize: 13)

        stack.addArrangedSubview(scrollView)
        stack.addArrangedSubview(tagField)
        dialog.accessoryView = stack

        if let iconData = itemObject.itemIconData {
            dialog.icon = NSImage(data: iconData)
        }

        let okButton = dialog.addButton(withTitle: "OK")
        okButton.keyEquivalent = ""
        let cancelButton = dialog.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
        cancelButton.keyEquivalent = "\u{1b}"
        for button in dialog.buttons { button.focusRingType = .exterior }

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

            guard response == .alertFirstButtonReturn,
                  !titleField.string.isEmpty else { return }

            self.itemObject.itemName = titleField.string

            if tagField.stringValue.isEmpty {
                self.itemObject.itemTag = nil
            } else {
                let formatted = tagField.stringValue
                    .split(separator: ",")
                    .map { t in
                        let trimmed = t.trimmingCharacters(in: .whitespaces)
                        return trimmed.hasPrefix("#") ? trimmed : "#\(trimmed)"
                    }
                    .joined(separator: ",")
                self.itemObject.itemTag = formatted
            }
            try? StorageHelper.shared.storageContext.save()
        }
    }

    private func actionEditDueDate() {
        let dialog = NSAlert()
        dialog.messageText = NSLocalizedString("Add a due date for this item.", comment: "")
        let picker = DialogDatePicker(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        picker.dateValue = itemObject.dueDate ?? Date()
        picker.datePickerStyle = .textFieldAndStepper
        dialog.accessoryView = picker
        let setButton = dialog.addButton(withTitle: NSLocalizedString("Set deadline", comment: ""))
        setButton.keyEquivalent = "\r"
        if itemObject.dueDate != nil {
            dialog.addButton(withTitle: NSLocalizedString("Remove", comment: ""))
        }
        let cancelButton2 = dialog.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
        cancelButton2.keyEquivalent = "\u{1b}"
        for button in dialog.buttons { button.focusRingType = .exterior }
        guard let window = popoverWindow() else { return }
        DispatchQueue.main.async { window.attachedSheet?.makeFirstResponder(picker) }
        dialog.beginSheetModal(for: window) { response in
            window.makeKey()
            if response == .alertFirstButtonReturn {
                self.itemObject.dueDate = picker.dateValue
                try? StorageHelper.shared.storageContext.save()
            } else if response == .alertSecondButtonReturn && self.itemObject.dueDate != nil {
                self.itemObject.dueDate = nil
                try? StorageHelper.shared.storageContext.save()
            }
        }
    }

    private func actionDelete() {
        StorageHelper.shared.storageContext.delete(itemObject)
        try? StorageHelper.shared.storageContext.save()
    }
}
