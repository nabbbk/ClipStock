import Cocoa
import LinkPresentation
import UniformTypeIdentifiers

class MetaDataHelper {

    /// Fetches icon, title, and URL for a dropped item (URL, file path, or plain text).
    static func fetchItemMetaData(
        droppedItem: Any,
        completionHandler: @escaping (Data?, String, URL?) -> Void
    ) {
        if let url = droppedItem as? NSURL {
            if url.isFileURL,
               let filePath = url.path,
               let fileName = url.lastPathComponent {
                let icon = NSWorkspace.shared.icon(forFile: filePath)
                completionHandler(icon.jpegData(), fileName, url as URL)
            } else {
                // Web URL — fetch metadata via LinkPresentation
                LPMetadataProvider().startFetchingMetadata(for: url as URL) { metaData, _ in
                    let title = metaData?.title ?? url.description
                    guard let iconProvider = metaData?.iconProvider else {
                        completionHandler(nil, title, url as URL)
                        return
                    }
                    iconProvider.loadItem(
                        forTypeIdentifier: UTType.image.identifier,
                        options: [:]
                    ) { data, _ in
                        guard let imgData = data as? Data,
                              let img = NSImage(data: imgData) else {
                            completionHandler(nil, title, url as URL)
                            return
                        }
                        completionHandler(img.jpegData(), title, url as URL)
                    }
                }
            }
        } else if let text = droppedItem as? NSString {
            completionHandler(nil, text as String, nil)
        } else {
            completionHandler(nil, "Unknown item", nil)
        }
    }
}
