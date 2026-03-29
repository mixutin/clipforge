import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appController: AppController
    @EnvironmentObject private var updaterController: UpdaterController
    @ObservedObject private var settings = SettingsStore.shared

    var body: some View {
        Form {
            Section("Server") {
                TextField("https://uploads.example.com", text: settings.binding(for: \.serverURL))
                    .textFieldStyle(.roundedBorder)

                SecureField("Bearer token", text: settings.binding(for: \.apiToken))
                    .textFieldStyle(.roundedBorder)

                Text("Use HTTPS for remote deployments. `http://127.0.0.1:8000` works well for local development. The API token is stored in your macOS Keychain. If you leave the server blank and use Automatic mode, Clipforge falls back to clipboard-only capture.")
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

                Toggle("Copy uploaded URL to the clipboard automatically", isOn: settings.binding(for: \.autoCopyLinkEnabled))
                    .disabled(settings.captureDestinationMode == .clipboardOnly)

                Toggle("Save a local screenshot copy after capture", isOn: settings.binding(for: \.saveLocalScreenshotEnabled))

                Picker("Filename format", selection: settings.binding(for: \.filenameMode)) {
                    ForEach(AppSettings.FilenameMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Global hotkey")
                    HotkeyRecorderView(hotkey: settings.binding(for: \.hotkey))
                }

                if settings.captureDestinationMode == .clipboardOnly {
                    Text("Clipboard Only mode copies the captured image itself, not a URL.")
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

                Button("Open Screen Recording Settings") {
                    PermissionManager.openScreenCaptureSettings()
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
