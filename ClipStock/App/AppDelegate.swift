import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {

    private var popover: NSPopover!
    private var statusBarItem: NSStatusItem!
    private var eventMonitor: Any?

    /// Exposed for sharing service picker in ItemViewCard
    var popoverContentView: NSView? {
        popover?.contentViewController?.view
    }
    private let persistence = StorageHelper.shared

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        let contentView = ContentView()
            .environment(\.managedObjectContext, persistence.storageContext)

        // Start clipboard monitoring
        ClipboardMonitor.shared.start()

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
        button.action = #selector(togglePopover(_:))
        button.target = self

        // Register for drag-and-drop on the status bar button's window
        button.window?.registerForDraggedTypes([.URL, .string])
        button.window?.delegate = self
    }

    func popoverWillClose(_ notification: Notification) {
        statusBarItem.button?.title = "\(persistence.getUnreadItemCounting())"
    }

    // MARK: - Popover Toggle

    @objc private func togglePopover(_ sender: AnyObject?) {
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
