import SwiftUI
import ServiceManagement

enum AppTab: String, CaseIterable {
    case stock = "Stock"
    case clipboard = "Clipboard"
}

struct ContentView: View {

    @ObservedObject private var appState = AppState.shared
    @AppStorage(PreferenceKey.launchAtLogin) private var launchAtLogin: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            Picker("", selection: $appState.selectedTab) {
                ForEach(AppTab.allCases, id: \.self) { tab in
                    Text(NSLocalizedString(tab.rawValue, comment: "")).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .focusable(false)
            .padding(.horizontal)
            .padding(.top, 10)

            // Tab content
            switch appState.selectedTab {
            case .stock:
                StockView()
            case .clipboard:
                ClipboardView()
            }

            Divider().padding(.top, 6)

            // Shared footer
            VStack(spacing: 6) {
                Toggle(NSLocalizedString("Launch at login", comment: ""), isOn: $launchAtLogin)
                    .toggleStyle(.checkbox)
                    .onChange(of: launchAtLogin) { newValue in
                        try? LaunchAtLoginHelper.setEnabled(newValue)
                    }

                HStack {
                    Button {
                        NSWorkspace.shared.open(URL(string: "https://github.com/nabbbk/ClipStock")!)
                    } label: {
                        Label(NSLocalizedString("Support", comment: ""), systemImage: "questionmark.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    Spacer()
                    Button(NSLocalizedString("Quit app", comment: "")) {
                        NSApplication.shared.terminate(nil)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .frame(maxHeight: .infinity)
        .withToastOverlay()
    }
}

// MARK: - Dialog Text View (Enter=submit, Shift+Enter=newline, Tab=next field)

class DialogTextView: NSTextView {
    weak var alert: NSAlert?
    weak var tabTarget: NSView?

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 && !event.modifierFlags.contains(.shift) {
            alert?.buttons.first?.performClick(nil)
            return
        }
        if event.keyCode == 48 { // Tab → next field
            window?.makeFirstResponder(tabTarget)
            return
        }
        super.keyDown(with: event)
    }
}

class DialogTagField: NSTextField, NSTextFieldDelegate {
    weak var alert: NSAlert?

    override init(frame: NSRect) {
        super.init(frame: frame)
        self.delegate = self
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.delegate = self
    }


    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(insertNewline(_:)) {
            alert?.buttons.first?.performClick(nil)
            return true
        }
        if commandSelector == #selector(insertTab(_:)) {
            if let next = nextKeyView {
                window?.makeFirstResponder(next)
            }
            return true
        }
        return false
    }
}

class DialogDatePicker: NSDatePicker {
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 48 { // Tab → cycle to buttons
            window?.selectNextKeyView(nil)
            return
        }
        super.keyDown(with: event)
    }
}

// MARK: - Drag-and-Drop Reorder

struct StockDropDelegate: DropDelegate {
    let targetItem: StockItem
    let items: [StockItem]
    @Binding var draggedItemID: String?

    func performDrop(info: DropInfo) -> Bool {
        draggedItemID = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggedID = draggedItemID,
              draggedID != targetItem.itemID,
              let fromIndex = items.firstIndex(where: { $0.itemID == draggedID }),
              let toIndex = items.firstIndex(where: { $0.itemID == targetItem.itemID })
        else { return }

        withAnimation(.default) {
            // Reassign sortIndex for all items based on new order
            var reordered = items
            let moved = reordered.remove(at: fromIndex)
            reordered.insert(moved, at: toIndex)
            for (i, item) in reordered.enumerated() {
                item.sortIndex = Int32(i)
            }
            try? StorageHelper.shared.storageContext.save()
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

// MARK: - Stock Tab (extracted from original ContentView)

struct StockView: View {

    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \StockItem.sortIndex, ascending: true),
            NSSortDescriptor(keyPath: \StockItem.addedDate, ascending: false)
        ],
        animation: .default)
    private var items: FetchedResults<StockItem>

    @State private var searchText = ""
    @State private var selectedTag = NSLocalizedString("All", comment: "")
    @State private var selectedIDs: Set<String> = []

    private var allTags: [String] {
        var tags: Set<String> = [NSLocalizedString("All", comment: "")]
        for item in items {
            if let tagString = item.itemTag {
                for tag in tagString.split(separator: ",") {
                    tags.insert(tag.trimmingCharacters(in: .whitespaces))
                }
            } else {
                tags.insert(NSLocalizedString("Un-Tagged", comment: ""))
            }
        }
        return tags.sorted()
    }
    @State private var cursorID: String?
    @State private var anchorID: String?
    @State private var draggedItemID: String?
    @FocusState private var stockSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField(NSLocalizedString("Search...", comment: ""), text: $searchText)
                    .textFieldStyle(.plain)
                    .focused($stockSearchFocused)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    actionManuallyAddItem()
                } label: {
                    Image(systemName: "plus")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor)))
            .padding(.horizontal)
            .padding(.top, 10)

            if items.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("There are no stocked items.")
                        .font(.headline)
                    Text("Drag a URL link or a file directly to the app icon at the top system bar to save it.")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 30)
                }
                Spacer()
            } else {
                Menu(selectedTag) {
                    ForEach(allTags, id: \.self) { tag in
                        Button(tag) { selectedTag = tag }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(Array(filteredItems.enumerated()), id: \.element.itemID) { index, item in
                                ItemViewCard(itemObject: item)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.accentColor, lineWidth: 2)
                                            .opacity(selectedIDs.contains(item.itemID ?? "") ? 1 : 0)
                                            .allowsHitTesting(false)
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
                                                .allowsHitTesting(false)
                                        }
                                    }
                                    .id(item.itemID)
                                    .onTapGesture {
                                        NSPasteboard.general.clearContents()
                                        if let url = item.itemURL {
                                            NSPasteboard.general.setString(url.absoluteString, forType: .string)
                                        } else {
                                            NSPasteboard.general.setString(item.itemName ?? "", forType: .string)
                                        }
                                        if let appDelegate = NSApp.delegate as? AppDelegate {
                                            appDelegate.closePopover(nil)
                                            // Force-close if performClose didn't work
                                            appDelegate.popoverContentView?.window?.orderOut(nil)
                                        }
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
        }
        .onAppear {
            DispatchQueue.main.async { stockSearchFocused = false }
        }
        .onReceive(AppState.shared.keyAction) { action in
            handleKeyAction(action)
        }
    }

    private func handleKeyAction(_ action: KeyAction) {
        let items = filteredItems
        switch action {
        case .navigateUp:
            moveCursor(-1, in: items, extend: false)
        case .navigateDown:
            moveCursor(1, in: items, extend: false)
        case .navigateUpExtend:
            moveCursor(-1, in: items, extend: true)
        case .navigateDownExtend:
            moveCursor(1, in: items, extend: true)
        case .copySelected:
            if let id = cursorID, let item = items.first(where: { $0.itemID == id }) {
                NSPasteboard.general.clearContents()
                if let url = item.itemURL {
                    NSPasteboard.general.setString(url.absoluteString, forType: .string)
                } else {
                    NSPasteboard.general.setString(item.itemName ?? "", forType: .string)
                }
                ToastState.shared.show(NSLocalizedString("Copied!", comment: ""))
            }
        case .deleteSelected:
            let toDelete = items.filter { selectedIDs.contains($0.itemID ?? "") }
            guard !toDelete.isEmpty else { return }
            for item in toDelete { StorageHelper.shared.storageContext.delete(item) }
            try? StorageHelper.shared.storageContext.save()
            selectedIDs.removeAll()
            let remaining = filteredItems
            if !remaining.isEmpty {
                let id = remaining[0].itemID
                cursorID = id
                anchorID = id
                if let id { selectedIDs.insert(id) }
            } else {
                cursorID = nil
                anchorID = nil
            }
        case .focusSearch:
            stockSearchFocused = true
        case .addItem:
            actionManuallyAddItem()
        case .editItem:
            if let id = cursorID, let item = items.first(where: { $0.itemID == id }) {
                actionEditItem(item)
            }
        case .addDeadline:
            if let id = cursorID, let item = items.first(where: { $0.itemID == id }) {
                actionEditDueDate(item)
            }
        case .removeDeadline:
            let toRemove = items.filter { selectedIDs.contains($0.itemID ?? "") }
            for item in toRemove { item.dueDate = nil }
            try? StorageHelper.shared.storageContext.save()
        case .saveToStock:
            break
        case .copyIndex(let n):
            guard n >= 0 && n < items.count else { return }
            let item = items[n]
            NSPasteboard.general.clearContents()
            if let url = item.itemURL {
                NSPasteboard.general.setString(url.absoluteString, forType: .string)
            } else {
                NSPasteboard.general.setString(item.itemName ?? "", forType: .string)
            }
            ToastState.shared.show(NSLocalizedString("Copied!", comment: ""))
        case .copyPlainText, .togglePin:
            break
        }
    }

    private func moveCursor(_ direction: Int, in items: [StockItem], extend: Bool) {
        guard !items.isEmpty else { return }
        let newIndex: Int
        if let current = cursorID, let idx = items.firstIndex(where: { $0.itemID == current }) {
            newIndex = max(0, min(items.count - 1, idx + direction))
        } else {
            newIndex = direction > 0 ? 0 : items.count - 1
        }
        let newID = items[newIndex].itemID
        if extend {
            if let id = newID { selectedIDs.insert(id) }
        } else {
            selectedIDs.removeAll()
            if let id = newID { selectedIDs.insert(id) }
            anchorID = newID
        }
        cursorID = newID
    }

    private func handleItemClick(_ item: StockItem, in items: [StockItem]) {
        let id = item.itemID ?? ""
        selectedIDs = [id]
        cursorID = item.itemID
        anchorID = item.itemID
    }

    private var filteredItems: [StockItem] {
        items.filter { item in
            if selectedTag != NSLocalizedString("All", comment: "") {
                if item.itemTag == nil && selectedTag == NSLocalizedString("Un-Tagged", comment: "") {
                    // pass through
                } else {
                    let itemTags = (item.itemTag ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                    if !itemTags.contains(selectedTag) {
                        return false
                    }
                }
            }
            guard !searchText.isEmpty else { return true }
            let tagMatch = (item.itemTag ?? "").localizedCaseInsensitiveContains(searchText)
            let contentMatch = (item.itemName ?? "").localizedCaseInsensitiveContains(searchText)
            return tagMatch || contentMatch
        }
    }

    private func actionManuallyAddItem() {
        let dialog = NSAlert()
        dialog.messageText = NSLocalizedString("Stock an item", comment: "")
        dialog.informativeText = NSLocalizedString(
            "Drag the URL link directly to the app icon on the system bar; or, you can also manually type a URL here.",
            comment: "")

        let stack = NSStackView(frame: NSRect(x: 0, y: 0, width: 260, height: 112))
        stack.orientation = .vertical
        stack.spacing = 8

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 260, height: 80))
        let textView = DialogTextView(frame: scrollView.contentView.bounds)
        textView.isEditable = true
        textView.isRichText = false
        textView.font = .systemFont(ofSize: 13)
        textView.autoresizingMask = [.width, .height]
        textView.isVerticallyResizable = true
        textView.textContainer?.widthTracksTextView = true
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        let tagField = DialogTagField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        tagField.placeholderString = "Tag"
        tagField.font = .systemFont(ofSize: 13)

        stack.addArrangedSubview(scrollView)
        stack.addArrangedSubview(tagField)
        dialog.accessoryView = stack

        let addButton = dialog.addButton(withTitle: NSLocalizedString("Add", comment: ""))
        addButton.keyEquivalent = ""
        let cancelButton = dialog.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
        cancelButton.keyEquivalent = "\u{1b}"

        // Wire up keyboard navigation between fields
        textView.alert = dialog
        textView.tabTarget = tagField
        tagField.alert = dialog

        // Key view loop: tag → buttons → content
        let buttons = dialog.buttons
        tagField.nextKeyView = buttons.first
        if buttons.count > 1 {
            for i in 0..<buttons.count - 1 {
                buttons[i].nextKeyView = buttons[i + 1]
            }
        }
        buttons.last?.nextKeyView = textView

        // Enable focus rings on dialog buttons

        guard let window = NSApplication.shared.windows.first(where: { $0.isVisible && $0.className.contains("Popover") }) ?? NSApplication.shared.keyWindow else { return }
        // Auto-focus content field after sheet appears
        DispatchQueue.main.async { window.attachedSheet?.makeFirstResponder(textView) }
        dialog.beginSheetModal(for: window) { response in
            window.makeKey()

            guard response == .alertFirstButtonReturn,
                  !textView.string.isEmpty else { return }

            let tag = TagFormatter.forStorage(tagField.stringValue)

            var inputValue: Any = textView.string
            if let url = URL(string: textView.string), url.scheme != nil {
                inputValue = url as NSURL
            }
            MetaDataHelper.fetchItemMetaData(droppedItem: inputValue) { iconData, title, url in
                StorageHelper.shared.saveToCoreData(itemURL: url, itemTitle: title, itemIconData: iconData, tag: tag)
            }
        }
    }

    private func actionEditItem(_ item: StockItem) {
        presentEditItemDialog(for: item)
    }

    private func actionEditDueDate(_ item: StockItem) {
        presentDeadlineDialog(for: item)
    }
}
