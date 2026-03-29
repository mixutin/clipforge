import Foundation

enum ClipforgeError: LocalizedError, Sendable {
    case invalidServerURL
    case missingAPIToken
    case screenCapturePermissionDenied
    case selectionCancelled
    case activeWindowUnavailable
    case clipboardDoesNotContainImage
    case droppedItemNotSupported
    case uploadUnauthorized
    case uploadTooLarge
    case serverUnreachable
    case temporaryUploadFailure(String)
    case badServerResponse
    case failedToEncodeImage
    case failedToSaveLocalCopy(String)
    case screenshotUnavailable
    case serverError(String)
    case generic(String)

    var errorDescription: String? {
        switch self {
        case .invalidServerURL:
            return "Enter a valid Clipforge Server URL in Settings."
        case .missingAPIToken:
            return "Enter your Clipforge Server API token in Settings."
        case .screenCapturePermissionDenied:
            return "Clipforge needs Screen Recording permission before it can capture screenshots."
        case .selectionCancelled:
            return "Capture cancelled."
        case .activeWindowUnavailable:
            return "Clipforge could not find a capturable active window."
        case .clipboardDoesNotContainImage:
            return "The clipboard does not currently contain an image."
        case .droppedItemNotSupported:
            return "Drop a PNG, JPG, WEBP, or an image from another app."
        case .uploadUnauthorized:
            return "The Clipforge Server rejected the API token."
        case .uploadTooLarge:
            return "The image is larger than the server allows."
        case .serverUnreachable:
            return "Clipforge could not reach the configured server."
        case .temporaryUploadFailure(let message):
            return message
        case .badServerResponse:
            return "The server returned an unexpected response."
        case .failedToEncodeImage:
            return "Clipforge could not prepare the image for upload."
        case .failedToSaveLocalCopy(let path):
            return "Clipforge could not save the local copy to \(path)."
        case .screenshotUnavailable:
            return "Clipforge could not create a screenshot."
        case .serverError(let message):
            return message
        case .generic(let message):
            return message
        }
    }

    var isRetryableUploadFailure: Bool {
        switch self {
        case .serverUnreachable, .temporaryUploadFailure:
            return true
        default:
            return false
        }
    }
}
