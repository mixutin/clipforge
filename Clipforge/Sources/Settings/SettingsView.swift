import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appController: AppController
    @ObservedObject private var settings = SettingsStore.shared

    var body: some View {
        Form {
            Section("Server") {
                TextField("https://uploads.example.com", text: settings.binding(for: \.serverURL))
                    .textFieldStyle(.roundedBorder)

                SecureField("Bearer token", text: settings.binding(for: \.apiToken))
                    .textFieldStyle(.roundedBorder)

                Text("Use HTTPS for remote deployments. `http://127.0.0.1:8000` works well for local development. The API token is now stored in your macOS Keychain.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Section("Capture & Upload") {
                Toggle("Copy returned link to the clipboard automatically", isOn: settings.binding(for: \.autoCopyLinkEnabled))
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
            }

            Section("Local Storage") {
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
            }

            Section("Permissions") {
                Text("Clipforge needs Screen Recording permission to capture with ScreenCaptureKit. macOS shows that prompt the first time you capture.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                Button("Open Screen Recording Settings") {
                    PermissionManager.openScreenCaptureSettings()
                }
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
