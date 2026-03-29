import AppKit
import Vision

enum OCRService {
    static func recognizeText(in asset: CapturedAsset) async -> String? {
        guard asset.isImage else { return nil }
        return await recognizeText(in: asset.data)
    }

    static func recognizeText(in imageData: Data) async -> String? {
        guard
            let image = NSImage(data: imageData),
            let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else {
            return nil
        }

        return await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.minimumTextHeight = 0.012

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                return nil
            }

            let lines = (request.results ?? [])
                .compactMap { $0.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { $0.isEmpty == false }

            guard lines.isEmpty == false else { return nil }
            return lines.joined(separator: "\n")
        }.value
    }
}
