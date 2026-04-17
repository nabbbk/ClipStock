import Foundation
import CoreData
import os.log

class StorageHelper {

    static let shared = StorageHelper()

    let storageContext: NSManagedObjectContext

    private static let log = Logger(subsystem: "com.nabbbk.ClipStock", category: "storage")

    private init() {
        // Switch to NSPersistentCloudKitContainer when you have a paid Developer account
        let container = NSPersistentContainer(name: "ClipStock")
        let description = container.persistentStoreDescriptions.first
        description?.shouldMigrateStoreAutomatically = true
        description?.shouldInferMappingModelAutomatically = true
        container.loadPersistentStores { _, error in
            if let error {
                Self.log.error("store load failed: \(String(describing: error), privacy: .public)")
            }
        }
        let context = container.viewContext
        context.automaticallyMergesChangesFromParent = true
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        self.storageContext = context

        migrateLegacyPlaintextIfNeeded()
    }

    /// One-shot: re-encrypt any row still holding legacy plaintext in clipText /
    /// clipImageData, then null those columns. Safe to call on every launch — it
    /// does nothing once migration is complete.
    private func migrateLegacyPlaintextIfNeeded() {
        guard ClipCrypto.isAvailable else {
            Self.log.error("crypto unavailable — skipping migration")
            return
        }
        let request = NSFetchRequest<ClipboardItem>(entityName: "ClipboardItem")
        request.predicate = NSPredicate(format: "clipText != nil OR clipImageData != nil")
        guard let rows = try? storageContext.fetch(request), !rows.isEmpty else { return }

        for clip in rows {
            if let legacyText = clip.clipText {
                clip.clipTextEnc = ClipCrypto.encryptString(legacyText)
                clip.clipTextHash = ClipCrypto.hashString(legacyText)
                clip.clipText = nil
            }
            if let legacyImage = clip.clipImageData {
                clip.clipImageDataEnc = ClipCrypto.encrypt(legacyImage)
                clip.clipImageData = nil
            }
        }
        do {
            try storageContext.save()
            Self.log.info("migrated \(rows.count, privacy: .public) row(s) to encrypted storage")
        } catch {
            Self.log.error("migration save failed: \(String(describing: error), privacy: .public)")
        }
    }

    private func nextSortIndex() -> Int32 {
        let request = NSFetchRequest<StockItem>(entityName: "StockItem")
        request.sortDescriptors = [NSSortDescriptor(key: "sortIndex", ascending: false)]
        request.fetchLimit = 1
        let max = (try? storageContext.fetch(request).first)?.sortIndex ?? -1
        return max + 1
    }

    func saveToCoreData(itemURL: URL?, itemTitle: String, itemIconData: Data?, tag: String? = nil) {
        let newItem = StockItem(context: storageContext)
        newItem.itemID = UUID().uuidString
        newItem.addedDate = Date()
        newItem.itemURL = itemURL
        newItem.itemName = itemTitle
        newItem.itemIconData = itemIconData
        newItem.itemTag = tag
        newItem.sortIndex = nextSortIndex()
        do {
            try storageContext.save()
        } catch {
            Self.log.error("saveToCoreData failed: \(String(describing: error), privacy: .public)")
        }
    }

    /// Promote a clipboard item to a permanent stock item.
    func promoteClipToStock(_ clip: ClipboardItem) {
        let newItem = StockItem(context: storageContext)
        newItem.itemID = UUID().uuidString
        newItem.addedDate = Date()
        newItem.sortIndex = nextSortIndex()

        let plainText = clip.plainText

        switch clip.clipType {
        case "link":
            newItem.itemName = plainText ?? "Link"
            if let urlString = plainText, let url = URL(string: urlString) {
                newItem.itemURL = url
            }
        case "image":
            newItem.itemName = plainText ?? "Image"
            newItem.itemIconData = clip.plainImage
        default:
            newItem.itemName = plainText ?? "Text"
        }

        do {
            try storageContext.save()
        } catch {
            Self.log.error("promote failed: \(String(describing: error), privacy: .public)")
        }
    }

    func getClipboardCount() -> Int {
        let request = NSFetchRequest<ClipboardItem>(entityName: "ClipboardItem")
        return (try? storageContext.count(for: request)) ?? 0
    }

    func clearAllClips() {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "ClipboardItem")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        deleteRequest.resultType = .resultTypeObjectIDs
        do {
            let result = try storageContext.execute(deleteRequest) as? NSBatchDeleteResult
            let objectIDs = result?.result as? [NSManagedObjectID] ?? []
            let changes: [AnyHashable: Any] = [NSDeletedObjectsKey: objectIDs]
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [storageContext])
        } catch {
            Self.log.error("clearAllClips failed: \(String(describing: error), privacy: .public)")
        }
    }

    func togglePin(_ clip: ClipboardItem) {
        clip.isPinned = !clip.isPinned
        try? storageContext.save()
    }

    func getAllTags() -> Set<String> {
        let request = NSFetchRequest<StockItem>(entityName: "StockItem")
        var allTags: Set<String> = [NSLocalizedString("All", comment: "")]
        do {
            let result = try storageContext.fetch(request)
            for item in result {
                if let tagString = item.itemTag {
                    for tag in tagString.split(separator: ",") {
                        allTags.insert(tag.trimmingCharacters(in: .whitespaces))
                    }
                } else {
                    allTags.insert(NSLocalizedString("Un-Tagged", comment: ""))
                }
            }
            return allTags
        } catch {
            return allTags
        }
    }
}
