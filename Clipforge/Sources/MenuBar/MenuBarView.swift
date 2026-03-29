import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var appController: AppController
    @EnvironmentObject private var updaterController: UpdaterController

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            VStack(spacing: 10) {
                actionButton(
                    title: "Capture Area",
                    subtitle: "Select a region and upload it immediately",
                    icon: "selection.pin.in.out",
                    isProminent: true
                ) {
                    appController.captureArea()
                }

                actionButton(
                    title: "Capture Full Screen",
                    subtitle: "Capture the display under your cursor",
                    icon: "macwindow.on.rectangle"
                ) {
                    appController.captureFullScreen()
                }

                actionButton(
                    title: "Capture Active Window",
                    subtitle: "Capture the frontmost app window without selecting a region",
                    icon: "macwindow"
                ) {
                    appController.captureActiveWindow()
                }

                actionButton(
                    title: "Upload Clipboard Image",
                    subtitle: "Send the current clipboard image without recapturing",
                    icon: "doc.on.clipboard"
                ) {
                    appController.uploadClipboardImage()
                }
            }

            if appController.isBusy {
                ProgressView(appController.statusMessage)
                    .controlSize(.small)
            }

            Divider()

            RecentUploadsList(
                items: appController.recentUploads,
                onCopy: appController.copyUploadLink,
                onOpen: appController.openUpload
            )

            Divider()

            HStack {
                Button("Settings") {
                    appController.openSettings()
                }

                Button("Check for Updates…") {
                    updaterController.checkForUpdates()
                }
                .disabled(!updaterController.canCheckForUpdates)

                Spacer()

                Text(appController.serverSummary)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(width: 380)
        .background(.regularMaterial)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Clipforge")
                .font(.system(size: 18, weight: .semibold))

            Text("Fast native screenshot uploads for your own server")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func actionButton(
        title: String,
        subtitle: String,
        icon: String,
        isProminent: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))

                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)
            }
            .padding(12)
            .background(backgroundStyle(isProminent: isProminent))
        }
        .buttonStyle(.plain)
        .disabled(appController.isBusy)
    }

    @ViewBuilder
    private func backgroundStyle(isProminent: Bool) -> some View {
        if isProminent {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.accentColor.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.accentColor.opacity(0.25), lineWidth: 1)
                )
        } else {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        }
    }
}
