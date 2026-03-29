import AppKit

@MainActor
final class ClipboardService {
    static let shared = ClipboardService()

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

    func loadImageAsset(filenameBase: String) throws -> CapturedAsset {
        guard let image = NSImage(pasteboard: .general) else {
            throw ClipforgeError.clipboardDoesNotContainImage
        }

        return try CapturedAsset.from(nsImage: image, filenameBase: filenameBase)
    }
}
