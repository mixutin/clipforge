import Foundation

struct ServerProfile: Codable, Equatable, Hashable, Identifiable, Sendable {
    var id: String
    var name: String
    var serverURL: String

    init(
        id: String = UUID().uuidString,
        name: String = ServerProfile.defaultName,
        serverURL: String = AppSettings.default.serverURL
    ) {
        self.id = id
        self.name = name
        self.serverURL = serverURL
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedServerURL: String {
        serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var displayName: String {
        trimmedName.isEmpty ? "Unnamed Server" : trimmedName
    }

    static let defaultName = "Default Server"
}

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
        case dateTimeDisplay
        case customTemplate

        var id: Self { self }

        var title: String {
            switch self {
            case .randomHex:
                return "Random Hex"
            case .timestamp:
                return "Timestamp"
            case .dateTimeDisplay:
                return "Date + Display"
            case .customTemplate:
                return "Custom Template"
            }
        }

        var helpText: String {
            switch self {
            case .randomHex:
                return "Keep filenames short and random, like `clipforge-a1b2c3d4e5f6`."
            case .timestamp:
                return "Use a timestamp-based name like `clipforge-20260329-173045`."
            case .dateTimeDisplay:
                return "Combine date, time, display name, and a random suffix for a more readable filename."
            case .customTemplate:
                return "Build your own filename template with placeholders like `{date}` and `{display_name}`."
            }
        }
    }

    enum ImageFormatMode: String, CaseIterable, Codable, Identifiable {
        case automatic
        case png
        case jpeg

        var id: Self { self }

        var title: String {
            switch self {
            case .automatic:
                return "Automatic"
            case .png:
                return "PNG"
            case .jpeg:
                return "JPEG"
            }
        }

        var helpText: String {
            switch self {
            case .automatic:
                return "Use PNG when transparency is present. Otherwise use JPEG for smaller uploads."
            case .png:
                return "Always keep screenshots lossless as PNG. Best for sharp UI, text, and transparency."
            case .jpeg:
                return "Always encode as JPEG for smaller files. Transparent regions are flattened onto white."
            }
        }
    }

    enum UploadCopyFormat: String, CaseIterable, Codable, Identifiable {
        case url
        case markdownImage
        case htmlImageTag
        case slackMrkdwn
        case discordEmbedLink

        var id: Self { self }

        var title: String {
            switch self {
            case .url:
                return "URL"
            case .markdownImage:
                return "Markdown Image"
            case .htmlImageTag:
                return "HTML Image Tag"
            case .slackMrkdwn:
                return "Slack Mrkdwn"
            case .discordEmbedLink:
                return "Discord Embed Link"
            }
        }

        var helpText: String {
            switch self {
            case .url:
                return "Copy the plain uploaded URL."
            case .markdownImage:
                return "Copy a Markdown image snippet using the direct media URL when available."
            case .htmlImageTag:
                return "Copy an HTML image tag using the direct media URL when available."
            case .slackMrkdwn:
                return "Copy a Slack mrkdwn link like `<url|label>` for quick pasting into Slack."
            case .discordEmbedLink:
                return "Copy the Clipforge share URL when available so Discord can build a richer embed."
            }
        }

        var copyToastTitle: String {
            switch self {
            case .url:
                return "Link copied"
            case .markdownImage:
                return "Markdown image copied"
            case .htmlImageTag:
                return "HTML image copied"
            case .slackMrkdwn:
                return "Slack share copied"
            case .discordEmbedLink:
                return "Discord link copied"
            }
        }

        var copyActionTitle: String {
            switch self {
            case .url:
                return "Copy Link"
            case .markdownImage:
                return "Copy Markdown"
            case .htmlImageTag:
                return "Copy HTML"
            case .slackMrkdwn:
                return "Copy Slack"
            case .discordEmbedLink:
                return "Copy Discord Link"
            }
        }

        var quickActionTitle: String {
            switch self {
            case .url:
                return "Copy Link"
            case .markdownImage:
                return "Copy Markdown"
            case .htmlImageTag:
                return "Copy HTML"
            case .slackMrkdwn:
                return "Copy Slack"
            case .discordEmbedLink:
                return "Copy Discord"
            }
        }

        var contentDescription: String {
            switch self {
            case .url:
                return "uploaded URL"
            case .markdownImage:
                return "Markdown image link"
            case .htmlImageTag:
                return "HTML image tag"
            case .slackMrkdwn:
                return "Slack mrkdwn share link"
            case .discordEmbedLink:
                return "Discord embed link"
            }
        }

        var copiedToClipboardMessage: String {
            switch self {
            case .url:
                return "Link copied to your clipboard."
            case .markdownImage:
                return "Markdown image link copied to your clipboard."
            case .htmlImageTag:
                return "HTML image tag copied to your clipboard."
            case .slackMrkdwn:
                return "Slack mrkdwn link copied to your clipboard."
            case .discordEmbedLink:
                return "Discord-ready link copied to your clipboard."
            }
        }

        var copiedAndRevealedMessage: String {
            switch self {
            case .url:
                return "Link copied and local file revealed in Finder."
            case .markdownImage:
                return "Markdown image link copied and local file revealed in Finder."
            case .htmlImageTag:
                return "HTML image tag copied and local file revealed in Finder."
            case .slackMrkdwn:
                return "Slack mrkdwn link copied and local file revealed in Finder."
            case .discordEmbedLink:
                return "Discord-ready link copied and local file revealed in Finder."
            }
        }

        func formattedString(
            remoteURL: String,
            directURL: String? = nil,
            shareURL: String? = nil,
            localFilename: String
        ) -> String {
            let altText = Self.altText(from: localFilename)
            let directMediaURL = directURL ?? remoteURL
            let shareableURL = shareURL ?? remoteURL

            switch self {
            case .url:
                return remoteURL
            case .markdownImage:
                let escapedAltText = Self.escapeMarkdownAltText(altText)
                return "![\(escapedAltText)](<\(directMediaURL)>)"
            case .htmlImageTag:
                let escapedURL = Self.escapeHTMLAttribute(directMediaURL)
                let escapedAltText = Self.escapeHTMLAttribute(altText)
                return "<img src=\"\(escapedURL)\" alt=\"\(escapedAltText)\" />"
            case .slackMrkdwn:
                let escapedURL = Self.escapeSlackValue(shareableURL)
                let escapedAltText = Self.escapeSlackValue(altText)
                return "<\(escapedURL)|\(escapedAltText)>"
            case .discordEmbedLink:
                return shareableURL
            }
        }

        private static func altText(from localFilename: String) -> String {
            let basename = (localFilename as NSString).deletingPathExtension
            return basename.isEmpty ? "Clipforge image" : basename
        }

        private static func escapeMarkdownAltText(_ value: String) -> String {
            var escaped = value.replacingOccurrences(of: "\\", with: "\\\\")

            for character in ["[", "]", "(", ")"] {
                escaped = escaped.replacingOccurrences(of: character, with: "\\\(character)")
            }

            return escaped
        }

        private static func escapeHTMLAttribute(_ value: String) -> String {
            value
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "\"", with: "&quot;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
        }

        private static func escapeSlackValue(_ value: String) -> String {
            value
                .replacingOccurrences(of: "|", with: " ")
                .replacingOccurrences(of: ">", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    enum PostUploadAction: String, CaseIterable, Codable, Identifiable {
        case copyLink
        case openLink
        case revealLocalFile
        case doNothing

        var id: Self { self }

        func title(for copyFormat: UploadCopyFormat) -> String {
            switch self {
            case .copyLink:
                return copyFormat.quickActionTitle
            case .openLink:
                return "Open Link"
            case .revealLocalFile:
                return "Reveal Local File"
            case .doNothing:
                return "Do Nothing"
            }
        }

        func helpText(for copyFormat: UploadCopyFormat) -> String {
            switch self {
            case .copyLink:
                return "Show a quick action in the success popup to copy the \(copyFormat.contentDescription)."
            case .openLink:
                return "Show a quick action in the success popup to open the uploaded URL."
            case .revealLocalFile:
                return "Show a quick action in the success popup to reveal the saved local file in Finder."
            case .doNothing:
                return "Do not show a quick action in the success popup after upload."
            }
        }
    }

    var serverURL: String
    var apiToken: String
    var autoCopyLinkEnabled: Bool
    var annotationReviewEnabled: Bool
    var imageFormatMode: ImageFormatMode
    var jpegCompressionQuality: Double
    var saveLocalScreenshotEnabled: Bool
    var revealSavedFileAfterUploadEnabled: Bool
    var localSaveFolder: String
    var captureDestinationMode: CaptureDestinationMode
    var filenameMode: FilenameMode
    var filenameTemplate: String
    var uploadCopyFormat: UploadCopyFormat
    var postUploadAction: PostUploadAction

    static var defaultLocalSaveFolder: String {
        let pictures = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first
        return pictures?
            .appendingPathComponent("Clipforge", isDirectory: true)
            .path(percentEncoded: false) ?? NSString(string: "~/Pictures/Clipforge").expandingTildeInPath
    }

    static let defaultCustomFilenameTemplate = "clipforge-{date}-{time}-{display_name}-{random_suffix}"

    static let `default` = AppSettings(
        serverURL: "",
        apiToken: "",
        autoCopyLinkEnabled: true,
        annotationReviewEnabled: false,
        imageFormatMode: .automatic,
        jpegCompressionQuality: 0.92,
        saveLocalScreenshotEnabled: false,
        revealSavedFileAfterUploadEnabled: false,
        localSaveFolder: AppSettings.defaultLocalSaveFolder,
        captureDestinationMode: .automatic,
        filenameMode: .randomHex,
        filenameTemplate: AppSettings.defaultCustomFilenameTemplate,
        uploadCopyFormat: .url,
        postUploadAction: .openLink
    )
}
