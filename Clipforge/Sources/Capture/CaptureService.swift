import AppKit
import ScreenCaptureKit

@MainActor
final class CaptureService {
    private let selectionOverlayController = SelectionOverlayController()

    func captureArea() async throws -> CGImage {
        try await PermissionManager.ensureScreenCaptureAccess()

        guard let selection = await selectionOverlayController.beginSelection() else {
            throw ClipforgeError.selectionCancelled
        }

        return try await capture(rect: selection)
    }

    func captureFullScreen() async throws -> CGImage {
        try await PermissionManager.ensureScreenCaptureAccess()

        guard let screen = activeScreen() else {
            throw ClipforgeError.screenshotUnavailable
        }

        return try await capture(rect: screen.frame)
    }

    private func capture(rect: CGRect) async throws -> CGImage {
        try await withCheckedThrowingContinuation { continuation in
            SCScreenshotManager.captureImage(in: rect) { image, error in
                if let error {
                    continuation.resume(throwing: ClipforgeError.serverError(error.localizedDescription))
                    return
                }

                guard let image else {
                    continuation.resume(throwing: ClipforgeError.screenshotUnavailable)
                    return
                }

                continuation.resume(returning: image)
            }
        }
    }

    private func activeScreen() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) ?? NSScreen.main
    }
}
