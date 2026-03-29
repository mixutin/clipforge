import Foundation

struct AppSettings: Sendable {
    enum CaptureDestinationMode: String, CaseIterable, Codable, Identifiable {
        case automatic
        case serverUpload
        case clipboardOnly

        var id: Self { self }

        var title: String {
            switch self {
            case .automatic:
                return "Automatic"
            case .serverUpload:
                return "Server Upload"
            case .clipboardOnly:
                return "Clipboard Only"
            }
        }

        var helpText: String {
            switch self {
            case .automatic:
                return "Upload when the server is configured. Otherwise copy the captured image directly to the clipboard."
            case .serverUpload:
                return "Always upload to the configured Clipforge Server."
            case .clipboardOnly:
                return "Skip the server and copy the captured image directly to the clipboard."
            }
        }
    }

    enum FilenameMode: String, CaseIterable, Codable, Identifiable {
        case randomHex
        case timestamp

        var id: Self { self }

        var title: String {
            switch self {
            case .randomHex:
                return "Random Hex"
            case .timestamp:
                return "Timestamp"
            }
        }
    }

    var serverURL: String
    var apiToken: String
    var autoCopyLinkEnabled: Bool
    var saveLocalScreenshotEnabled: Bool
    var revealSavedFileAfterUploadEnabled: Bool
    var localSaveFolder: String
    var captureDestinationMode: CaptureDestinationMode
    var filenameMode: FilenameMode

    static var defaultLocalSaveFolder: String {
        let pictures = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first
        return pictures?
            .appendingPathComponent("Clipforge", isDirectory: true)
            .path(percentEncoded: false) ?? NSString(string: "~/Pictures/Clipforge").expandingTildeInPath
    }

    static let `default` = AppSettings(
        serverURL: "http://127.0.0.1:8000",
        apiToken: "",
        autoCopyLinkEnabled: true,
        saveLocalScreenshotEnabled: false,
        revealSavedFileAfterUploadEnabled: false,
        localSaveFolder: AppSettings.defaultLocalSaveFolder,
        captureDestinationMode: .automatic,
        filenameMode: .randomHex
    )
}
