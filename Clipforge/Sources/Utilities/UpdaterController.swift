import Combine
import Foundation
import Sparkle

@MainActor
final class UpdaterController: ObservableObject {
    static let shared = UpdaterController()

    @Published private(set) var canCheckForUpdates: Bool
    @Published private(set) var automaticallyChecksForUpdates: Bool
    @Published private(set) var automaticallyDownloadsUpdates: Bool
    @Published private(set) var allowsAutomaticUpdates: Bool

    let standardController: SPUStandardUpdaterController
    let updater: SPUUpdater

    private var cancellables = Set<AnyCancellable>()

    private init() {
        standardController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        updater = standardController.updater
        canCheckForUpdates = updater.canCheckForUpdates
        automaticallyChecksForUpdates = updater.automaticallyChecksForUpdates
        automaticallyDownloadsUpdates = updater.automaticallyDownloadsUpdates
        allowsAutomaticUpdates = updater.allowsAutomaticUpdates

        updater.publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main)
            .assign(to: &$canCheckForUpdates)

        updater.publisher(for: \.automaticallyChecksForUpdates)
            .receive(on: RunLoop.main)
            .assign(to: &$automaticallyChecksForUpdates)

        updater.publisher(for: \.automaticallyDownloadsUpdates)
            .receive(on: RunLoop.main)
            .assign(to: &$automaticallyDownloadsUpdates)

        updater.publisher(for: \.allowsAutomaticUpdates)
            .receive(on: RunLoop.main)
            .assign(to: &$allowsAutomaticUpdates)
    }

    var versionDescription: String {
        let shortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(shortVersion) (\(buildNumber))"
    }

    func checkForUpdates() {
        standardController.checkForUpdates(nil)
    }

    func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
        updater.automaticallyChecksForUpdates = enabled
    }

    func setAutomaticallyDownloadsUpdates(_ enabled: Bool) {
        updater.automaticallyDownloadsUpdates = enabled
    }
}
