import Foundation

struct UploadResponse: Decodable, Sendable {
    let url: String
}

struct UploadClient: Sendable {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func upload(asset: CapturedAsset, settings: AppSettings) async throws -> URL {
        guard let baseURL = URL(string: settings.serverURL), baseURL.scheme != nil, baseURL.host != nil else {
            throw ClipforgeError.invalidServerURL
        }

        guard settings.apiToken.isEmpty == false else {
            throw ClipforgeError.missingAPIToken
        }

        let uploadURL = baseURL.appendingPathComponent("upload")
        let boundary = "Clipforge-\(UUID().uuidString)"

        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("Bearer \(settings.apiToken)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = MultipartFormDataBuilder(boundary: boundary).build(
            fileField: "file",
            filename: asset.filename,
            mimeType: asset.mimeType,
            data: asset.data
        )

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw ClipforgeError.badServerResponse
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                throw mapHTTPStatus(code: httpResponse.statusCode, payload: data)
            }

            return try decodeUploadURL(from: data)
        } catch let error as ClipforgeError {
            throw error
        } catch let error as URLError {
            throw mapNetworkError(error)
        } catch {
            throw ClipforgeError.generic(error.localizedDescription)
        }
    }

    private func decodeUploadURL(from data: Data) throws -> URL {
        guard
            let uploadResponse = try? JSONDecoder().decode(UploadResponse.self, from: data),
            let url = URL(string: uploadResponse.url)
        else {
            throw ClipforgeError.badServerResponse
        }

        return url
    }

    private func mapNetworkError(_ error: URLError) -> ClipforgeError {
        switch error.code {
        case .timedOut, .cannotConnectToHost, .cannotFindHost, .notConnectedToInternet, .networkConnectionLost:
            return .serverUnreachable
        default:
            return .generic(error.localizedDescription)
        }
    }

    private func mapHTTPStatus(code: Int, payload: Data) -> ClipforgeError {
        switch code {
        case 401:
            return .uploadUnauthorized
        case 413:
            return .uploadTooLarge
        case 408, 425, 429, 500, 502, 503, 504:
            return .temporaryUploadFailure(
                serverMessage(from: payload) ?? "The Clipforge Server is temporarily unavailable."
            )
        default:
            return .serverError(serverMessage(from: payload) ?? "Clipforge Server returned HTTP \(code).")
        }
    }

    private func serverMessage(from data: Data) -> String? {
        if
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let detail = json["detail"] as? String
        {
            return detail
        }

        let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return text?.isEmpty == false ? text : nil
    }
}
