import AppKit
import SwiftUI

@MainActor
final class AnnotationEditorController: NSObject, NSWindowDelegate {
    private var windowController: NSWindowController?
    private var continuation: CheckedContinuation<CapturedAsset?, Error>?
    private var isResolving = false

    func edit(asset: CapturedAsset, settings: AppSettings) async throws -> CapturedAsset? {
        guard continuation == nil else { return asset }

        let viewModel = try AnnotationEditorViewModel(asset: asset, settings: settings)

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            isResolving = false

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 980, height: 720),
                styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "Annotate Screenshot"
            window.center()
            window.delegate = self
            window.isReleasedWhenClosed = false
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.setContentSize(NSSize(width: 980, height: 720))

            let hostingController = NSHostingController(
                rootView: AnnotationEditorView(
                    viewModel: viewModel,
                    onCancel: { [weak self] in
                        self?.resolve(with: .success(nil))
                    },
                    onContinue: { [weak self] in
                        guard let self else { return }

                        do {
                            let renderedAsset = try viewModel.renderAsset()
                            self.resolve(with: .success(renderedAsset))
                        } catch {
                            self.resolve(with: .failure(error))
                        }
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

    private func resolve(with result: Result<CapturedAsset?, Error>, closeWindow: Bool = true) {
        guard isResolving == false else { return }

        isResolving = true
        let continuation = self.continuation
        self.continuation = nil
        let controller = windowController
        windowController = nil

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
