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

    func loadImageAsset(filenameBase: String) throws -> CapturedAsset {
        guard let image = NSImage(pasteboard: .general) else {
            throw ClipforgeError.clipboardDoesNotContainImage
        }

        return try CapturedAsset.from(nsImage: image, filenameBase: filenameBase)
    }
}
