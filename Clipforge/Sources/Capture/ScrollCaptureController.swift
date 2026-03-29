import AppKit
import SwiftUI

@MainActor
final class ScrollCaptureController: NSObject, NSWindowDelegate {
    private var windowController: NSWindowController?
    private var continuation: CheckedContinuation<CapturedAsset?, Error>?
    private var isResolving = false
    private var capturedFrames: [CGImage] = []
    private let state = ScrollCaptureSessionState()

    func capture(
        using captureService: CaptureService,
        settings: AppSettings,
        filenameBase: String
    ) async throws -> CapturedAsset? {
        guard continuation == nil else { return nil }

        let firstFrame = try await captureService.captureActiveWindow()
        capturedFrames = [firstFrame]
        state.frameCount = 1
        state.isCapturing = false

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            isResolving = false

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 260),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Scroll Capture"
            window.center()
            window.delegate = self
            window.isReleasedWhenClosed = false

            let hostingController = NSHostingController(
                rootView: ScrollCaptureView(
                    state: state,
                    onCaptureNext: { [weak self] in
                        guard let self else { return }
                        Task { @MainActor in
                            await self.captureNextFrame(using: captureService)
                        }
                    },
                    onUndoLast: { [weak self] in
                        self?.undoLastFrame()
                    },
                    onFinish: { [weak self] in
                        guard let self else { return }

                        do {
                            let asset = try self.renderCapturedAsset(settings: settings, filenameBase: filenameBase)
                            self.resolve(with: .success(asset))
                        } catch {
                            self.resolve(with: .failure(error))
                        }
                    },
                    onCancel: { [weak self] in
                        self?.resolve(with: .success(nil))
                    }
                )
            )

            window.contentViewController = hostingController

            let controller = NSWindowController(window: window)
            windowController = controller
            controller.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func windowWillClose(_ notification: Notification) {
        guard isResolving == false else { return }
        resolve(with: .success(nil), closeWindow: false)
    }

    private func captureNextFrame(using captureService: CaptureService) async {
        guard state.isCapturing == false else { return }
        state.isCapturing = true
        windowController?.window?.orderOut(nil)

        defer {
            state.isCapturing = false
            windowController?.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
        }

        do {
            try await Task.sleep(for: .milliseconds(180))
            let frame = try await captureService.captureActiveWindow()
            capturedFrames.append(frame)
            state.frameCount = capturedFrames.count
        } catch {
            ToastPresenter.shared.showError(
                title: "Scroll capture",
                message: "Clipforge could not capture the next section. Adjust the window and try again."
            )
        }
    }

    private func undoLastFrame() {
        guard capturedFrames.count > 1 else { return }
        capturedFrames.removeLast()
        state.frameCount = capturedFrames.count
    }

    private func renderCapturedAsset(settings: AppSettings, filenameBase: String) throws -> CapturedAsset {
        guard let stitchedImage = ScrollImageStitcher.stitch(images: capturedFrames) else {
            throw ClipforgeError.scrollCaptureFailed
        }

        return try CapturedAsset.from(
            cgImage: stitchedImage,
            filenameBase: filenameBase,
            settings: settings
        )
    }

    private func resolve(with result: Result<CapturedAsset?, Error>, closeWindow: Bool = true) {
        guard isResolving == false else { return }

        isResolving = true
        let continuation = self.continuation
        self.continuation = nil
        let controller = windowController
        windowController = nil
        capturedFrames = []

        if closeWindow {
            controller?.close()
        }

        switch result {
        case .success(let asset):
            continuation?.resume(returning: asset)
        case .failure(let error):
            continuation?.resume(throwing: error)
        }
    }
}

@MainActor
final class ScrollCaptureSessionState: ObservableObject {
    @Published var frameCount = 1
    @Published var isCapturing = false
}
