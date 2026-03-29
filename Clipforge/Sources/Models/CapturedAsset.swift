import AppKit

struct CapturedAsset: Sendable {
    let data: Data
    let mimeType: String
    let fileExtension: String
    let filenameBase: String

    var filename: String {
        "\(filenameBase).\(fileExtension)"
    }

    static func from(cgImage: CGImage, filenameBase: String) throws -> CapturedAsset {
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        return try encode(bitmapRep: bitmapRep, filenameBase: filenameBase)
    }

    static func from(nsImage: NSImage, filenameBase: String) throws -> CapturedAsset {
        if let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            return try from(cgImage: cgImage, filenameBase: filenameBase)
        }

        guard
            let tiffData = nsImage.tiffRepresentation,
            let bitmapRep = NSBitmapImageRep(data: tiffData)
        else {
            throw ClipforgeError.failedToEncodeImage
        }

        return try encode(bitmapRep: bitmapRep, filenameBase: filenameBase)
    }

    private static func encode(bitmapRep: NSBitmapImageRep, filenameBase: String) throws -> CapturedAsset {
        let usesPNG = bitmapRep.hasAlpha
        let fileType: NSBitmapImageRep.FileType = usesPNG ? .png : .jpeg
        let properties: [NSBitmapImageRep.PropertyKey: Any] = usesPNG ? [:] : [.compressionFactor: 0.92]

        guard let data = bitmapRep.representation(using: fileType, properties: properties) else {
            throw ClipforgeError.failedToEncodeImage
        }

        return CapturedAsset(
            data: data,
            mimeType: usesPNG ? "image/png" : "image/jpeg",
            fileExtension: usesPNG ? "png" : "jpg",
            filenameBase: filenameBase
        )
    }
}
