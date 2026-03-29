import AppKit
import CoreGraphics

enum PermissionManager {
    static func hasScreenCaptureAccess() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    static func requestScreenCaptureAccess() async -> Bool {
        await MainActor.run {
            CGRequestScreenCaptureAccess()
        }
    }

    static func ensureScreenCaptureAccess() async throws {
        if hasScreenCaptureAccess() {
            return
        }

        let granted = await requestScreenCaptureAccess()
        guard granted else {
            throw ClipforgeError.screenCapturePermissionDenied
        }
    }

    static func openScreenCaptureSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else {
            return
        }

        NSWorkspace.shared.open(url)
    }
}
