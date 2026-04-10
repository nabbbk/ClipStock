import SwiftUI
import ServiceManagement

enum AppTab: String, CaseIterable {
    case stock = "Stock"
    case clipboard = "Clipboard"
}

struct ContentView: View {

    @State private var selectedTab: AppTab = .stock

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            Picker("", selection: $selectedTab) {
                ForEach(AppTab.allCases, id: \.self) { tab in
                    Text(NSLocalizedString(tab.rawValue, comment: "")).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .focusable(false)
            .padding(.horizontal)
            .padding(.top, 10)

            // Tab content
            switch selectedTab {
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

// MARK: - Stock Tab (extracted from original ContentView)

struct StockView: View {

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \StockItem.addedDate, ascending: false)],
        animation: .default)
    private var items: FetchedResults<StockItem>

    @State private var searchText = ""
    @State private var allTags: Set<String> = []
    @State private var selectedTag = NSLocalizedString("All", comment: "")

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                SearchFieldView(searchText: $searchText)
                Button {
                    actionManuallyAddItem()
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .frame(height: 40)
                            .foregroundColor(Color(NSColor.controlBackgroundColor))
                        Image(systemName: "plus")
                            .foregroundColor(Color(NSColor.labelColor))
                            .font(.title2)
                    }
                    .frame(width: 44)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.top, 8)

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

                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(filteredItems) { item in
                            ItemViewCard(itemObject: item)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 8)
            }
        }
        .onAppear {
            allTags = StorageHelper.shared.getAllTags()
        }
    }

    private var filteredItems: [StockItem] {
        items.filter { item in
            if selectedTag != NSLocalizedString("All", comment: "") {
                if item.itemTag == nil && selectedTag == NSLocalizedString("Un-Tagged", comment: "") {
                    // pass through
                } else if item.itemTag != selectedTag {
                    return false
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
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 260, height: 80))
        let textView = NSTextView(frame: scrollView.contentView.bounds)
        textView.isEditable = true
        textView.isRichText = false
        textView.font = .systemFont(ofSize: 13)
        textView.autoresizingMask = [.width, .height]
        textView.isVerticallyResizable = true
        textView.textContainer?.widthTracksTextView = true
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        dialog.accessoryView = scrollView
        dialog.addButton(withTitle: NSLocalizedString("Add", comment: ""))
        dialog.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))

        guard let window = NSApplication.shared.windows.first(where: { $0.isVisible && $0.className.contains("Popover") }) ?? NSApplication.shared.keyWindow else { return }
        dialog.beginSheetModal(for: window) { response in
            guard response == .alertFirstButtonReturn,
                  !textView.string.isEmpty else { return }

            var inputValue: Any = textView.string
            if let url = URL(string: textView.string), url.scheme != nil {
                inputValue = url as NSURL
            }
            MetaDataHelper.fetchItemMetaData(droppedItem: inputValue) { iconData, title, url in
                StorageHelper.shared.saveToCoreData(itemURL: url, itemTitle: title, itemIconData: iconData)
            }
        }
    }
}
