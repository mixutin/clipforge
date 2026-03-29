import AppKit
import SwiftUI

@MainActor
final class PermissionOnboardingController: NSWindowController, NSWindowDelegate {
    private let settingsStore = SettingsStore.shared

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 470),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Welcome to Clipforge"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)

        window.delegate = self
        window.contentViewController = NSHostingController(
            rootView: PermissionOnboardingView(
                onDismiss: { [weak window] in
                    window?.performClose(nil)
                }
            )
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showIfNeeded() {
        guard settingsStore.shouldPresentPermissionGuideOnLaunch else { return }
        settingsStore.markPermissionGuidePresented()
        show()
    }

    func show() {
        guard let window else { return }

        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window.center()
        window.makeKeyAndOrderFront(nil)
    }
}
