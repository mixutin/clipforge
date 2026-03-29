import SwiftUI

struct PermissionOnboardingView: View {
    @ObservedObject private var settings = SettingsStore.shared

    let onDismiss: () -> Void

    @State private var hasScreenCaptureAccess = PermissionManager.hasScreenCaptureAccess()
    @State private var isRequestingAccess = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header
            statusCard
            steps
            footer
        }
        .padding(28)
        .frame(width: 560)
        .background(
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color.accentColor.opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .onAppear(perform: refreshPermissionStatus)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshPermissionStatus()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Welcome to Clipforge")
                .font(.system(size: 28, weight: .bold))

            Text("Clipforge lives in your menu bar and captures screenshots with a global hotkey. To capture the screen, macOS needs Screen Recording permission.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
    }

    private var statusCard: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: hasScreenCaptureAccess ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(hasScreenCaptureAccess ? Color.green : Color.orange)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                Text(hasScreenCaptureAccess ? "Screen Recording is ready" : "Screen Recording still needs approval")
                    .font(.system(size: 15, weight: .semibold))

                Text(statusMessage)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var steps: some View {
        VStack(alignment: .leading, spacing: 14) {
            onboardingStep(
                icon: "1.circle.fill",
                title: "Grant Screen Recording access",
                body: "Click Request Permission for the first prompt, or open macOS settings directly if you already denied it."
            )

            onboardingStep(
                icon: "2.circle.fill",
                title: "Enable Clipforge in System Settings",
                body: "Look for Clipforge in Screen Recording and turn it on. macOS may ask you to quit and reopen the app after enabling it."
            )

            onboardingStep(
                icon: "3.circle.fill",
                title: "Capture from the menu bar or hotkey",
                body: "Once permission is granted, use \(settings.hotkey.displayString) or the menu bar actions to capture and upload. Clipboard image uploads still work without screen capture permission."
            )
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                if hasScreenCaptureAccess == false {
                    Button(isRequestingAccess ? "Requesting…" : "Request Permission") {
                        requestPermission()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRequestingAccess)

                    Button("Open Screen Recording Settings") {
                        PermissionManager.openScreenCaptureSettings()
                    }
                    .buttonStyle(.bordered)

                    Button("Check Again") {
                        refreshPermissionStatus()
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button("Start Using Clipforge") {
                        onDismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            HStack {
                Text("You can reopen this guide later from Settings.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                Spacer()

                Button(hasScreenCaptureAccess ? "Close" : "Continue to Menu Bar") {
                    onDismiss()
                }
                .buttonStyle(.link)
            }
        }
    }

    private var statusMessage: String {
        if hasScreenCaptureAccess {
            return "Clipforge can capture area, full-screen, and active-window screenshots."
        }

        return "Screenshot capture will not work until Clipforge is allowed in macOS Screen Recording settings."
    }

    private func onboardingStep(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))

                Text(body)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func requestPermission() {
        guard isRequestingAccess == false else { return }

        isRequestingAccess = true
        Task {
            _ = await PermissionManager.requestScreenCaptureAccess()
            await MainActor.run {
                isRequestingAccess = false
                refreshPermissionStatus()
            }
        }
    }

    private func refreshPermissionStatus() {
        hasScreenCaptureAccess = PermissionManager.hasScreenCaptureAccess()
    }
}
