import Cocoa
import SwiftUI
import Carbon.HIToolbox
import KeyboardShortcuts

class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {

    private var popover: NSPopover!
    private var statusBarItem: NSStatusItem!
    private var eventMonitor: Any?
    private var localKeyMonitor: Any?
    private var settingsWindow: NSWindow?

    /// Exposed for sharing service picker in ItemViewCard
    var popoverContentView: NSView? {
        popover?.contentViewController?.view
    }
    private let persistence = StorageHelper.shared

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSView.disableFocusRings()

        let contentView = ContentView()
            .environment(\.managedObjectContext, persistence.storageContext)

        // Start clipboard monitoring
        ClipboardMonitor.shared.start()

        // Reconcile launch-at-login state with stored preference
        LaunchAtLoginHelper.applyStoredPreference()

        let popover = NSPopover()
        popover.contentSize = NSSize(width: 400, height: 560)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: contentView)
        popover.delegate = self
        self.popover = popover

        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusBarItem.button else { return }
        button.image = NSImage(systemSymbolName: "tray.full.fill", accessibilityDescription: "ClipStock")
        button.imagePosition = .imageLeft
        button.title = "\(persistence.getUnreadItemCounting())"
        button.action = #selector(statusBarButtonClicked(_:))
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        // Register for drag-and-drop on the status bar button's window
        button.window?.registerForDraggedTypes([.URL, .string])
        button.window?.delegate = self

        // Global hotkeys via KeyboardShortcuts
        registerGlobalHotKeys()

        // Local hotkeys (when popover is open)
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.popover.isShown else { return event }
            return self.handleLocalKey(event) ? nil : event
        }
    }

    func popoverWillClose(_ notification: Notification) {
        statusBarItem.button?.title = "\(persistence.getUnreadItemCounting())"
    }

    // MARK: - Popover Toggle

    @objc func statusBarButtonClicked(_ sender: AnyObject?) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            showStatusBarMenu()
        } else {
            togglePopover(sender)
        }
    }

    private func showStatusBarMenu() {
        let menu = NSMenu()
        let prefsItem = NSMenuItem(
            title: NSLocalizedString("Preferences...", comment: ""),
            action: #selector(openPreferences),
            keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(
            title: NSLocalizedString("Quit ClipStock", comment: ""),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"))
        statusBarItem.menu = menu
        statusBarItem.button?.performClick(nil)
        statusBarItem.menu = nil
    }

    @objc func openPreferences() {
        if settingsWindow == nil {
            let hosting = NSHostingController(rootView: SettingsView())
            let window = NSWindow(contentViewController: hosting)
            window.title = NSLocalizedString("ClipStock Preferences", comment: "")
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            settingsWindow = window
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        if (notification.object as? NSWindow) === settingsWindow {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        guard let button = statusBarItem.button else { return }
        if popover.isShown {
            closePopover(sender)
        } else {
            NSApplication.shared.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.becomeKey()
            eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                self?.closePopover(nil)
            }
        }
        button.title = "\(persistence.getUnreadItemCounting())"
    }

    private func closePopover(_ sender: AnyObject?) {
        popover.performClose(sender)
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    // MARK: - Global Hotkeys

    private func registerGlobalHotKeys() {
        KeyboardShortcuts.onKeyUp(for: .openStock) { [weak self] in
            AppState.shared.selectedTab = .stock
            if self?.popover.isShown == false { self?.togglePopover(nil) }
        }
        KeyboardShortcuts.onKeyUp(for: .openClipboard) { [weak self] in
            AppState.shared.selectedTab = .clipboard
            if self?.popover.isShown == false { self?.togglePopover(nil) }
        }
    }

    // MARK: - Local Keyboard Shortcuts

    private func handleLocalKey(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let state = AppState.shared
        let textFieldActive = NSApp.keyWindow?.firstResponder is NSText

        // Esc — if a dialog sheet is showing, let it handle Esc; otherwise close popover
        if event.keyCode == 53 {
            if let window = popover.contentViewController?.view.window, window.attachedSheet != nil {
                return false
            }
            closePopover(nil)
            return true
        }

        // Navigation keys — only when not typing in a text field and no dialog open
        let sheetOpen = popover.contentViewController?.view.window?.attachedSheet != nil
        if !textFieldActive && !sheetOpen {
            let hasShift = flags.contains(.shift)
            switch event.keyCode {
            case 48: // Tab
                if !hasShift {
                    state.selectedTab = state.selectedTab == .stock ? .clipboard : .stock
                    return true
                }
            case 36: // Enter
                if !hasShift {
                    state.keyAction.send(.copySelected)
                    if Preferences.pasteOnSelect {
                        closePopover(nil)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                            PasteHelper.simulatePaste()
                        }
                    }
                    return true
                }
            case 126: // ↑
                state.keyAction.send(hasShift ? .navigateUpExtend : .navigateUp)
                return true
            case 125: // ↓
                state.keyAction.send(hasShift ? .navigateDownExtend : .navigateDown)
                return true
            default:
                break
            }
        }

        // Cmd shortcuts — use key codes (works with any input method), skip when dialog open
        if flags == .command && !sheetOpen {
            switch Int(event.keyCode) {
            case kVK_ANSI_F:
                state.keyAction.send(.focusSearch)
                return true
            case kVK_ANSI_N:
                if state.selectedTab == .stock {
                    state.keyAction.send(.addItem)
                    return true
                }
            case kVK_ANSI_R:
                state.keyAction.send(.markAsRead)
                return true
            case kVK_ANSI_E:
                state.keyAction.send(.editItem)
                return true
            case kVK_ANSI_D:
                state.keyAction.send(.addDeadline)
                return true
            case kVK_ANSI_S:
                state.keyAction.send(.saveToStock)
                return true
            case kVK_ANSI_P:
                state.keyAction.send(.togglePin)
                return true
            case kVK_Delete: // Cmd+Backspace
                state.keyAction.send(.deleteSelected)
                return true
            case kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4,
                 kVK_ANSI_5, kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9:
                if let n = digitIndex(forKeyCode: Int(event.keyCode)) {
                    state.keyAction.send(.copyIndex(n))
                    closePopover(nil)
                    if Preferences.pasteOnSelect {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                            PasteHelper.simulatePaste()
                        }
                    }
                    return true
                }
            default:
                break
            }
        }

        // Cmd+Shift shortcuts
        if flags == [.command, .shift] && !sheetOpen {
            switch Int(event.keyCode) {
            case kVK_ANSI_D:
                state.keyAction.send(.removeDeadline)
                return true
            default:
                break
            }
        }

        // Cmd+Option shortcuts
        if flags == [.command, .option] && !sheetOpen {
            switch Int(event.keyCode) {
            case kVK_ANSI_V:
                state.keyAction.send(.copyPlainText)
                return true
            default:
                break
            }
        }

        return false
    }

    private func digitIndex(forKeyCode code: Int) -> Int? {
        switch code {
        case kVK_ANSI_1: return 0
        case kVK_ANSI_2: return 1
        case kVK_ANSI_3: return 2
        case kVK_ANSI_4: return 3
        case kVK_ANSI_5: return 4
        case kVK_ANSI_6: return 5
        case kVK_ANSI_7: return 6
        case kVK_ANSI_8: return 7
        case kVK_ANSI_9: return 8
        default: return nil
        }
    }
}

// MARK: - Drag and Drop

extension AppDelegate: NSWindowDelegate, NSDraggingDestination {

    func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .link
    }

    func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return sender.draggingSourceOperationMask
    }

    func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let firstObject = sender.draggingPasteboard
            .readObjects(forClasses: [NSURL.self, NSString.self])?.first else {
            return false
        }

        MetaDataHelper.fetchItemMetaData(droppedItem: firstObject) { iconData, itemTitle, itemURL in
            self.persistence.saveToCoreData(itemURL: itemURL, itemTitle: itemTitle, itemIconData: iconData)
            DispatchQueue.main.async {
                self.statusBarItem.button?.title = "\(self.persistence.getUnreadItemCounting())"
            }

            // Remind first-time user that only file references are saved
            if !UserDefaults.standard.bool(forKey: "file-path-reminder-shown") {
                UserDefaults.standard.set(true, forKey: "file-path-reminder-shown")
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.informativeText = NSLocalizedString(
                        "Only file references are saved. If you delete or move the file, this app will not be able to open the file.",
                        comment: "")
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            }
        }
        return true
    }
}

// MARK: - KeyboardShortcuts Definitions

extension KeyboardShortcuts.Name {
    static let openStock = Self("openStock", default: .init(.v, modifiers: [.control, .shift]))
    static let openClipboard = Self("openClipboard", default: .init(.c, modifiers: [.control, .shift]))
}
