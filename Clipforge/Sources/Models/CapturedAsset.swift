import AppKit

struct CapturedAsset: Sendable {
    enum MediaKind: String, Sendable {
        case image
        case video
    }

    let data: Data
    let mimeType: String
    let fileExtension: String
    let filenameBase: String
    let mediaKind: MediaKind
    let thumbnailPNGData: Data?
    let durationSeconds: Double?

    init(
        data: Data,
        mimeType: String,
        fileExtension: String,
        filenameBase: String,
        mediaKind: MediaKind = .image,
        thumbnailPNGData: Data? = nil,
        durationSeconds: Double? = nil
    ) {
        self.data = data
        self.mimeType = mimeType
        self.fileExtension = fileExtension
        self.filenameBase = filenameBase
        self.mediaKind = mediaKind
        self.thumbnailPNGData = thumbnailPNGData
        self.durationSeconds = durationSeconds
    }

    var filename: String {
        "\(filenameBase).\(fileExtension)"
    }

    var isImage: Bool {
        mediaKind == .image
    }

    var isVideo: Bool {
        mediaKind == .video
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

    static func video(
        data: Data,
        filenameBase: String,
        fileExtension: String = "mp4",
        mimeType: String = "video/mp4",
        thumbnailImage: NSImage? = nil,
        durationSeconds: Double? = nil
    ) -> CapturedAsset {
        CapturedAsset(
            data: data,
            mimeType: mimeType,
            fileExtension: fileExtension,
            filenameBase: filenameBase,
            mediaKind: .video,
            thumbnailPNGData: thumbnailImage.flatMap { ThumbnailGenerator.makePNGData(from: $0) },
            durationSeconds: durationSeconds
        )
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

        let thumbnailPNGData = NSImage(data: data).flatMap { ThumbnailGenerator.makePNGData(from: $0) }

        return CapturedAsset(
            data: data,
            mimeType: mimeType,
            fileExtension: fileExtension,
            filenameBase: filenameBase,
            mediaKind: .image,
            thumbnailPNGData: thumbnailPNGData,
            durationSeconds: nil
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
