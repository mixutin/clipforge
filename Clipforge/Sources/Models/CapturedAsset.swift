import AppKit

struct CapturedAsset: Sendable {
    let data: Data
    let mimeType: String
    let fileExtension: String
    let filenameBase: String

    var filename: String {
        "\(filenameBase).\(fileExtension)"
    }

    static func from(cgImage: CGImage, filenameBase: String, settings: AppSettings) throws -> CapturedAsset {
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        return try encode(bitmapRep: bitmapRep, filenameBase: filenameBase, settings: settings)
    }

    static func from(nsImage: NSImage, filenameBase: String, settings: AppSettings) throws -> CapturedAsset {
        if let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            return try from(cgImage: cgImage, filenameBase: filenameBase, settings: settings)
        }

        guard
            let tiffData = nsImage.tiffRepresentation,
            let bitmapRep = NSBitmapImageRep(data: tiffData)
        else {
            throw ClipforgeError.failedToEncodeImage
        }

        return try encode(bitmapRep: bitmapRep, filenameBase: filenameBase, settings: settings)
    }

    private static func encode(bitmapRep: NSBitmapImageRep, filenameBase: String, settings: AppSettings) throws -> CapturedAsset {
        let resolvedFormat = resolvedFormat(for: bitmapRep, mode: settings.imageFormatMode)
        let fileType: NSBitmapImageRep.FileType
        let mimeType: String
        let fileExtension: String
        let properties: [NSBitmapImageRep.PropertyKey: Any]
        let sourceRep: NSBitmapImageRep

        switch resolvedFormat {
        case .png:
            fileType = .png
            mimeType = "image/png"
            fileExtension = "png"
            properties = [:]
            sourceRep = bitmapRep
        case .jpeg:
            fileType = .jpeg
            mimeType = "image/jpeg"
            fileExtension = "jpg"
            properties = [.compressionFactor: min(max(settings.jpegCompressionQuality, 0.4), 1.0)]
            sourceRep = try bitmapRep.hasAlpha ? flattenedBitmapRep(from: bitmapRep) : bitmapRep
        }

        guard let data = sourceRep.representation(using: fileType, properties: properties) else {
            throw ClipforgeError.failedToEncodeImage
        }

        return CapturedAsset(
            data: data,
            mimeType: mimeType,
            fileExtension: fileExtension,
            filenameBase: filenameBase
        )
    }

    private enum ResolvedFormat {
        case png
        case jpeg
    }

    private static func resolvedFormat(
        for bitmapRep: NSBitmapImageRep,
        mode: AppSettings.ImageFormatMode
    ) -> ResolvedFormat {
        switch mode {
        case .automatic:
            return bitmapRep.hasAlpha ? .png : .jpeg
        case .png:
            return .png
        case .jpeg:
            return .jpeg
        }
    }

    private static func flattenedBitmapRep(from bitmapRep: NSBitmapImageRep) throws -> NSBitmapImageRep {
        let width = bitmapRep.pixelsWide
        let height = bitmapRep.pixelsHigh
        let imageRect = NSRect(x: 0, y: 0, width: width, height: height)
        let image = NSImage(size: NSSize(width: width, height: height))
        image.addRepresentation(bitmapRep)
        let flattenedImage = NSImage(size: image.size)

        flattenedImage.lockFocusFlipped(true)
        NSColor.white.setFill()
        imageRect.fill()
        image.draw(in: imageRect, from: .zero, operation: .sourceOver, fraction: 1)
        flattenedImage.unlockFocus()

        guard
            let tiffData = flattenedImage.tiffRepresentation,
            let flattenedRep = NSBitmapImageRep(data: tiffData)
        else {
            throw ClipforgeError.failedToEncodeImage
        }

        return flattenedRep
    }
}
