import Foundation

struct AppSettings: Sendable {
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
    var localSaveFolder: String
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
        localSaveFolder: AppSettings.defaultLocalSaveFolder,
        filenameMode: .randomHex
    )
}
