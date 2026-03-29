import CoreGraphics
import XCTest
@testable import Clipforge

final class ScrollImageStitcherTests: XCTestCase {
    func testStitchReturnsTallerImageWhenGivenMultipleFrames() throws {
        let frames = try makeScrollFrames()

        let stitched = try XCTUnwrap(ScrollImageStitcher.stitch(images: frames))

        XCTAssertEqual(stitched.width, 360)
        XCTAssertGreaterThan(stitched.height, try XCTUnwrap(frames.first).height)
        XCTAssertLessThanOrEqual(stitched.height, frames.reduce(0) { $0 + $1.height })
    }

    private func makeScrollFrames() throws -> [CGImage] {
        let frameWidth = 360
        let frameHeight = 260
        let headerHeight = 44
        let viewportHeight = frameHeight - headerHeight
        let offsets = [0, 160, 320, 480]
        let contentHeight = 980
        let contentImage = try makeContentImage(width: frameWidth, height: contentHeight)

        return try offsets.map { offset in
            try makeFrame(
                width: frameWidth,
                height: frameHeight,
                headerHeight: headerHeight,
                viewportHeight: viewportHeight,
                contentHeight: contentHeight,
                offset: offset,
                contentImage: contentImage
            )
        }
    }

    private func makeFrame(
        width: Int,
        height: Int,
        headerHeight: Int,
        viewportHeight: Int,
        contentHeight: Int,
        offset: Int,
        contentImage: CGImage
    ) throws -> CGImage {
        let context = try makeContext(width: width, height: height)

        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)

        context.setFillColor(CGColor(red: 0.08, green: 0.1, blue: 0.15, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: headerHeight))

        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.92))
        context.fill(CGRect(x: 18, y: 12, width: 170, height: 8))
        context.fill(CGRect(x: 18, y: 26, width: 120, height: 6))

        context.saveGState()
        context.clip(to: CGRect(x: 0, y: headerHeight, width: width, height: viewportHeight))
        context.draw(
            contentImage,
            in: CGRect(x: 0, y: headerHeight - offset, width: width, height: contentHeight)
        )
        context.restoreGState()

        guard let image = context.makeImage() else {
            throw ClipforgeError.scrollCaptureFailed
        }

        return image
    }

    private func makeContentImage(width: Int, height: Int) throws -> CGImage {
        let context = try makeContext(width: width, height: height)

        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)

        for row in 0..<height {
            let value = CGFloat((row * 73 + 19) % 251) / 255
            let color = CGColor(
                red: 0.15 + (value * 0.65),
                green: 0.18 + (value * 0.58),
                blue: 0.2 + (value * 0.72),
                alpha: 1
            )
            context.setFillColor(color)
            context.fill(CGRect(x: 0, y: row, width: width, height: 1))

            let accentWidth = 40 + ((row * 11) % 180)
            context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.08))
            context.fill(CGRect(x: 16, y: row, width: accentWidth, height: 1))
        }

        for index in 0..<12 {
            let rowY = 18 + (index * 78)
            let cardRect = CGRect(x: 18, y: rowY, width: width - 36, height: 56)
            let color = palette(for: index)
            context.setFillColor(color)
            let path = CGPath(
                roundedRect: cardRect,
                cornerWidth: 18,
                cornerHeight: 18,
                transform: nil
            )
            context.addPath(path)
            context.fillPath()

            context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.82))
            context.fill(CGRect(x: cardRect.minX + 18, y: cardRect.minY + 18, width: cardRect.width * 0.58, height: 10))
            context.fill(CGRect(x: cardRect.minX + 36, y: cardRect.minY + 34, width: cardRect.width * 0.36, height: 10))
        }

        guard let image = context.makeImage() else {
            throw ClipforgeError.scrollCaptureFailed
        }

        return image
    }

    private func makeContext(width: Int, height: Int) throws -> CGContext {
        guard
            let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else {
            throw ClipforgeError.scrollCaptureFailed
        }

        return context
    }

    private func palette(for index: Int) -> CGColor {
        CGColor(
            red: 0.17 + Double(index % 3) * 0.08,
            green: 0.34 + Double(index % 4) * 0.07,
            blue: 0.64 + Double(index % 5) * 0.04,
            alpha: 1
        )
    }
}
