import CoreGraphics

enum ScrollImageStitcher {
    static func stitch(images: [CGImage]) -> CGImage? {
        guard images.isEmpty == false else { return nil }

        let pixelImages = images.compactMap(PixelImage.init)
        guard pixelImages.count == images.count else { return nil }

        guard let first = pixelImages.first else { return nil }
        guard pixelImages.dropFirst().allSatisfy({ $0.width == first.width }) else { return nil }

        let reducedImages = pixelImages.map { $0.reduced(sampleWidth: 48) }

        var cropStarts = Array(repeating: 0, count: pixelImages.count)
        for index in 1..<pixelImages.count {
            cropStarts[index] = match(previous: reducedImages[index - 1], current: reducedImages[index]).cropStart
        }

        let totalHeight = zip(pixelImages.indices, pixelImages).reduce(0) { partial, pair in
            let (index, image) = pair
            return partial + image.height - cropStarts[index]
        }

        var stitchedPixels: [UInt8] = []
        stitchedPixels.reserveCapacity(totalHeight * first.bytesPerRow)

        for (index, image) in pixelImages.enumerated() {
            image.appendRows(startingAt: cropStarts[index], into: &stitchedPixels)
        }

        return PixelImage.makeCGImage(
            width: first.width,
            height: totalHeight,
            pixels: stitchedPixels
        )
    }

    private static func match(previous: ReducedImage, current: ReducedImage) -> Match {
        let maxHeaderInset = min(current.height / 4, 220)
        let minOverlap = max(24, previous.height / 12)
        let maxOverlap = max(minOverlap, min(previous.height - 40, Int(Double(previous.height) * 0.82)))

        var bestMatch = Match(cropStart: max(0, current.height - previous.height / 2), score: .greatestFiniteMagnitude)

        for headerInset in stride(from: 0, through: maxHeaderInset, by: 4) {
            let availableHeight = current.height - headerInset
            guard availableHeight > minOverlap else { continue }

            let overlapUpperBound = min(maxOverlap, availableHeight - 16)
            guard overlapUpperBound >= minOverlap else { continue }

            for overlap in stride(from: overlapUpperBound, through: minOverlap, by: -4) {
                let previousStart = previous.height - overlap
                let currentStart = headerInset
                let rawScore = rowDifference(
                    previous,
                    previousStart: previousStart,
                    current,
                    currentStart: currentStart,
                    rowCount: overlap
                )
                let overlapBonus = Double(overlap) / Double(previous.height) * 0.025
                let adjustedScore = rawScore - overlapBonus

                if adjustedScore < bestMatch.score {
                    bestMatch = Match(cropStart: currentStart + overlap, score: adjustedScore)
                }

                if rawScore < 0.032 {
                    break
                }
            }
        }

        guard bestMatch.score < 0.12 else {
            return Match(cropStart: 0, score: bestMatch.score)
        }

        return bestMatch
    }

    private static func rowDifference(
        _ previous: ReducedImage,
        previousStart: Int,
        _ current: ReducedImage,
        currentStart: Int,
        rowCount: Int
    ) -> Double {
        let width = previous.width
        var totalDifference: Double = 0

        for rowOffset in 0..<rowCount {
            let previousIndex = (previousStart + rowOffset) * width
            let currentIndex = (currentStart + rowOffset) * width

            for column in 0..<width {
                let lhs = Double(previous.pixels[previousIndex + column])
                let rhs = Double(current.pixels[currentIndex + column])
                totalDifference += abs(lhs - rhs)
            }
        }

        let sampleCount = Double(rowCount * width)
        return sampleCount > 0 ? totalDifference / (sampleCount * 255.0) : .greatestFiniteMagnitude
    }
}

private struct Match {
    let cropStart: Int
    let score: Double
}

private struct ReducedImage {
    let width: Int
    let height: Int
    let pixels: [UInt8]
}

private struct PixelImage {
    let width: Int
    let height: Int
    let bytesPerRow: Int
    let pixels: [UInt8]

    init?(cgImage: CGImage) {
        width = cgImage.width
        height = cgImage.height
        bytesPerRow = width * 4

        var buffer = [UInt8](repeating: 0, count: height * bytesPerRow)
        guard
            let colorSpace = cgImage.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: &buffer,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else {
            return nil
        }

        // Flip into a top-to-bottom buffer so overlap math matches on-screen order.
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        pixels = buffer
    }

    func reduced(sampleWidth: Int) -> ReducedImage {
        let resolvedSampleWidth = max(8, min(sampleWidth, width))
        var reducedPixels = [UInt8]()
        reducedPixels.reserveCapacity(height * resolvedSampleWidth)

        for row in 0..<height {
            for column in 0..<resolvedSampleWidth {
                let sourceX = min(width - 1, Int((Double(column) / Double(resolvedSampleWidth - 1)) * Double(width - 1)))
                let offset = row * bytesPerRow + sourceX * 4
                let red = Double(pixels[offset])
                let green = Double(pixels[offset + 1])
                let blue = Double(pixels[offset + 2])
                let luma = UInt8(min(max((0.2126 * red) + (0.7152 * green) + (0.0722 * blue), 0), 255))
                reducedPixels.append(luma)
            }
        }

        return ReducedImage(width: resolvedSampleWidth, height: height, pixels: reducedPixels)
    }

    func appendRows(startingAt startRow: Int, into buffer: inout [UInt8]) {
        let clampedStart = min(max(startRow, 0), height)
        let startIndex = clampedStart * bytesPerRow
        buffer.append(contentsOf: pixels[startIndex...])
    }

    static func makeCGImage(width: Int, height: Int, pixels: [UInt8]) -> CGImage? {
        let bytesPerRow = width * 4
        let data: CFData? = pixels.withUnsafeBufferPointer { buffer -> CFData? in
            guard let baseAddress = buffer.baseAddress else { return nil }
            return CFDataCreate(nil, baseAddress, buffer.count)
        }

        guard
            let data,
            let provider = CGDataProvider(data: data),
            let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)
        else {
            return nil
        }

        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    }
}
