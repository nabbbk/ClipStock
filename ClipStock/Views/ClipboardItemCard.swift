import SwiftUI

struct ClipboardItemCard: View {

    @ObservedObject var clip: ClipboardItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Top row: icon + text + menu
            HStack(alignment: .top, spacing: 10) {

                // Type icon or image preview
                Group {
                    if clip.clipType == "image",
                       let data = clip.plainImage,
                       let img = NSImage(data: data) {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 40, height: 40)
                            .cornerRadius(6)
                            .clipped()
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(iconColor)
                                .frame(width: 40, height: 40)
                            Image(systemName: iconName)
                                .foregroundColor(.white)
                        }
                    }
                }
                .frame(width: 40, height: 40)

                // Content text
                VStack(alignment: .leading, spacing: 2) {
                    Text(previewText)
                        .font(.system(size: 12))
                        .lineLimit(3)

                    HStack(spacing: 4) {
                        if let app = clip.clipSourceApp {
                            Text(app)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        if let date = clip.clipDate {
                            Text(date, style: .relative)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer(minLength: 4)

                if clip.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                        .padding(.trailing, 2)
                }

                // Action menu — use contextMenu-style button instead of Menu with borderlessButton
                Menu {
                    Button(NSLocalizedString("Copy", comment: "")) { actionCopy() }
                    Button(clip.isPinned
                           ? NSLocalizedString("Unpin", comment: "")
                           : NSLocalizedString("Pin", comment: "")) { actionTogglePin() }
                    Button(NSLocalizedString("Save to Stock", comment: "")) { actionPromoteToStock() }
                    Divider()
                    Button(NSLocalizedString("Delete", comment: ""), role: .destructive) { actionDelete() }
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
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor)))
        .contentShape(Rectangle())
        .onTapGesture { actionOpen() }
        .onDrag {
            if clip.clipType == "image", let data = clip.plainImage, let img = NSImage(data: data) {
                return NSItemProvider(object: img)
            }
            return NSItemProvider(object: (clip.plainText ?? "") as NSString)
        }
    }

    // MARK: - Computed

    private var previewText: String {
        switch clip.clipType {
        case "image": return clip.plainText ?? "Image"
        case "link": return clip.plainText ?? "Link"
        default: return clip.plainText ?? "Text"
        }
    }

    private var iconName: String {
        switch clip.clipType {
        case "image": return "photo"
        case "link": return "link"
        default: return "doc.text"
        }
    }

    private var iconColor: Color {
        switch clip.clipType {
        case "image": return .purple
        case "link": return .blue
        default: return .gray
        }
    }

    // MARK: - Actions

    private func actionOpen() {
        actionCopy()
        ToastState.shared.show(NSLocalizedString("Copied!", comment: ""))
    }

    private func actionCopy() {
        ClipboardMonitor.shared.ignoreSelfCopy()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if clip.clipType == "image", let data = clip.plainImage, let img = NSImage(data: data) {
            pasteboard.writeObjects([img])
        } else if let text = clip.plainText {
            pasteboard.setString(text, forType: .string)
        }
    }

    private func actionPromoteToStock() {
        StorageHelper.shared.promoteClipToStock(clip)
    }

    private func actionTogglePin() {
        StorageHelper.shared.togglePin(clip)
    }

    private func actionDelete() {
        StorageHelper.shared.storageContext.delete(clip)
        try? StorageHelper.shared.storageContext.save()
    }
}
