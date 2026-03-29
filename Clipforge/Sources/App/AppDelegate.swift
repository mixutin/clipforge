import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var permissionOnboardingController: PermissionOnboardingController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let controller = AppController.shared
        let menuBarController = MenuBarController(appController: controller)
        let permissionOnboardingController = PermissionOnboardingController()

        self.menuBarController = menuBarController
        self.permissionOnboardingController = permissionOnboardingController
        controller.menuBarController = menuBarController
        controller.permissionOnboardingController = permissionOnboardingController
        controller.configure()
        permissionOnboardingController.showIfNeeded()
    }
}
