import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var permissionOnboardingController: PermissionOnboardingController?
    private var uploadHistoryController: UploadHistoryController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let controller = AppController.shared
        let menuBarController = MenuBarController(appController: controller)
        let permissionOnboardingController = PermissionOnboardingController()
        let uploadHistoryController = UploadHistoryController(appController: controller)

        self.menuBarController = menuBarController
        self.permissionOnboardingController = permissionOnboardingController
        self.uploadHistoryController = uploadHistoryController
        controller.menuBarController = menuBarController
        controller.permissionOnboardingController = permissionOnboardingController
        controller.uploadHistoryController = uploadHistoryController
        controller.configure()
        permissionOnboardingController.showIfNeeded()
    }
}
