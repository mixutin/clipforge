import AppKit
import Carbon.HIToolbox

@MainActor
final class SelectionOverlayController: NSObject {
    private var windows: [SelectionOverlayWindow] = []
    private var continuation: CheckedContinuation<CGRect?, Never>?

    func beginSelection() async -> CGRect? {
        guard continuation == nil else { return nil }

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            presentOverlay()
        }
    }

    private func presentOverlay() {
        NSApp.activate(ignoringOtherApps: true)
        NSCursor.crosshair.push()

        windows = NSScreen.screens.map { screen in
            let window = SelectionOverlayWindow(screen: screen) { [weak self] selection in
                self?.finish(selection: selection)
            }
            window.makeKeyAndOrderFront(nil)
            return window
        }
    }

    private func finish(selection: CGRect?) {
        guard let continuation else { return }
        self.continuation = nil

        windows.forEach { window in
            window.orderOut(nil)
            window.close()
        }
        windows.removeAll()
        NSCursor.pop()

        continuation.resume(returning: selection)
    }
}

private final class SelectionOverlayWindow: NSWindow {
    init(screen: NSScreen, onComplete: @escaping (CGRect?) -> Void) {
        let contentRect = screen.frame
        let overlayView = SelectionOverlayView(
            frame: CGRect(origin: .zero, size: contentRect.size),
            screenFrame: contentRect,
            onComplete: onComplete
        )

        super.init(contentRect: contentRect, styleMask: .borderless, backing: .buffered, defer: false)

        setFrame(contentRect, display: false)
        level = .screenSaver
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        ignoresMouseEvents = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        contentView = overlayView
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private final class SelectionOverlayView: NSView {
    private let screenFrame: CGRect
    private let onComplete: (CGRect?) -> Void

    private var dragStart: CGPoint?
    private var currentPoint: CGPoint?

    init(frame frameRect: NSRect, screenFrame: CGRect, onComplete: @escaping (CGRect?) -> Void) {
        self.screenFrame = screenFrame
        self.onComplete = onComplete
        super.init(frame: frameRect)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func mouseDown(with event: NSEvent) {
        let point = clampedPoint(for: event.locationInWindow)
        dragStart = point
        currentPoint = point
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        currentPoint = clampedPoint(for: event.locationInWindow)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        currentPoint = clampedPoint(for: event.locationInWindow)
        needsDisplay = true

        guard let rect = selectionRect?.standardized, rect.width >= 4, rect.height >= 4 else {
            onComplete(nil)
            return
        }

        let globalRect = rect.offsetBy(dx: screenFrame.minX, dy: screenFrame.minY)
        onComplete(globalRect)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == UInt16(kVK_Escape) {
            onComplete(nil)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        context.setFillColor(NSColor.black.withAlphaComponent(0.34).cgColor)
        context.fill(bounds)

        if let rect = selectionRect?.integral {
            context.saveGState()
            context.setBlendMode(.clear)
            context.fill(rect)
            context.restoreGState()

            context.setStrokeColor(NSColor.white.withAlphaComponent(0.95).cgColor)
            context.setLineWidth(2)
            context.stroke(rect.insetBy(dx: 1, dy: 1))

            drawSizeBadge(for: rect)
        }
    }

    private var selectionRect: CGRect? {
        guard let dragStart, let currentPoint else { return nil }
        return CGRect(
            x: min(dragStart.x, currentPoint.x),
            y: min(dragStart.y, currentPoint.y),
            width: abs(currentPoint.x - dragStart.x),
            height: abs(currentPoint.y - dragStart.y)
        )
    }

    private func drawSizeBadge(for rect: CGRect) {
        let label = "\(Int(rect.width)) × \(Int(rect.height))"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let attributedString = NSAttributedString(string: label, attributes: attributes)
        let textSize = attributedString.size()
        let badgeRect = CGRect(
            x: rect.minX,
            y: min(rect.maxY + 8, bounds.maxY - textSize.height - 10),
            width: textSize.width + 14,
            height: textSize.height + 8
        )

        NSColor.black.withAlphaComponent(0.65).setFill()
        NSBezierPath(roundedRect: badgeRect, xRadius: 8, yRadius: 8).fill()
        attributedString.draw(
            at: CGPoint(x: badgeRect.minX + 7, y: badgeRect.minY + 4)
        )
    }

    private func clampedPoint(for point: CGPoint) -> CGPoint {
        CGPoint(
            x: min(max(point.x, bounds.minX), bounds.maxX),
            y: min(max(point.y, bounds.minY), bounds.maxY)
        )
    }
}
