import Foundation
import CoreData

class StorageHelper {

    static let shared = StorageHelper()

    let storageContext: NSManagedObjectContext

    private init() {
        // Switch to NSPersistentCloudKitContainer when you have a paid Developer account
        let container = NSPersistentContainer(name: "ClipStock")
        container.loadPersistentStores { _, error in
            if let error {
                print("Core Data load error: \(error.localizedDescription)")
            }
        }
        let context = container.viewContext
        context.automaticallyMergesChangesFromParent = true
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        self.storageContext = context
    }

    func saveToCoreData(itemURL: URL?, itemTitle: String, itemIconData: Data?) {
        let newItem = StockItem(context: storageContext)
        newItem.itemID = UUID().uuidString
        newItem.addedDate = Date()
        newItem.itemURL = itemURL
        newItem.itemName = itemTitle
        newItem.itemIconData = itemIconData
        newItem.itemUnread = true
        do {
            try storageContext.save()
        } catch {
            print("Save error: \(error.localizedDescription)")
        }
    }

    func getUnreadItemCounting() -> Int {
        let request = NSFetchRequest<StockItem>(entityName: "StockItem")
        request.predicate = NSPredicate(format: "itemUnread == YES")
        do {
            return try storageContext.count(for: request)
        } catch {
            return 0
        }
    }

    /// Promote a clipboard item to a permanent stock item.
    func promoteClipToStock(_ clip: ClipboardItem) {
        let newItem = StockItem(context: storageContext)
        newItem.itemID = UUID().uuidString
        newItem.addedDate = Date()
        newItem.itemUnread = true

        switch clip.clipType {
        case "link":
            newItem.itemName = clip.clipText ?? "Link"
            if let urlString = clip.clipText, let url = URL(string: urlString) {
                newItem.itemURL = url
            }
        case "image":
            newItem.itemName = clip.clipText ?? "Image"
            newItem.itemIconData = clip.clipImageData
        default:
            newItem.itemName = clip.clipText ?? "Text"
        }

        do {
            try storageContext.save()
        } catch {
            print("Promote error: \(error.localizedDescription)")
        }
    }

    func getClipboardCount() -> Int {
        let request = NSFetchRequest<ClipboardItem>(entityName: "ClipboardItem")
        return (try? storageContext.count(for: request)) ?? 0
    }

    func clearAllClips() {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "ClipboardItem")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        do {
            try storageContext.execute(deleteRequest)
            try storageContext.save()
            storageContext.reset()
        } catch {
            print("Clear clips error: \(error.localizedDescription)")
        }
    }

    func getAllTags() -> Set<String> {
        let request = NSFetchRequest<StockItem>(entityName: "StockItem")
        var allTags: Set<String> = [NSLocalizedString("All", comment: "")]
        do {
            let result = try storageContext.fetch(request)
            for item in result {
                allTags.insert(item.itemTag ?? NSLocalizedString("Un-Tagged", comment: ""))
            }
            return allTags
        } catch {
            return allTags
        }
    }
}
