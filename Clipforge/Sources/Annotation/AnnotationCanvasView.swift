import AppKit
import Combine
import SwiftUI

struct AnnotationCanvasView: NSViewRepresentable {
    @ObservedObject var viewModel: AnnotationEditorViewModel

    func makeNSView(context: Context) -> AnnotationCanvasNSView {
        let view = AnnotationCanvasNSView()
        view.viewModel = viewModel
        return view
    }

    func updateNSView(_ nsView: AnnotationCanvasNSView, context: Context) {
        nsView.viewModel = viewModel
    }
}

@MainActor
final class AnnotationCanvasNSView: NSView {
    var viewModel: AnnotationEditorViewModel? {
        didSet {
            observation = viewModel?.objectWillChange.sink { [weak self] _ in
                self?.needsDisplay = true
            }
            needsDisplay = true
        }
    }

    private var observation: AnyCancellable?
    private var isDrawing = false

    override var isFlipped: Bool {
        true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor.windowBackgroundColor.setFill()
        dirtyRect.fill()

        guard let viewModel else { return }

        let imageRect = fittedImageRect(for: viewModel.image.size, in: bounds.insetBy(dx: 10, dy: 10))
        viewModel.image.draw(in: imageRect)

        let borderPath = NSBezierPath(roundedRect: imageRect, xRadius: 14, yRadius: 14)
        NSColor.separatorColor.withAlphaComponent(0.8).setStroke()
        borderPath.lineWidth = 1
        borderPath.stroke()

        AnnotationRenderer.draw(viewModel.annotations, in: imageRect)

        if let draftAnnotation = viewModel.draftAnnotation {
            AnnotationRenderer.draw([draftAnnotation], in: imageRect)
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard let viewModel else { return }

        let location = convert(event.locationInWindow, from: nil)
        guard let normalizedPoint = normalizedPoint(from: location) else { return }

        isDrawing = true
        viewModel.beginAnnotation(at: normalizedPoint)
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDrawing, let viewModel else { return }
        let location = convert(event.locationInWindow, from: nil)
        viewModel.updateAnnotation(at: clampedNormalizedPoint(from: location))
    }

    override func mouseUp(with event: NSEvent) {
        guard isDrawing, let viewModel else { return }
        let location = convert(event.locationInWindow, from: nil)
        viewModel.updateAnnotation(at: clampedNormalizedPoint(from: location))
        viewModel.commitDraft()
        isDrawing = false
    }

    private func normalizedPoint(from location: CGPoint) -> NormalizedPoint? {
        let imageRect = fittedImageRect(for: viewModel?.image.size ?? .zero, in: bounds.insetBy(dx: 10, dy: 10))
        guard imageRect.contains(location), imageRect.width > 0, imageRect.height > 0 else {
            return nil
        }

        return NormalizedPoint(
            x: (location.x - imageRect.minX) / imageRect.width,
            y: (location.y - imageRect.minY) / imageRect.height
        )
    }

    private func clampedNormalizedPoint(from location: CGPoint) -> NormalizedPoint {
        let imageRect = fittedImageRect(for: viewModel?.image.size ?? .zero, in: bounds.insetBy(dx: 10, dy: 10))
        guard imageRect.width > 0, imageRect.height > 0 else {
            return NormalizedPoint(x: 0, y: 0)
        }

        let clampedX = min(max(location.x, imageRect.minX), imageRect.maxX)
        let clampedY = min(max(location.y, imageRect.minY), imageRect.maxY)

        return NormalizedPoint(
            x: (clampedX - imageRect.minX) / imageRect.width,
            y: (clampedY - imageRect.minY) / imageRect.height
        )
    }

    private func fittedImageRect(for imageSize: NSSize, in bounds: CGRect) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0, bounds.width > 0, bounds.height > 0 else {
            return .zero
        }

        let widthRatio = bounds.width / imageSize.width
        let heightRatio = bounds.height / imageSize.height
        let scale = min(widthRatio, heightRatio)
        let fittedSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)

        return CGRect(
            x: bounds.midX - (fittedSize.width / 2),
            y: bounds.midY - (fittedSize.height / 2),
            width: fittedSize.width,
            height: fittedSize.height
        )
    }
}
