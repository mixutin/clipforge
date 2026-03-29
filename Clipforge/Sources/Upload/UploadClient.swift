import Foundation

struct UploadResponse: Decodable, Sendable {
    let url: String
}

struct UploadClient: Sendable {
    typealias ProgressHandler = @MainActor @Sendable (Double) -> Void

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func upload(
        asset: CapturedAsset,
        settings: AppSettings,
        onProgress: ProgressHandler? = nil
    ) async throws -> URL {
        let (request, body) = try makeUploadRequest(asset: asset, settings: settings)

        if onProgress == nil {
            return try await uploadWithoutProgress(request: request, body: body)
        }

        return try await uploadWithProgress(request: request, body: body, onProgress: onProgress)
    }

    private func makeUploadRequest(asset: CapturedAsset, settings: AppSettings) throws -> (URLRequest, Data) {
        guard let baseURL = URL(string: settings.serverURL), baseURL.scheme != nil, baseURL.host != nil else {
            throw ClipforgeError.invalidServerURL
        }

        guard settings.apiToken.isEmpty == false else {
            throw ClipforgeError.missingAPIToken
        }

        let uploadURL = baseURL.appendingPathComponent("upload")
        let boundary = "Clipforge-\(UUID().uuidString)"
        let body = MultipartFormDataBuilder(boundary: boundary).build(
            fileField: "file",
            filename: asset.filename,
            mimeType: asset.mimeType,
            data: asset.data
        )

        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("Bearer \(settings.apiToken)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        return (request, body)
    }

    private func uploadWithoutProgress(request: URLRequest, body: Data) async throws -> URL {
        var request = request
        request.httpBody = body

        do {
            let (data, response) = try await session.data(for: request)
            return try handleUploadResponse(data: data, response: response)
        } catch let error as ClipforgeError {
            throw error
        } catch let error as URLError {
            throw mapNetworkError(error)
        } catch {
            throw ClipforgeError.generic(error.localizedDescription)
        }
    }

    private func uploadWithProgress(
        request: URLRequest,
        body: Data,
        onProgress: ProgressHandler?
    ) async throws -> URL {
        let delegate = UploadTaskDelegate(onProgress: onProgress)
        let progressSession = URLSession(
            configuration: session.configuration,
            delegate: delegate,
            delegateQueue: nil
        )

        defer {
            progressSession.finishTasksAndInvalidate()
        }

        do {
            let (data, response) = try await delegate.upload(with: request, body: body, session: progressSession)
            return try handleUploadResponse(data: data, response: response)
        } catch let error as ClipforgeError {
            throw error
        } catch let error as URLError {
            throw mapNetworkError(error)
        } catch {
            throw ClipforgeError.generic(error.localizedDescription)
        }
    }

    private func handleUploadResponse(data: Data, response: URLResponse) throws -> URL {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClipforgeError.badServerResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw mapHTTPStatus(code: httpResponse.statusCode, payload: data)
        }

        return try decodeUploadURL(from: data)
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

private final class UploadTaskDelegate: NSObject, URLSessionDataDelegate, URLSessionTaskDelegate, @unchecked Sendable {
    private let onProgress: UploadClient.ProgressHandler?
    private var continuation: CheckedContinuation<(Data, URLResponse), Error>?
    private var response: URLResponse?
    private var responseData = Data()

    init(onProgress: UploadClient.ProgressHandler?) {
        self.onProgress = onProgress
    }

    func upload(
        with request: URLRequest,
        body: Data,
        session: URLSession
    ) async throws -> (Data, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            emitProgress(0)

            let task = session.uploadTask(with: request, from: body)
            task.resume()
        }
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        self.response = response
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        responseData.append(data)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        guard totalBytesExpectedToSend > 0 else { return }

        let fractionCompleted = min(
            max(Double(totalBytesSent) / Double(totalBytesExpectedToSend), 0),
            1
        )
        emitProgress(fractionCompleted)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            resume(with: .failure(error))
            return
        }

        guard let response else {
            resume(with: .failure(ClipforgeError.badServerResponse))
            return
        }

        emitProgress(1)
        resume(with: .success((responseData, response)))
    }

    private func emitProgress(_ fractionCompleted: Double) {
        guard let onProgress else { return }

        Task { @MainActor in
            onProgress(fractionCompleted)
        }
    }

    private func resume(with result: Result<(Data, URLResponse), Error>) {
        guard let continuation else { return }

        self.continuation = nil
        self.response = nil
        self.responseData = Data()

        switch result {
        case .success(let payload):
            continuation.resume(returning: payload)
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }
}
