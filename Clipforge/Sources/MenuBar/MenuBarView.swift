import SwiftUI
import UniformTypeIdentifiers

struct MenuBarView: View {
    @EnvironmentObject private var appController: AppController
    @EnvironmentObject private var updaterController: UpdaterController
    @ObservedObject private var settings = SettingsStore.shared
    @State private var isDropTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            VStack(spacing: 10) {
                actionButton(
                    title: "Capture Area",
                    subtitle: captureAreaSubtitle,
                    icon: "selection.pin.in.out",
                    isProminent: true
                ) {
                    appController.captureArea()
                }

                actionButton(
                    title: "Capture Full Screen",
                    subtitle: captureFullscreenSubtitle,
                    icon: "macwindow.on.rectangle"
                ) {
                    appController.captureFullScreen()
                }

                actionButton(
                    title: "Capture Active Window",
                    subtitle: captureWindowSubtitle,
                    icon: "macwindow"
                ) {
                    appController.captureActiveWindow()
                }

                actionButton(
                    title: "Upload Clipboard Image",
                    subtitle: "Send the current clipboard image to your configured server",
                    icon: "doc.on.clipboard"
                ) {
                    appController.uploadClipboardImage()
                }
                .disabled(appController.isBusy || !appController.canUploadClipboardImage)
            }

            if appController.isBusy {
                ProgressView(appController.statusMessage)
                    .controlSize(.small)
            }

            dropZone

            Divider()

            RecentUploadsList(
                items: appController.recentUploads,
                onCopy: appController.copyUploadContent,
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
        .onDrop(of: dropTypeIdentifiers, isTargeted: $isDropTargeted) { providers in
            guard appController.isBusy == false else {
                return false
            }

            appController.uploadDroppedItems(providers)
            return true
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Clipforge")
                .font(.system(size: 18, weight: .semibold))

            Text(headerSubtitle)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    private var headerSubtitle: String {
        switch settings.captureDestinationMode {
        case .clipboardOnly:
            return "Fast native screenshots copied straight to your clipboard"
        case .serverUpload:
            return "Fast native screenshot uploads for your own server"
        case .automatic:
            return settings.hasReadyUploadConfiguration
                ? "Fast native screenshot uploads for your own server"
                : "Fast native screenshots copied to your clipboard until a server is set up"
        }
    }

    private var captureAreaSubtitle: String {
        switch settings.captureDestinationMode {
        case .clipboardOnly:
            return "Select a region and copy it to the clipboard"
        case .serverUpload:
            return "Select a region and upload it immediately"
        case .automatic:
            return settings.hasReadyUploadConfiguration
                ? "Select a region and upload it immediately"
                : "Select a region and copy it to the clipboard"
        }
    }

    private var captureFullscreenSubtitle: String {
        switch settings.captureDestinationMode {
        case .clipboardOnly:
            return "Capture the display under your cursor and copy it to the clipboard"
        case .serverUpload:
            return "Capture the display under your cursor and upload it"
        case .automatic:
            return settings.hasReadyUploadConfiguration
                ? "Capture the display under your cursor and upload it"
                : "Capture the display under your cursor and copy it to the clipboard"
        }
    }

    private var captureWindowSubtitle: String {
        switch settings.captureDestinationMode {
        case .clipboardOnly:
            return "Capture the frontmost app window and copy it to the clipboard"
        case .serverUpload:
            return "Capture the frontmost app window and upload it"
        case .automatic:
            return settings.hasReadyUploadConfiguration
                ? "Capture the frontmost app window and upload it"
                : "Capture the frontmost app window and copy it to the clipboard"
        }
    }

    private var dropZone: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: isDropTargeted ? "tray.and.arrow.down.fill" : "square.and.arrow.up.on.square")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(dropZoneAccentColor)

                VStack(alignment: .leading, spacing: 3) {
                    Text(isDropTargeted ? "Release to upload your image" : "Drop an image here to upload")
                        .font(.system(size: 13, weight: .semibold))

                    Text(dropZoneSubtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(dropZoneBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            dropZoneAccentColor.opacity(isDropTargeted ? 0.55 : 0.22),
                            style: StrokeStyle(lineWidth: 1.2, dash: [6, 5])
                        )
                )
        )
        .opacity(appController.isBusy ? 0.6 : 1)
        .animation(.easeInOut(duration: 0.16), value: isDropTargeted)
    }

    private var dropZoneSubtitle: String {
        if settings.hasReadyUploadConfiguration {
            return "Finder image files and dragged images upload through your configured Clipforge Server."
        }

        return "Set up a server in Settings first. Dropping now will guide you there."
    }

    private var dropZoneAccentColor: Color {
        if settings.hasReadyUploadConfiguration {
            return isDropTargeted ? .accentColor : .secondary
        }

        return isDropTargeted ? .orange : .secondary
    }

    private var dropZoneBackgroundColor: Color {
        if isDropTargeted {
            return Color.accentColor.opacity(0.12)
        }

        return Color.primary.opacity(0.04)
    }

    private var dropTypeIdentifiers: [String] {
        [
            UTType.fileURL.identifier,
            UTType.image.identifier
        ]
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
