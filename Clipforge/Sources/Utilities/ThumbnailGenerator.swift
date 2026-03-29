import AppKit

enum ThumbnailGenerator {
    static func makePNGData(from imageData: Data, maxDimension: CGFloat = 84) -> Data? {
        guard let image = NSImage(data: imageData) else { return nil }
        return makePNGData(from: image, maxDimension: maxDimension)
    }

    static func makePNGData(from image: NSImage, maxDimension: CGFloat = 84) -> Data? {
        guard image.size.width > 0, image.size.height > 0 else { return nil }

        let scale = min(maxDimension / image.size.width, maxDimension / image.size.height, 1)
        let targetSize = NSSize(
            width: floor(image.size.width * scale),
            height: floor(image.size.height * scale)
        )

        let thumbnail = NSImage(size: targetSize)
        thumbnail.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(
            in: NSRect(origin: .zero, size: targetSize),
            from: NSRect(origin: .zero, size: image.size),
            operation: .copy,
            fraction: 1
        )
        thumbnail.unlockFocus()

        guard
            let tiffData = thumbnail.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiffData)
        else {
            return nil
        }

        return bitmap.representation(using: .png, properties: [:])
    }
}
