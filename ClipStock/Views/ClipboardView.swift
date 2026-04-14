import SwiftUI

struct ClipboardView: View {

    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \ClipboardItem.isPinned, ascending: false),
            NSSortDescriptor(keyPath: \ClipboardItem.clipDate, ascending: false)
        ],
        animation: .default)
    private var clips: FetchedResults<ClipboardItem>

    @State private var searchText = ""
    @State private var selectedIDs: Set<String> = []
    @State private var cursorID: String?
    @State private var anchorID: String?
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {

            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField(NSLocalizedString("Search clippings...", comment: ""), text: $searchText)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor)))
            .padding(.horizontal)
            .padding(.top, 10)

            if filteredClips.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "clipboard")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text(NSLocalizedString("No clippings yet", comment: ""))
                        .font(.headline)
                    Text(NSLocalizedString("Copy something to get started.", comment: ""))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                // Clips list
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(Array(filteredClips.enumerated()), id: \.element.clipID) { index, clip in
                                ClipboardItemCard(clip: clip)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.accentColor, lineWidth: 2)
                                            .opacity(selectedIDs.contains(clip.clipID ?? "") ? 1 : 0)
                                    )
                                    .overlay(alignment: .topTrailing) {
                                        if index < 9 {
                                            Text("⌘\(index + 1)")
                                                .font(.caption2.monospacedDigit())
                                                .foregroundColor(.secondary)
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 2)
                                                .background(RoundedRectangle(cornerRadius: 4).fill(Color(NSColor.controlBackgroundColor).opacity(0.85)))
                                                .padding(6)
                                        }
                                    }
                                    .id(clip.clipID)
                                    .onTapGesture {
                                        handleClipClick(clip, in: filteredClips)
                                    }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.top, 8)
                    .onChange(of: cursorID) { id in
                        if let id { withAnimation { proxy.scrollTo(id, anchor: .center) } }
                    }
                }
            }

            Divider().padding(.top, 6)

            // Footer
            HStack {
                Text("\(clips.count) " + NSLocalizedString("clippings", comment: ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button(NSLocalizedString("Clear All", comment: "")) {
                    StorageHelper.shared.clearAllClips()
                }
                .font(.caption)
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
        .onAppear {
            DispatchQueue.main.async { isSearchFocused = false }
        }
        .onReceive(AppState.shared.keyAction) { action in
            handleKeyAction(action)
        }
    }

    private var filteredClips: [ClipboardItem] {
        guard !searchText.isEmpty else { return Array(clips) }
        return clips.filter { clip in
            (clip.clipText ?? "").localizedCaseInsensitiveContains(searchText) ||
            (clip.clipSourceApp ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    private func handleKeyAction(_ action: KeyAction) {
        let clips = filteredClips
        switch action {
        case .navigateUp:
            moveCursor(-1, in: clips, extend: false)
        case .navigateDown:
            moveCursor(1, in: clips, extend: false)
        case .navigateUpExtend:
            moveCursor(-1, in: clips, extend: true)
        case .navigateDownExtend:
            moveCursor(1, in: clips, extend: true)
        case .copySelected:
            if let id = cursorID, let clip = clips.first(where: { $0.clipID == id }) {
                ClipboardMonitor.shared.ignoreSelfCopy()
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                if clip.clipType == "image", let data = clip.clipImageData, let img = NSImage(data: data) {
                    pasteboard.writeObjects([img])
                } else if let text = clip.clipText {
                    pasteboard.setString(text, forType: .string)
                }
                ToastState.shared.show(NSLocalizedString("Copied!", comment: ""))
            }
        case .deleteSelected:
            let toDelete = clips.filter { selectedIDs.contains($0.clipID ?? "") }
            guard !toDelete.isEmpty else { return }
            for clip in toDelete { StorageHelper.shared.storageContext.delete(clip) }
            try? StorageHelper.shared.storageContext.save()
            selectedIDs.removeAll()
            let remaining = filteredClips
            if !remaining.isEmpty {
                let id = remaining[0].clipID
                cursorID = id
                anchorID = id
                if let id { selectedIDs.insert(id) }
            } else {
                cursorID = nil
                anchorID = nil
            }
        case .focusSearch:
            isSearchFocused = true
        case .saveToStock:
            let toPromote = clips.filter { selectedIDs.contains($0.clipID ?? "") }
            for clip in toPromote { StorageHelper.shared.promoteClipToStock(clip) }
            if !toPromote.isEmpty {
                ToastState.shared.show(NSLocalizedString("Save to Stock", comment: ""))
            }
        case .copyIndex(let n):
            guard n >= 0 && n < clips.count else { return }
            let clip = clips[n]
            ClipboardMonitor.shared.ignoreSelfCopy()
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            if clip.clipType == "image", let data = clip.clipImageData, let img = NSImage(data: data) {
                pasteboard.writeObjects([img])
            } else if let text = clip.clipText {
                pasteboard.setString(text, forType: .string)
            }
            ToastState.shared.show(NSLocalizedString("Copied!", comment: ""))
        case .copyPlainText:
            if let id = cursorID, let clip = clips.first(where: { $0.clipID == id }),
               let text = clip.clipText {
                ClipboardMonitor.shared.ignoreSelfCopy()
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(text, forType: .string)
                ToastState.shared.show(NSLocalizedString("Copied as plain text", comment: ""))
            }
        case .togglePin:
            if let id = cursorID, let clip = clips.first(where: { $0.clipID == id }) {
                StorageHelper.shared.togglePin(clip)
                ToastState.shared.show(clip.isPinned
                    ? NSLocalizedString("Pinned", comment: "")
                    : NSLocalizedString("Unpinned", comment: ""))
            }
        case .addItem, .editItem, .addDeadline, .removeDeadline:
            break
        }
    }

    private func moveCursor(_ direction: Int, in clips: [ClipboardItem], extend: Bool) {
        guard !clips.isEmpty else { return }
        let newIndex: Int
        if let current = cursorID, let idx = clips.firstIndex(where: { $0.clipID == current }) {
            newIndex = max(0, min(clips.count - 1, idx + direction))
        } else {
            newIndex = direction > 0 ? 0 : clips.count - 1
        }
        let newID = clips[newIndex].clipID
        if extend {
            if let id = newID { selectedIDs.insert(id) }
        } else {
            selectedIDs.removeAll()
            if let id = newID { selectedIDs.insert(id) }
            anchorID = newID
        }
        cursorID = newID
    }

    private func handleClipClick(_ clip: ClipboardItem, in clips: [ClipboardItem]) {
        let id = clip.clipID ?? ""
        selectedIDs = [id]
        cursorID = clip.clipID
        anchorID = clip.clipID
    }
}
