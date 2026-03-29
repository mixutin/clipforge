import AppKit
import Foundation
import os
import UniformTypeIdentifiers

@MainActor
final class AppController: ObservableObject {
    private static let maxUploadAttempts = 3

    enum ActionSource {
        case menuBar
        case hotkey
    }

    private enum DeliveryDestination {
        case upload(AppSettings)
        case clipboard
    }

    private enum LocalSaveStatus: Equatable {
        case notRequested
        case saved(URL)
        case failed

        var savedFileURL: URL? {
            guard case .saved(let url) = self else { return nil }
            return url
        }

        var didFail: Bool {
            if case .failed = self {
                return true
            }

            return false
        }
    }

    private struct SuccessToastAction {
        let title: String
        let handler: () -> Void
    }

    static let shared = AppController()

    @Published private(set) var recentUploads: [UploadRecord]
    @Published private(set) var isBusy = false
    @Published private(set) var statusMessage = ""
    @Published private(set) var uploadProgress: Double?

    let settingsStore = SettingsStore.shared
    private let historyStore = HistoryStore.shared
    private let captureService = CaptureService()
    private let screenRecordingService = ScreenRecordingService()
    private let scrollCaptureController = ScrollCaptureController()
    private let uploadClient = UploadClient()
    private let clipboardService = ClipboardService.shared
    private let toastPresenter = ToastPresenter.shared
    private let annotationEditorController = AnnotationEditorController()
    private let logger = Logger(subsystem: "com.clipforge.app", category: "App")
    private var hotkeyObserver: NSObjectProtocol?

    weak var menuBarController: MenuBarController?
    weak var permissionOnboardingController: PermissionOnboardingController?
    weak var uploadHistoryController: UploadHistoryController?

    private init() {
        recentUploads = historyStore.load()
    }

    var serverSummary: String {
        switch settingsStore.captureDestinationMode {
        case .clipboardOnly:
            return "Clipboard only"
        case .serverUpload:
            switch settingsStore.uploadConfigurationState() {
            case .ready(let settings):
                return hostSummary(for: settings.serverURL, profileName: settingsStore.activeServerProfileDisplayName)
            case .notConfigured:
                return "Server required"
            case .invalid:
                return "Server setup incomplete"
            }
        case .automatic:
            switch settingsStore.uploadConfigurationState() {
            case .ready(let settings):
                return hostSummary(for: settings.serverURL, profileName: settingsStore.activeServerProfileDisplayName)
            case .notConfigured:
                return "Auto: Clipboard"
            case .invalid:
                return "Server setup incomplete"
            }
        }
    }

    var canUploadClipboardImage: Bool {
        settingsStore.hasReadyUploadConfiguration
    }

    var canRecordScreenClip: Bool {
        settingsStore.hasReadyUploadConfiguration
    }

    var uploadProgressPercentText: String? {
        guard let uploadProgress else { return nil }
        return "\(Int((uploadProgress * 100).rounded()))%"
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

    func captureScroll(source: ActionSource = .menuBar) {
        Task {
            await runScrollCapture(source: source)
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

    func recordScreenClip(source: ActionSource = .menuBar) {
        Task {
            await runScreenRecording(source: source)
        }
    }

    func uploadDroppedItems(_ providers: [NSItemProvider], source: ActionSource = .menuBar) {
        Task {
            await runDroppedUpload(providers: providers, source: source)
        }
    }

    func openSettings() {
        menuBarController?.closePopover()
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    func openPermissionGuide() {
        menuBarController?.closePopover()
        permissionOnboardingController?.show()
    }

    func openUploadHistory() {
        menuBarController?.closePopover()
        uploadHistoryController?.show()
    }

    func copyUploadContent(_ record: UploadRecord) {
        let copiedContent = formattedUploadContent(
            remoteURLString: record.remoteURL,
            localFilename: record.localFilename
        )
        let copyFormat = settingsStore.uploadCopyFormat

        clipboardService.copyString(copiedContent)
        toastPresenter.showSuccess(title: copyFormat.copyToastTitle, message: copiedContent)
    }

    func copyRecognizedText(_ record: UploadRecord) {
        guard let recognizedText = record.recognizedText?.trimmingCharacters(in: .whitespacesAndNewlines),
              recognizedText.isEmpty == false
        else {
            return
        }

        clipboardService.copyString(recognizedText)
        toastPresenter.showSuccess(
            title: "Recognized text copied",
            message: recognizedText
        )
    }

    func openUpload(_ record: UploadRecord) {
        guard let url = URL(string: record.remoteURL) else { return }
        NSWorkspace.shared.open(url)
    }

    private func runCaptureArea(source: ActionSource) async {
        guard await beginWork(status: "Selecting area…", source: source, closesPopover: true) else { return }
        defer { endWork() }

        do {
            let currentSettings = settingsStore.currentSettings
            let cgImage = try await captureService.captureArea()
            let asset = try CapturedAsset.from(
                cgImage: cgImage,
                filenameBase: makeFilenameBase(
                    settings: currentSettings,
                    displayName: captureService.activeDisplayName(),
                    sourceName: "screen"
                ),
                settings: currentSettings
            )
            try await deliver(asset: asset)
        } catch {
            if case ClipforgeError.selectionCancelled = error {
                return
            }

            present(error: error, title: "Capture failed")
        }
    }

    private func runCaptureFullScreen(source: ActionSource) async {
        guard await beginWork(status: "Capturing display…", source: source, closesPopover: true) else { return }
        defer { endWork() }

        do {
            let currentSettings = settingsStore.currentSettings
            let cgImage = try await captureService.captureFullScreen()
            let asset = try CapturedAsset.from(
                cgImage: cgImage,
                filenameBase: makeFilenameBase(
                    settings: currentSettings,
                    displayName: captureService.activeDisplayName(),
                    sourceName: "screen"
                ),
                settings: currentSettings
            )
            try await deliver(asset: asset)
        } catch {
            present(error: error, title: "Capture failed")
        }
    }

    private func runScrollCapture(source: ActionSource) async {
        guard await beginWork(status: "Preparing scroll capture…", source: source, closesPopover: true) else { return }
        defer { endWork() }

        do {
            let currentSettings = settingsStore.currentSettings
            let asset = try await scrollCaptureController.capture(
                using: captureService,
                settings: currentSettings,
                filenameBase: makeFilenameBase(
                    settings: currentSettings,
                    displayName: captureService.activeWindowDisplayName(),
                    sourceName: "scroll"
                )
            )

            guard let asset else { return }
            try await deliver(asset: asset)
        } catch {
            present(error: error, title: "Scroll capture failed")
        }
    }

    private func runCaptureActiveWindow(source: ActionSource) async {
        guard await beginWork(status: "Capturing active window…", source: source, closesPopover: true) else { return }
        defer { endWork() }

        do {
            let currentSettings = settingsStore.currentSettings
            let cgImage = try await captureService.captureActiveWindow()
            let asset = try CapturedAsset.from(
                cgImage: cgImage,
                filenameBase: makeFilenameBase(
                    settings: currentSettings,
                    displayName: captureService.activeWindowDisplayName(),
                    sourceName: NSWorkspace.shared.frontmostApplication?.localizedName ?? "window"
                ),
                settings: currentSettings
            )
            try await deliver(asset: asset)
        } catch {
            present(error: error, title: "Capture failed")
        }
    }

    private func runClipboardUpload(source: ActionSource) async {
        guard await beginWork(status: "Preparing pasted image…", source: source, closesPopover: false) else { return }
        defer { endWork() }

        do {
            let currentSettings = settingsStore.currentSettings
            let asset = try clipboardService.loadImageAsset(
                filenameBase: makeFilenameBase(
                    settings: currentSettings,
                    sourceName: "clipboard"
                ),
                settings: currentSettings
            )
            try await deliver(asset: asset, forceUpload: true)
        } catch {
            present(error: error, title: "Paste failed")
        }
    }

    private func runDroppedUpload(providers: [NSItemProvider], source: ActionSource) async {
        guard await beginWork(status: "Preparing dropped image…", source: source, closesPopover: false) else { return }
        defer { endWork() }

        do {
            let currentSettings = settingsStore.currentSettings
            let asset = try await DroppedImageLoader.loadImageAsset(
                from: providers,
                filenameBase: makeFilenameBase(
                    settings: currentSettings,
                    sourceName: "drop"
                ),
                settings: currentSettings
            )
            try await deliver(asset: asset, forceUpload: true)
        } catch {
            present(error: error, title: "Dropped image upload failed")
        }
    }

    private func runScreenRecording(source: ActionSource) async {
        guard await beginWork(status: "Recording screen clip… 8s left", source: source, closesPopover: true) else { return }
        defer { endWork() }

        var countdownTask: Task<Void, Never>?
        defer { countdownTask?.cancel() }

        do {
            _ = try settingsStore.validatedUploadSettings()
            let currentSettings = settingsStore.currentSettings

            countdownTask = Task { @MainActor [weak self] in
                for remaining in stride(from: 7, through: 1, by: -1) {
                    try? await Task.sleep(for: .seconds(1))
                    guard Task.isCancelled == false else { return }
                    self?.statusMessage = "Recording screen clip… \(remaining)s left"
                }
            }

            let asset = try await screenRecordingService.recordShortClip(
                filenameBase: makeFilenameBase(
                    settings: currentSettings,
                    displayName: captureService.activeDisplayName(),
                    sourceName: "screen-clip"
                )
            )
            try await deliver(asset: asset, forceUpload: true)
        } catch {
            present(error: error, title: "Screen clip failed")
        }
    }

    private func beginWork(status: String, source: ActionSource, closesPopover: Bool) async -> Bool {
        guard isBusy == false else { return false }

        isBusy = true
        statusMessage = status
        uploadProgress = nil

        if source == .menuBar && closesPopover {
            menuBarController?.closePopover()
            try? await Task.sleep(for: .milliseconds(150))
        }

        return true
    }

    private func deliver(asset: CapturedAsset, forceUpload: Bool = false) async throws {
        guard let preparedAsset = try await prepareAssetForDelivery(asset) else { return }

        let localSaveStatus = saveLocalCopyIfNeeded(asset: preparedAsset, settings: settingsStore.currentSettings)

        switch try resolveDeliveryDestination(forceUpload: forceUpload) {
        case .upload(let settings):
            await uploadAndFinalize(asset: preparedAsset, settings: settings, localSaveStatus: localSaveStatus)
        case .clipboard:
            statusMessage = "Copying to clipboard…"

            try clipboardService.copyImageAsset(preparedAsset)
            let recognizedText = await recognizedTextIfAvailable(for: preparedAsset)
            let recognizedTextAction = recognizedTextToastAction(for: recognizedText)

            let message: String
            if localSaveStatus.didFail {
                message = "Image copied to your clipboard, but the local copy could not be saved."
            } else {
                message = "Image copied to your clipboard. Paste it into any app."
            }

            toastPresenter.showSuccess(
                title: "Clipforge copied your capture",
                message: message,
                actionTitle: recognizedTextAction?.title,
                action: recognizedTextAction?.handler
            )
        }
    }

    private func prepareAssetForDelivery(_ asset: CapturedAsset) async throws -> CapturedAsset? {
        guard settingsStore.annotationReviewEnabled, asset.isImage else { return asset }

        statusMessage = "Opening annotation editor…"
        menuBarController?.closePopover()
        return try await annotationEditorController.edit(asset: asset, settings: settingsStore.currentSettings)
    }

    private func uploadAndFinalize(
        asset: CapturedAsset,
        settings: AppSettings,
        localSaveStatus: LocalSaveStatus,
        isManualRetry: Bool = false
    ) async {
        do {
            let remoteURL = try await performUploadWithRetry(
                asset: asset,
                settings: settings,
                isManualRetry: isManualRetry
            )
            let recognizedText = await recognizedTextIfAvailable(for: asset)
            let revealedLocalFile = revealLocalFileIfNeeded(localSaveStatus: localSaveStatus, settings: settings)
            let successAction = successToastAction(
                for: remoteURL,
                localFilename: asset.filename,
                localSaveStatus: localSaveStatus,
                settings: settings
            )
            let recognizedTextAction = recognizedTextToastAction(for: recognizedText)

            if settings.autoCopyLinkEnabled {
                clipboardService.copyString(
                    formattedUploadContent(
                        remoteURLString: remoteURL.absoluteString,
                        localFilename: asset.filename,
                        copyFormat: settings.uploadCopyFormat
                    )
                )
            }

            let record = UploadRecord(
                localFilename: asset.filename,
                remoteURL: remoteURL.absoluteString,
                thumbnailPNGData: asset.thumbnailPNGData,
                mediaKind: asset.isVideo ? .video : .image,
                recognizedText: recognizedText,
                createdAt: Date()
            )
            recentUploads = historyStore.add(record)

            let message: String
            if localSaveStatus.didFail {
                message = "Uploaded successfully, but the local copy could not be saved."
            } else if settings.autoCopyLinkEnabled && revealedLocalFile {
                message = "Uploaded successfully. \(settings.uploadCopyFormat.copiedAndRevealedMessage)"
            } else if settings.autoCopyLinkEnabled {
                message = "Uploaded successfully. \(settings.uploadCopyFormat.copiedToClipboardMessage)"
            } else if revealedLocalFile {
                message = "Uploaded successfully. Local file revealed in Finder."
            } else {
                message = "Uploaded successfully."
            }

            toastPresenter.showSuccess(
                title: asset.isVideo ? "Clipforge uploaded your screen clip" : "Clipforge uploaded your image",
                message: message,
                actionTitle: successAction?.title,
                action: successAction?.handler,
                secondaryActionTitle: recognizedTextAction?.title,
                secondaryAction: recognizedTextAction?.handler
            )
        } catch {
            handleUploadFailure(
                error,
                asset: asset,
                settings: settings,
                localSaveStatus: localSaveStatus
            )
        }
    }

    private func performUploadWithRetry(
        asset: CapturedAsset,
        settings: AppSettings,
        isManualRetry: Bool
    ) async throws -> URL {
        uploadProgress = nil

        for attempt in 1...Self.maxUploadAttempts {
            statusMessage = uploadStatusMessage(forAttempt: attempt, isManualRetry: isManualRetry)

            do {
                let uploadedURL = try await uploadClient.upload(
                    asset: asset,
                    settings: settings
                ) { [weak self] fractionCompleted in
                    self?.uploadProgress = fractionCompleted
                }
                uploadProgress = 1
                return uploadedURL
            } catch let error as ClipforgeError {
                guard error.isRetryableUploadFailure, attempt < Self.maxUploadAttempts else {
                    throw error
                }

                uploadProgress = nil
                logger.warning("Temporary upload failure on attempt \(attempt): \(error.localizedDescription)")
                try? await Task.sleep(for: retryDelay(afterAttempt: attempt))
            } catch {
                throw error
            }
        }

        throw ClipforgeError.serverUnreachable
    }

    private func uploadStatusMessage(forAttempt attempt: Int, isManualRetry: Bool) -> String {
        if attempt == 1 {
            return isManualRetry ? "Retrying upload…" : "Uploading…"
        }

        return "Retrying upload (\(attempt) of \(Self.maxUploadAttempts))…"
    }

    private func retryDelay(afterAttempt attempt: Int) -> Duration {
        switch attempt {
        case 1:
            return .seconds(1)
        default:
            return .seconds(2)
        }
    }

    private func makeFilenameBase(
        settings: AppSettings,
        displayName: String? = nil,
        sourceName: String? = nil
    ) -> String {
        FilenameGenerator.makeBase(
            using: settings,
            context: FilenameGenerator.Context(
                now: Date(),
                displayName: displayName,
                sourceName: sourceName
            )
        )
    }

    private func saveLocalCopyIfNeeded(asset: CapturedAsset, settings: AppSettings) -> LocalSaveStatus {
        guard settings.saveLocalScreenshotEnabled else { return .notRequested }

        let directoryURL = URL(fileURLWithPath: settings.localSaveFolder, isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let destinationURL = directoryURL.appendingPathComponent(asset.filename)
            try asset.data.write(to: destinationURL, options: .atomic)
            return .saved(destinationURL)
        } catch {
            logger.error("Failed to save local screenshot: \(error.localizedDescription)")
            return .failed
        }
    }

    private func revealLocalFileIfNeeded(localSaveStatus: LocalSaveStatus, settings: AppSettings) -> Bool {
        guard settings.revealSavedFileAfterUploadEnabled,
              let savedFileURL = localSaveStatus.savedFileURL
        else {
            return false
        }

        NSWorkspace.shared.activateFileViewerSelecting([savedFileURL])
        return true
    }

    private func successToastAction(
        for remoteURL: URL,
        localFilename: String,
        localSaveStatus: LocalSaveStatus,
        settings: AppSettings
    ) -> SuccessToastAction? {
        switch settings.postUploadAction {
        case .copyLink:
            return SuccessToastAction(
                title: settings.autoCopyLinkEnabled ? "Copy Again" : settings.uploadCopyFormat.copyActionTitle,
                handler: { [weak self] in
                    guard let self else { return }
                    let copiedContent = self.formattedUploadContent(
                        remoteURLString: remoteURL.absoluteString,
                        localFilename: localFilename,
                        copyFormat: settings.uploadCopyFormat
                    )
                    self.clipboardService.copyString(copiedContent)
                    self.toastPresenter.showSuccess(
                        title: settings.uploadCopyFormat.copyToastTitle,
                        message: copiedContent
                    )
                }
            )
        case .openLink:
            return SuccessToastAction(
                title: "Open",
                handler: {
                    NSWorkspace.shared.open(remoteURL)
                }
            )
        case .revealLocalFile:
            guard let savedFileURL = localSaveStatus.savedFileURL else {
                return nil
            }

            return SuccessToastAction(
                title: settings.revealSavedFileAfterUploadEnabled ? "Reveal Again" : "Reveal",
                handler: {
                    NSWorkspace.shared.activateFileViewerSelecting([savedFileURL])
                }
            )
        case .doNothing:
            return nil
        }
    }

    private func recognizedTextToastAction(for recognizedText: String?) -> SuccessToastAction? {
        guard let recognizedText = recognizedText?.trimmingCharacters(in: .whitespacesAndNewlines),
              recognizedText.isEmpty == false
        else {
            return nil
        }

        return SuccessToastAction(
            title: "Copy Text",
            handler: { [weak self] in
                self?.clipboardService.copyString(recognizedText)
                self?.toastPresenter.showSuccess(
                    title: "Recognized text copied",
                    message: recognizedText
                )
            }
        )
    }

    private func recognizedTextIfAvailable(for asset: CapturedAsset) async -> String? {
        guard asset.isImage else { return nil }
        statusMessage = "Recognizing text…"
        return await OCRService.recognizeText(in: asset)
    }

    private func formattedUploadContent(
        remoteURLString: String,
        localFilename: String,
        copyFormat: AppSettings.UploadCopyFormat? = nil
    ) -> String {
        let format = copyFormat ?? settingsStore.uploadCopyFormat
        return format.formattedString(remoteURL: remoteURLString, localFilename: localFilename)
    }

    private func handleUploadFailure(
        _ error: Error,
        asset: CapturedAsset,
        settings: AppSettings,
        localSaveStatus: LocalSaveStatus
    ) {
        let clipforgeError = error as? ClipforgeError ?? .generic(error.localizedDescription)
        let message = uploadFailureMessage(for: clipforgeError, localSaveStatus: localSaveStatus)

        if clipforgeError.isRetryableUploadFailure {
            toastPresenter.showError(
                title: "Clipforge could not finish the upload",
                message: message,
                actionTitle: "Retry Upload"
            ) { [weak self] in
                self?.retryUpload(asset: asset, settings: settings, localSaveStatus: localSaveStatus)
            }
            return
        }

        switch clipforgeError {
        case .uploadUnauthorized:
            toastPresenter.showError(
                title: "Upload failed",
                message: message,
                actionTitle: "Settings"
            ) { [weak self] in
                self?.openSettings()
            }
        default:
            toastPresenter.showError(title: "Upload failed", message: message)
        }
    }

    private func retryUpload(
        asset: CapturedAsset,
        settings: AppSettings,
        localSaveStatus: LocalSaveStatus
    ) {
        Task { @MainActor [weak self] in
            guard let self, self.isBusy == false else { return }

            self.isBusy = true
            defer { self.endWork() }

            await self.uploadAndFinalize(
                asset: asset,
                settings: settings,
                localSaveStatus: localSaveStatus,
                isManualRetry: true
            )
        }
    }

    private func endWork() {
        isBusy = false
        statusMessage = ""
        uploadProgress = nil
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
                actionTitle: "Open Guide"
            ) {
                self.openPermissionGuide()
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

    private func uploadFailureMessage(
        for error: ClipforgeError,
        localSaveStatus: LocalSaveStatus
    ) -> String {
        let baseMessage: String

        switch error {
        case .serverUnreachable:
            baseMessage = "Clipforge tried \(Self.maxUploadAttempts) times but could not reach your server. Check that the server is running and reachable, then try again."
        case .temporaryUploadFailure(let message):
            baseMessage = "Clipforge tried \(Self.maxUploadAttempts) times but the server is still temporarily unavailable. \(message)"
        case .uploadUnauthorized:
            baseMessage = "The Clipforge Server rejected the API token. Update it in Settings and try again."
        case .uploadTooLarge:
            baseMessage = "The image is larger than the server allows. Capture a smaller region or increase the server upload limit."
        default:
            baseMessage = error.localizedDescription
        }

        switch localSaveStatus {
        case .saved:
            return "\(baseMessage) The screenshot is still saved locally."
        case .notRequested:
            if error.isRetryableUploadFailure {
                return "\(baseMessage) Retry Upload will resend the same capture without making you create it again."
            }

            return baseMessage
        case .failed:
            return "\(baseMessage) Clipforge also could not save a local fallback copy."
        }
    }

    private func resolveDeliveryDestination(forceUpload: Bool) throws -> DeliveryDestination {
        if forceUpload {
            return .upload(try settingsStore.validatedUploadSettings())
        }

        switch settingsStore.captureDestinationMode {
        case .clipboardOnly:
            return .clipboard
        case .serverUpload:
            return .upload(try settingsStore.validatedUploadSettings())
        case .automatic:
            switch settingsStore.uploadConfigurationState() {
            case .ready(let settings):
                return .upload(settings)
            case .notConfigured:
                return .clipboard
            case .invalid(let error):
                throw error
            }
        }
    }

    private func hostSummary(for serverURL: String, profileName: String) -> String {
        guard let url = URL(string: serverURL), let host = url.host else {
            return "Server not configured"
        }

        guard settingsStore.serverProfiles.count > 1 else {
            return host
        }

        return "\(profileName) · \(host)"
    }
}
