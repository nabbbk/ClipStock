import SwiftUI

struct ItemViewCard: View {

    @ObservedObject var itemObject: StockItem

    var body: some View {
        if itemObject.isDeleted || itemObject.managedObjectContext == nil {
            EmptyView()
        } else {
        HStack(spacing: 8) {

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
        }
    }

    // MARK: - Actions

    private func actionOpen() {
        // Copy content to clipboard
        NSPasteboard.general.clearContents()
        if let url = itemObject.itemURL {
            NSPasteboard.general.setString(url.absoluteString, forType: .string)
        } else {
            NSPasteboard.general.setString(itemObject.itemName ?? "", forType: .string)
        }

        // Close popover after copy
        if let delegate = NSApp.delegate as? AppDelegate {
            delegate.togglePopover(nil)
        }
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



    private func actionPresentEditDialog() {
        presentEditItemDialog(for: itemObject)
    }

    private func actionEditDueDate() {
        presentDeadlineDialog(for: itemObject)
    }

    private func actionDelete() {
        StorageHelper.shared.storageContext.delete(itemObject)
        try? StorageHelper.shared.storageContext.save()
    }
}
