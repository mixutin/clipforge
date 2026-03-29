import AppKit
import Foundation
import os

@MainActor
final class AppController: ObservableObject {
    enum ActionSource {
        case menuBar
        case hotkey
    }

    static let shared = AppController()

    @Published private(set) var recentUploads: [UploadRecord]
    @Published private(set) var isBusy = false
    @Published private(set) var statusMessage = ""

    let settingsStore = SettingsStore.shared
    private let historyStore = HistoryStore.shared
    private let captureService = CaptureService()
    private let uploadClient = UploadClient()
    private let clipboardService = ClipboardService.shared
    private let toastPresenter = ToastPresenter.shared
    private let logger = Logger(subsystem: "com.clipforge.app", category: "App")
    private var hotkeyObserver: NSObjectProtocol?

    weak var menuBarController: MenuBarController?

    private init() {
        recentUploads = historyStore.load()
    }

    var serverSummary: String {
        guard
            let url = URL(string: settingsStore.serverURL),
            let host = url.host
        else {
            return "Server not configured"
        }

        return host
    }

    func configure() {
        registerHotkey()

        hotkeyObserver = NotificationCenter.default.addObserver(
            forName: .clipforgeHotkeyDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.registerHotkey()
            }
        }
    }

    func captureActiveWindow(source: ActionSource = .menuBar) {
        Task {
            await runCaptureActiveWindow(source: source)
        }
    }

    private func registerHotkey() {
        HotkeyService.shared.register(settingsStore.hotkey) { [weak self] in
            Task { @MainActor in
                self?.captureArea(source: .hotkey)
            }
        }
    }

    func captureArea(source: ActionSource = .menuBar) {
        Task {
            await runCaptureArea(source: source)
        }
    }

    func captureFullScreen(source: ActionSource = .menuBar) {
        Task {
            await runCaptureFullScreen(source: source)
        }
    }

    func uploadClipboardImage(source: ActionSource = .menuBar) {
        Task {
            await runClipboardUpload(source: source)
        }
    }

    func openSettings() {
        menuBarController?.closePopover()
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    func copyUploadLink(_ record: UploadRecord) {
        clipboardService.copyString(record.remoteURL)
        toastPresenter.showSuccess(title: "Link copied", message: record.remoteURL)
    }

    func openUpload(_ record: UploadRecord) {
        guard let url = URL(string: record.remoteURL) else { return }
        NSWorkspace.shared.open(url)
    }

    private func runCaptureArea(source: ActionSource) async {
        guard await beginWork(status: "Selecting area…", source: source) else { return }
        defer { endWork() }

        do {
            let cgImage = try await captureService.captureArea()
            let asset = try CapturedAsset.from(
                cgImage: cgImage,
                filenameBase: FilenameGenerator.makeBase(using: settingsStore.filenameMode)
            )
            try await upload(asset: asset)
        } catch {
            if case ClipforgeError.selectionCancelled = error {
                return
            }

            present(error: error, title: "Capture failed")
        }
    }

    private func runCaptureFullScreen(source: ActionSource) async {
        guard await beginWork(status: "Capturing display…", source: source) else { return }
        defer { endWork() }

        do {
            let cgImage = try await captureService.captureFullScreen()
            let asset = try CapturedAsset.from(
                cgImage: cgImage,
                filenameBase: FilenameGenerator.makeBase(using: settingsStore.filenameMode)
            )
            try await upload(asset: asset)
        } catch {
            present(error: error, title: "Capture failed")
        }
    }

    private func runCaptureActiveWindow(source: ActionSource) async {
        guard await beginWork(status: "Capturing active window…", source: source) else { return }
        defer { endWork() }

        do {
            let cgImage = try await captureService.captureActiveWindow()
            let asset = try CapturedAsset.from(
                cgImage: cgImage,
                filenameBase: FilenameGenerator.makeBase(using: settingsStore.filenameMode)
            )
            try await upload(asset: asset)
        } catch {
            present(error: error, title: "Capture failed")
        }
    }

    private func runClipboardUpload(source: ActionSource) async {
        guard await beginWork(status: "Preparing clipboard image…", source: source) else { return }
        defer { endWork() }

        do {
            let asset = try clipboardService.loadImageAsset(
                filenameBase: FilenameGenerator.makeBase(using: settingsStore.filenameMode)
            )
            try await upload(asset: asset)
        } catch {
            present(error: error, title: "Clipboard upload failed")
        }
    }

    private func beginWork(status: String, source: ActionSource) async -> Bool {
        guard isBusy == false else { return false }

        isBusy = true
        statusMessage = status

        if source == .menuBar {
            menuBarController?.closePopover()
            try? await Task.sleep(for: .milliseconds(150))
        }

        return true
    }

    private func upload(asset: CapturedAsset) async throws {
        statusMessage = "Uploading…"

        let settings = try settingsStore.validate()
        let localSaveWarning = try saveLocalCopyIfNeeded(asset: asset, settings: settings)
        let remoteURL = try await uploadClient.upload(asset: asset, settings: settings)

        if settings.autoCopyLinkEnabled {
            clipboardService.copyString(remoteURL.absoluteString)
        }

        let record = UploadRecord(
            localFilename: asset.filename,
            remoteURL: remoteURL.absoluteString,
            thumbnailPNGData: ThumbnailGenerator.makePNGData(from: asset.data),
            createdAt: Date()
        )
        recentUploads = historyStore.add(record)

        let message: String
        if let localSaveWarning {
            message = localSaveWarning
        } else if settings.autoCopyLinkEnabled {
            message = "Uploaded successfully. Link copied to your clipboard."
        } else {
            message = "Uploaded successfully."
        }

        toastPresenter.showSuccess(
            title: "Clipforge uploaded your image",
            message: message,
            actionTitle: "Open"
        ) {
            NSWorkspace.shared.open(remoteURL)
        }
    }

    private func saveLocalCopyIfNeeded(asset: CapturedAsset, settings: AppSettings) throws -> String? {
        guard settings.saveLocalScreenshotEnabled else { return nil }

        let directoryURL = URL(fileURLWithPath: settings.localSaveFolder, isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let destinationURL = directoryURL.appendingPathComponent(asset.filename)
            try asset.data.write(to: destinationURL, options: .atomic)
            return nil
        } catch {
            logger.error("Failed to save local screenshot: \(error.localizedDescription)")
            return "Uploaded successfully, but the local copy could not be saved."
        }
    }

    private func endWork() {
        isBusy = false
        statusMessage = ""
    }

    private func present(error: Error, title: String) {
        let clipforgeError = error as? ClipforgeError ?? .generic(error.localizedDescription)

        switch clipforgeError {
        case .selectionCancelled:
            break
        case .screenCapturePermissionDenied:
            toastPresenter.showError(
                title: title,
                message: clipforgeError.localizedDescription,
                actionTitle: "Open Settings"
            ) {
                PermissionManager.openScreenCaptureSettings()
            }
        case .invalidServerURL, .missingAPIToken:
            toastPresenter.showError(
                title: title,
                message: clipforgeError.localizedDescription,
                actionTitle: "Settings"
            ) { [weak self] in
                self?.openSettings()
            }
        default:
            toastPresenter.showError(title: title, message: clipforgeError.localizedDescription)
        }
    }
}
