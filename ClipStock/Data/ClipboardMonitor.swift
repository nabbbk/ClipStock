import Cocoa

class ClipboardMonitor {

    static let shared = ClipboardMonitor()

    private var timer: Timer?
    private var lastChangeCount: Int
    private var skipNextChange = false

    private init() {
        lastChangeCount = NSPasteboard.general.changeCount
    }

    /// Call this before writing to the pasteboard from within the app.
    func ignoreSelfCopy() {
        skipNextChange = true
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
        if skipNextChange {
            skipNextChange = false
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
        // Skip duplicates: don't save if the most recent clip has the same content
        if let text, let lastClip = fetchLastClip(context: context), lastClip.clipText == text {
            return
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

    private func fetchLastClip(context: NSManagedObjectContext) -> ClipboardItem? {
        let request = NSFetchRequest<ClipboardItem>(entityName: "ClipboardItem")
        request.sortDescriptors = [NSSortDescriptor(key: "clipDate", ascending: false)]
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    private func purgeOldClips(context: NSManagedObjectContext) {
        let request = NSFetchRequest<ClipboardItem>(entityName: "ClipboardItem")
        request.sortDescriptors = [NSSortDescriptor(key: "clipDate", ascending: false)]
        do {
            let allClips = try context.fetch(request)
            if allClips.count > 500 {
                for clip in allClips[500...] {
                    context.delete(clip)
                }
                try context.save()
            }
        } catch {
            print("Purge error: \(error.localizedDescription)")
        }
    }
}
