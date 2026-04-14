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
            print("Save error: \(error.localizedDescription)")
        }
    }

    /// Promote a clipboard item to a permanent stock item.
    func promoteClipToStock(_ clip: ClipboardItem) {
        let newItem = StockItem(context: storageContext)
        newItem.itemID = UUID().uuidString
        newItem.addedDate = Date()
        newItem.sortIndex = nextSortIndex()

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
        deleteRequest.resultType = .resultTypeObjectIDs
        do {
            let result = try storageContext.execute(deleteRequest) as? NSBatchDeleteResult
            let objectIDs = result?.result as? [NSManagedObjectID] ?? []
            let changes: [AnyHashable: Any] = [NSDeletedObjectsKey: objectIDs]
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [storageContext])
        } catch {
            print("Clear clips error: \(error.localizedDescription)")
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
