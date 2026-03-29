import SwiftUI

@main
struct ClipforgeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appController = AppController.shared
    @StateObject private var updaterController = UpdaterController.shared

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(appController)
                .environmentObject(updaterController)
        }
        .defaultSize(width: 560, height: 440)
    }
}
