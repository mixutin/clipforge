import AppKit
import CoreGraphics
import ScreenCaptureKit

extension SCShareableContent: @unchecked @retroactive Sendable {}
extension SCWindow: @unchecked @retroactive Sendable {}

@MainActor
final class CaptureService {
    private let selectionOverlayController = SelectionOverlayController()

    func activeDisplayName() -> String? {
        activeScreen()?.localizedName
    }

    func activeWindowDisplayName() -> String? {
        do {
            let windowInfo = try frontmostWindowInfo()
            let midpoint = CGPoint(x: windowInfo.bounds.midX, y: windowInfo.bounds.midY)
            return NSScreen.screens.first(where: { $0.frame.contains(midpoint) })?.localizedName
        } catch {
            return activeDisplayName()
        }
    }

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

    func captureActiveWindow() async throws -> CGImage {
        try await PermissionManager.ensureScreenCaptureAccess()
        let window = try await activeWindow()
        return try await capture(window: window)
    }

    private func capture(rect: CGRect) async throws -> CGImage {
        try await withCheckedThrowingContinuation { continuation in
            SCScreenshotManager.captureImage(in: rect) { image, error in
                if let error {
                    continuation.resume(throwing: ClipforgeError.generic(error.localizedDescription))
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

    private func capture(window: SCWindow) async throws -> CGImage {
        let contentFilter = SCContentFilter(desktopIndependentWindow: window)
        let contentRect = contentFilter.contentRect
        let pixelScale = max(CGFloat(contentFilter.pointPixelScale), 1)

        let configuration = SCStreamConfiguration()
        configuration.width = Int(contentRect.width * pixelScale)
        configuration.height = Int(contentRect.height * pixelScale)
        configuration.showsCursor = false
        configuration.scalesToFit = true

        return try await withCheckedThrowingContinuation { continuation in
            SCScreenshotManager.captureImage(contentFilter: contentFilter, configuration: configuration) { image, error in
                if let error {
                    continuation.resume(throwing: ClipforgeError.generic(error.localizedDescription))
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

    private func activeWindow() async throws -> SCWindow {
        let windowInfo = try frontmostWindowInfo()
        let content = try await shareableContent()

        guard let window = content.windows.first(where: { $0.windowID == windowInfo.id }) else {
            throw ClipforgeError.activeWindowUnavailable
        }

        return window
    }

    private struct FrontmostWindowInfo {
        let id: CGWindowID
        let bounds: CGRect
    }

    private func frontmostWindowInfo() throws -> FrontmostWindowInfo {
        guard let frontmostApplication = NSWorkspace.shared.frontmostApplication else {
            throw ClipforgeError.activeWindowUnavailable
        }

        let ownProcessID = ProcessInfo.processInfo.processIdentifier
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            throw ClipforgeError.activeWindowUnavailable
        }

        for info in windowList {
            guard
                let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t,
                ownerPID == frontmostApplication.processIdentifier,
                ownerPID != ownProcessID
            else {
                continue
            }

            let layer = info[kCGWindowLayer as String] as? Int ?? 0
            let alpha = info[kCGWindowAlpha as String] as? Double ?? 1

            guard layer == 0, alpha > 0 else { continue }

            if
                let bounds = info[kCGWindowBounds as String] as? NSDictionary,
                let rect = CGRect(dictionaryRepresentation: bounds),
                rect.width >= 32,
                rect.height >= 32
            {
                if let windowNumber = info[kCGWindowNumber as String] as? NSNumber {
                    return FrontmostWindowInfo(
                        id: CGWindowID(windowNumber.uint32Value),
                        bounds: rect
                    )
                }
            }
        }

        throw ClipforgeError.activeWindowUnavailable
    }

    private func shareableContent() async throws -> SCShareableContent {
        try await withCheckedThrowingContinuation { continuation in
            SCShareableContent.getExcludingDesktopWindows(true, onScreenWindowsOnly: true) { content, error in
                if let error {
                    continuation.resume(throwing: ClipforgeError.generic(error.localizedDescription))
                    return
                }

                guard let content else {
                    continuation.resume(throwing: ClipforgeError.activeWindowUnavailable)
                    return
                }

                continuation.resume(returning: content)
            }
        }
    }
}
