import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appController: AppController
    @EnvironmentObject private var updaterController: UpdaterController
    @ObservedObject private var settings = SettingsStore.shared

    var body: some View {
        Form {
            Section("Server") {
                Picker("Active profile", selection: settings.binding(for: \.activeServerProfileID)) {
                    ForEach(settings.serverProfiles) { profile in
                        Text(profile.displayName).tag(profile.id)
                    }
                }

                HStack {
                    Button("New Profile") {
                        settings.createServerProfile()
                    }

                    Button("Delete Profile") {
                        settings.deleteActiveServerProfile()
                    }
                    .disabled(!settings.canDeleteServerProfile)

                    Spacer()

                    Text("\(settings.serverProfiles.count) profile\(settings.serverProfiles.count == 1 ? "" : "s")")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                TextField("Profile name", text: settings.binding(for: \.activeServerProfileName))
                    .textFieldStyle(.roundedBorder)

                TextField("https://uploads.example.com", text: settings.binding(for: \.serverURL))
                    .textFieldStyle(.roundedBorder)

                SecureField("Bearer token", text: settings.binding(for: \.apiToken))
                    .textFieldStyle(.roundedBorder)

                Text("Each profile keeps its own server URL and API token locally. Tokens are stored in your macOS Keychain. Use HTTPS for remote deployments. `http://127.0.0.1:8000` works well for local development. If you leave the active server blank and use Automatic mode, Clipforge falls back to clipboard-only capture.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Section("Capture & Upload") {
                Picker("After capture", selection: settings.binding(for: \.captureDestinationMode)) {
                    ForEach(AppSettings.CaptureDestinationMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }

                Text(settings.captureDestinationMode.helpText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                Toggle("Copy uploaded content to the clipboard automatically", isOn: settings.binding(for: \.autoCopyLinkEnabled))
                    .disabled(settings.captureDestinationMode == .clipboardOnly)

                Toggle("Open the annotation editor before delivery", isOn: settings.binding(for: \.annotationReviewEnabled))

                Text("When enabled, Clipforge opens a quick review window after capture, clipboard upload, or drag-and-drop so you can add arrows, boxes, highlights, or pen marks before the image is copied or uploaded.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                Picker("Image format", selection: settings.binding(for: \.imageFormatMode)) {
                    ForEach(AppSettings.ImageFormatMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }

                Text(settings.imageFormatMode.helpText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("JPEG quality")
                        Spacer()
                        Text("\(Int((settings.jpegCompressionQuality * 100).rounded()))%")
                            .foregroundStyle(.secondary)
                    }

                    Slider(value: settings.binding(for: \.jpegCompressionQuality), in: 0.5...1.0, step: 0.05)
                }

                Text("Only applies when JPEG is used, including Automatic mode for screenshots without transparency.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                Picker("Copied upload format", selection: settings.binding(for: \.uploadCopyFormat)) {
                    ForEach(AppSettings.UploadCopyFormat.allCases) { format in
                        Text(format.title).tag(format)
                    }
                }

                Text(settings.uploadCopyFormat.helpText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                Picker("Success popup action", selection: settings.binding(for: \.postUploadAction)) {
                    ForEach(AppSettings.PostUploadAction.allCases) { action in
                        Text(action.title(for: settings.uploadCopyFormat)).tag(action)
                    }
                }

                Text(settings.postUploadAction.helpText(for: settings.uploadCopyFormat))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                if settings.postUploadAction == .revealLocalFile && !settings.saveLocalScreenshotEnabled {
                    Text("Reveal Local File needs local screenshot saving turned on, otherwise the popup will hide that quick action.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Toggle("Save a local screenshot copy after capture", isOn: settings.binding(for: \.saveLocalScreenshotEnabled))

                Picker("Filename style", selection: settings.binding(for: \.filenameMode)) {
                    ForEach(AppSettings.FilenameMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }

                Text(settings.filenameMode.helpText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                if settings.filenameMode == .customTemplate {
                    TextField(
                        "clipforge-{date}-{time}-{display_name}-{random_suffix}",
                        text: settings.binding(for: \.filenameTemplate)
                    )
                    .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Placeholders: `{date}`, `{time}`, `{timestamp}`, `{display_name}`, `{source_name}`, `{random_suffix}`")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    Text("Preview: `\(FilenameGenerator.previewBase(using: settings.currentSettings))`")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Global hotkey")
                    HotkeyRecorderView(hotkey: settings.binding(for: \.hotkey))
                }

                if settings.captureDestinationMode == .clipboardOnly {
                    Text("Clipboard Only mode copies the captured image itself, not a URL. The success popup action above applies to successful server uploads.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Section("Local Storage") {
                Toggle(
                    "Reveal the saved file in Finder after upload",
                    isOn: settings.binding(for: \.revealSavedFileAfterUploadEnabled)
                )
                .disabled(!settings.saveLocalScreenshotEnabled)

                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(settings.localSaveFolder)
                            .font(.system(size: 12))
                            .textSelection(.enabled)

                        Text("Clipforge will create the folder if it does not exist.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Choose…") {
                        chooseFolder()
                    }

                    Button("Reset") {
                        settings.resetLocalFolderToDefault()
                    }
                }

                Text("This only runs after a successful upload when local screenshot saving is enabled.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Section("Permissions") {
                Text("Clipforge needs Screen Recording permission to capture with ScreenCaptureKit. macOS shows that prompt the first time you capture.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                HStack {
                    Button("Open Screen Recording Settings") {
                        PermissionManager.openScreenCaptureSettings()
                    }

                    Button("Open Permission Guide") {
                        appController.openPermissionGuide()
                    }
                }
            }

            Section("Updates") {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(updaterController.versionDescription)
                            .font(.system(size: 12, weight: .medium))

                        Text("Clipforge can check GitHub-hosted releases and install newer versions with Sparkle.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Check for Updates…") {
                        updaterController.checkForUpdates()
                    }
                    .disabled(!updaterController.canCheckForUpdates)
                }

                Toggle(
                    "Automatically check for updates",
                    isOn: Binding(
                        get: { updaterController.automaticallyChecksForUpdates },
                        set: { updaterController.setAutomaticallyChecksForUpdates($0) }
                    )
                )

                Toggle(
                    "Automatically download updates in the background",
                    isOn: Binding(
                        get: { updaterController.automaticallyDownloadsUpdates },
                        set: { updaterController.setAutomaticallyDownloadsUpdates($0) }
                    )
                )
                .disabled(!updaterController.automaticallyChecksForUpdates || !updaterController.allowsAutomaticUpdates)
            }
        }
        .formStyle(.grouped)
        .padding(20)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = URL(fileURLWithPath: settings.localSaveFolder, isDirectory: true)

        if panel.runModal() == .OK, let url = panel.url {
            settings.localSaveFolder = url.path
        }
    }
}
