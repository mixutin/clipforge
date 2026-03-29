import Foundation

enum ClipforgeError: LocalizedError, Sendable {
    case invalidServerURL
    case missingAPIToken
    case screenCapturePermissionDenied
    case selectionCancelled
    case clipboardDoesNotContainImage
    case uploadUnauthorized
    case uploadTooLarge
    case serverUnreachable
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
        case .clipboardDoesNotContainImage:
            return "The clipboard does not currently contain an image."
        case .uploadUnauthorized:
            return "The Clipforge Server rejected the API token."
        case .uploadTooLarge:
            return "The image is larger than the server allows."
        case .serverUnreachable:
            return "Clipforge could not reach the configured server."
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
}
