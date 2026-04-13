import SwiftUI
import ServiceManagement

enum AppTab: String, CaseIterable {
    case stock = "Stock"
    case clipboard = "Clipboard"
}

struct ContentView: View {

    @ObservedObject private var appState = AppState.shared

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
                Toggle(NSLocalizedString("Launch at login", comment: ""), isOn: Binding(
                    get: { SMAppService.mainApp.status == .enabled },
                    set: { newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            print("Launch at login error: \(error)")
                        }
                    }
                ))
                .toggleStyle(.checkbox)

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

// MARK: - Stock Tab (extracted from original ContentView)

struct StockView: View {

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \StockItem.addedDate, ascending: false)],
        animation: .default)
    private var items: FetchedResults<StockItem>

    @State private var searchText = ""
    @State private var allTags: Set<String> = []
    @State private var selectedTag = NSLocalizedString("All", comment: "")
    @State private var selectedIDs: Set<String> = []
    @State private var cursorID: String?
    @State private var anchorID: String?
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
                HStack {
                    Menu(selectedTag) {
                        ForEach(allTags.sorted(), id: \.self) { tag in
                            Button(tag) { selectedTag = tag }
                        }
                    }
                    Button {
                        allTags = StorageHelper.shared.getAllTags()
                    } label: {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(filteredItems) { item in
                                ItemViewCard(itemObject: item)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.accentColor, lineWidth: 2)
                                            .opacity(selectedIDs.contains(item.itemID ?? "") ? 1 : 0)
                                    )
                                    .id(item.itemID)
                                    .onTapGesture {
                                        handleItemClick(item, in: filteredItems)
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
            allTags = StorageHelper.shared.getAllTags()
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
                ClipboardMonitor.shared.ignoreSelfCopy()
                NSPasteboard.general.clearContents()
                if let url = item.itemURL {
                    NSPasteboard.general.setString(url.absoluteString, forType: .string)
                } else {
                    NSPasteboard.general.setString(item.itemName ?? "", forType: .string)
                }
                item.itemUnread = false
                try? StorageHelper.shared.storageContext.save()
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
        case .markAsRead:
            let toToggle = items.filter { selectedIDs.contains($0.itemID ?? "") }
            for item in toToggle { item.itemUnread.toggle() }
            try? StorageHelper.shared.storageContext.save()
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
        case .copyIndex:
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
        for button in dialog.buttons { button.focusRingType = .exterior }

        guard let window = NSApplication.shared.windows.first(where: { $0.isVisible && $0.className.contains("Popover") }) ?? NSApplication.shared.keyWindow else { return }
        // Auto-focus content field after sheet appears
        DispatchQueue.main.async { window.attachedSheet?.makeFirstResponder(textView) }
        dialog.beginSheetModal(for: window) { response in
            window.makeKey()

            guard response == .alertFirstButtonReturn,
                  !textView.string.isEmpty else { return }

            var tag: String? = nil
            if !tagField.stringValue.isEmpty {
                let formatted = tagField.stringValue
                    .split(separator: ",")
                    .map { t in
                        let trimmed = t.trimmingCharacters(in: .whitespaces)
                        return trimmed.hasPrefix("#") ? trimmed : "#\(trimmed)"
                    }
                    .joined(separator: ",")
                tag = formatted
            }

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
        tagField.stringValue = (item.itemTag ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "#", with: "") }
            .joined(separator: ", ")
        tagField.placeholderString = "Tag"
        tagField.font = .systemFont(ofSize: 13)

        stack.addArrangedSubview(scrollView)
        stack.addArrangedSubview(tagField)
        dialog.accessoryView = stack

        let okButton = dialog.addButton(withTitle: "OK")
        okButton.keyEquivalent = ""
        let cancelButton = dialog.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
        cancelButton.keyEquivalent = "\u{1b}"
        for button in dialog.buttons { button.focusRingType = .exterior }

        titleField.alert = dialog
        titleField.tabTarget = tagField
        tagField.alert = dialog

        let buttons2 = dialog.buttons
        tagField.nextKeyView = buttons2.first
        if buttons2.count > 1 {
            for i in 0..<buttons2.count - 1 {
                buttons2[i].nextKeyView = buttons2[i + 1]
            }
        }
        buttons2.last?.nextKeyView = titleField

        guard let window = NSApplication.shared.windows.first(where: { $0.isVisible && $0.className.contains("Popover") }) ?? NSApplication.shared.keyWindow else { return }
        DispatchQueue.main.async { window.attachedSheet?.makeFirstResponder(titleField) }
        dialog.beginSheetModal(for: window) { response in
            window.makeKey()
            guard response == .alertFirstButtonReturn, !titleField.string.isEmpty else { return }
            item.itemName = titleField.string
            if tagField.stringValue.isEmpty {
                item.itemTag = nil
            } else {
                let formatted = tagField.stringValue
                    .split(separator: ",")
                    .map { t in
                        let trimmed = t.trimmingCharacters(in: .whitespaces)
                        return trimmed.hasPrefix("#") ? trimmed : "#\(trimmed)"
                    }
                    .joined(separator: ",")
                item.itemTag = formatted
            }
            try? StorageHelper.shared.storageContext.save()
        }
    }

    private func actionEditDueDate(_ item: StockItem) {
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
        for button in dialog.buttons { button.focusRingType = .exterior }
        guard let window = NSApplication.shared.windows.first(where: { $0.isVisible && $0.className.contains("Popover") }) ?? NSApplication.shared.keyWindow else { return }
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
}
