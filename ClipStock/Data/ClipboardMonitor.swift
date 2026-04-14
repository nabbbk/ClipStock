import Cocoa

class ClipboardMonitor {

    static let shared = ClipboardMonitor()

    private var timer: Timer?
    private var lastChangeCount: Int
    private var skipNextChange = 0

    private init() {
        lastChangeCount = NSPasteboard.general.changeCount
    }

    /// Call this before writing to the pasteboard from within the app.
    func ignoreSelfCopy() {
        skipNextChange = 2  // clearContents + setString both increment changeCount
    }

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func checkClipboard() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        // Skip if the app itself wrote to the clipboard
        if skipNextChange > 0 {
            skipNextChange -= 1
            return
        }

        let context = StorageHelper.shared.storageContext

        // Detect clipboard content type and save
        if let image = NSImage(pasteboard: pasteboard) {
            // Image clipboard (raw image data on pasteboard)
            let imageData = image.jpegData()
            let preview = pasteboard.string(forType: .string) ?? "Image"
            saveClip(type: "image", text: preview, imageData: imageData, context: context)
        } else if let urlString = pasteboard.string(forType: .string),
                  let url = URL(string: urlString),
                  let scheme = url.scheme,
                  ["http", "https"].contains(scheme.lowercased()) {
            // Link clipboard
            saveClip(type: "link", text: urlString, imageData: nil, context: context)
        } else if let text = pasteboard.string(forType: .string), !text.isEmpty {
            // Text clipboard
            saveClip(type: "text", text: text, imageData: nil, context: context)
        }
    }

    private func saveClip(type: String, text: String?, imageData: Data?, context: NSManagedObjectContext) {
        // Move to top: if duplicate text exists, update its date instead of creating new
        if let text {
            let request = NSFetchRequest<ClipboardItem>(entityName: "ClipboardItem")
            request.predicate = NSPredicate(format: "clipText == %@", text)
            if let existing = try? context.fetch(request).first {
                existing.clipDate = Date()
                existing.clipSourceApp = NSWorkspace.shared.frontmostApplication?.localizedName
                try? context.save()
                return
            }
        }

        let clip = ClipboardItem(context: context)
        clip.clipID = UUID().uuidString
        clip.clipDate = Date()
        clip.clipType = type
        clip.clipText = text
        clip.clipImageData = imageData
        clip.clipSourceApp = NSWorkspace.shared.frontmostApplication?.localizedName

        do {
            try context.save()
        } catch {
            print("Clipboard save error: \(error.localizedDescription)")
        }

        // Enforce 500 item limit
        purgeOldClips(context: context)
    }

    private func purgeOldClips(context: NSManagedObjectContext) {
        let limit = Preferences.maxHistoryCount
        let request = NSFetchRequest<ClipboardItem>(entityName: "ClipboardItem")
        request.predicate = NSPredicate(format: "isPinned == NO OR isPinned == nil")
        request.sortDescriptors = [NSSortDescriptor(key: "clipDate", ascending: false)]
        do {
            let unpinned = try context.fetch(request)
            if unpinned.count > limit {
                for clip in unpinned[limit...] {
                    context.delete(clip)
                }
                try context.save()
            }
        } catch {
            print("Purge error: \(error.localizedDescription)")
        }
    }
}
