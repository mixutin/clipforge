import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let controller = AppController.shared
        let menuBarController = MenuBarController(appController: controller)

        self.menuBarController = menuBarController
        controller.menuBarController = menuBarController
        controller.configure()
    }
}
