import AppKit
import SwiftUI

@MainActor
final class MenuBarController: NSObject {
    private let appController: AppController
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()

    init(appController: AppController) {
        self.appController = appController
        super.init()
        configureStatusItem()
        configurePopover()
    }

    func closePopover() {
        popover.performClose(nil)
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }

        let image = NSImage(systemSymbolName: "viewfinder.circle", accessibilityDescription: "Clipforge")
        image?.isTemplate = true

        button.image = image
        button.toolTip = "Clipforge"
        button.action = #selector(togglePopover)
        button.target = self
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 390, height: 640)
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView()
                .environmentObject(appController)
                .environmentObject(UpdaterController.shared)
        )
    }

    @objc
    private func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            closePopover()
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
