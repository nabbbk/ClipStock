import Cocoa

extension NSImage {
    /// Converts the image to JPEG data for compact Core Data storage.
    func jpegData(compressionFactor: CGFloat = 0.8) -> Data? {
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: compressionFactor])
    }
}
