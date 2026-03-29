import AppKit
import SwiftUI

@MainActor
final class UploadHistoryController: NSWindowController, NSWindowDelegate {
    init(appController: AppController) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Upload History"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.center()
        window.setContentSize(NSSize(width: 760, height: 560))

        super.init(window: window)

        window.delegate = self
        window.contentViewController = NSHostingController(
            rootView: UploadHistoryView()
                .environmentObject(appController)
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        guard let window else { return }

        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
    }
}
