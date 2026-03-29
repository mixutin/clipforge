import AppKit

@MainActor
final class ClipboardService {
    static let shared = ClipboardService()

    private static let supportedImageExtensions: Set<String> = [
        "png",
        "jpg",
        "jpeg",
        "webp",
        "gif",
        "tif",
        "tiff",
        "heic",
        "heif",
        "bmp"
    ]

    private init() {}

    func copyString(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }

    func copyImageAsset(_ asset: CapturedAsset) throws {
        guard let image = NSImage(data: asset.data) else {
            throw ClipforgeError.failedToEncodeImage
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        guard pasteboard.writeObjects([image]) else {
            throw ClipforgeError.failedToEncodeImage
        }
    }

    func containsUploadableImage() -> Bool {
        let pasteboard = NSPasteboard.general

        if NSImage(pasteboard: pasteboard) != nil {
            return true
        }

        return supportedImageFileURL(in: pasteboard) != nil
    }

    func loadImageAsset(filenameBase: String, settings: AppSettings) throws -> CapturedAsset {
        let pasteboard = NSPasteboard.general

        if let image = NSImage(pasteboard: pasteboard) {
            return try CapturedAsset.from(nsImage: image, filenameBase: filenameBase, settings: settings)
        }

        if let fileURL = supportedImageFileURL(in: pasteboard),
           let image = NSImage(contentsOf: fileURL) {
            return try CapturedAsset.from(nsImage: image, filenameBase: filenameBase, settings: settings)
        }

        throw ClipforgeError.clipboardDoesNotContainImage
    }

    private func supportedImageFileURL(in pasteboard: NSPasteboard) -> URL? {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true
        ]

        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL] else {
            return nil
        }

        return urls.first(where: Self.isSupportedImageFileURL)
    }

    private static func isSupportedImageFileURL(_ url: URL) -> Bool {
        supportedImageExtensions.contains(url.pathExtension.lowercased())
    }
}
