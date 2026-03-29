import AppKit
import Foundation

@MainActor
final class AnnotationEditorViewModel: ObservableObject {
    let asset: CapturedAsset
    let image: NSImage
    private let settings: AppSettings

    @Published private(set) var annotations: [ImageAnnotation] = []
    @Published private(set) var draftAnnotation: ImageAnnotation?
    @Published var selectedTool: AnnotationTool = .arrow
    @Published var selectedColor: AnnotationColor = .red

    init(asset: CapturedAsset, settings: AppSettings) throws {
        guard let image = NSImage(data: asset.data) else {
            throw ClipforgeError.failedToEncodeImage
        }

        self.asset = asset
        self.image = image
        self.settings = settings
    }

    var canUndo: Bool {
        draftAnnotation != nil || annotations.isEmpty == false
    }

    var hasAnnotations: Bool {
        draftAnnotation != nil || annotations.isEmpty == false
    }

    func beginAnnotation(at point: NormalizedPoint) {
        switch selectedTool {
        case .pen:
            draftAnnotation = ImageAnnotation(tool: selectedTool, color: selectedColor, points: [point])
        case .arrow, .rectangle, .highlight:
            draftAnnotation = ImageAnnotation(tool: selectedTool, color: selectedColor, points: [point, point])
        }
    }

    func updateAnnotation(at point: NormalizedPoint) {
        guard var draftAnnotation else { return }

        switch draftAnnotation.tool {
        case .pen:
            if let lastPoint = draftAnnotation.points.last,
               hypot(lastPoint.x - point.x, lastPoint.y - point.y) < 0.002 {
                return
            }

            draftAnnotation.points.append(point)
        case .arrow, .rectangle, .highlight:
            draftAnnotation.points[draftAnnotation.points.count - 1] = point
        }

        self.draftAnnotation = draftAnnotation
    }

    func commitDraft() {
        guard let draftAnnotation else { return }
        self.draftAnnotation = nil

        guard draftAnnotation.isMeaningful else { return }
        annotations.append(draftAnnotation)
    }

    func undo() {
        if draftAnnotation != nil {
            draftAnnotation = nil
            return
        }

        guard annotations.isEmpty == false else { return }
        annotations.removeLast()
    }

    func clear() {
        draftAnnotation = nil
        annotations.removeAll()
    }

    func renderAsset() throws -> CapturedAsset {
        guard hasAnnotations else { return asset }

        let outputSize = pixelSize(for: image)
        let outputImage = NSImage(size: outputSize)

        outputImage.lockFocusFlipped(true)
        defer { outputImage.unlockFocus() }

        let renderRect = CGRect(origin: .zero, size: outputSize)
        image.draw(in: renderRect)
        AnnotationRenderer.draw(annotations, in: renderRect)

        return try CapturedAsset.from(nsImage: outputImage, filenameBase: asset.filenameBase, settings: settings)
    }

    private func pixelSize(for image: NSImage) -> NSSize {
        if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            return NSSize(width: cgImage.width, height: cgImage.height)
        }

        return image.size
    }
}
