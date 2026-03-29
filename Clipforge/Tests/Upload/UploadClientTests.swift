import Foundation
import XCTest
@testable import Clipforge

final class UploadClientTests: XCTestCase {
    override class func tearDown() {
        super.tearDown()
        MockURLProtocol.requestHandler = nil
    }

    func testUploadDecodesReturnedURL() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 201,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let data = Data(#"{"url":"https://example.com/uploads/test.png"}"#.utf8)
            return (response, data)
        }

        let client = UploadClient(session: makeSession())
        let url = try await client.upload(asset: sampleAsset(), settings: sampleSettings())

        XCTAssertEqual(url.absoluteString, "https://example.com/uploads/test.png")
    }

    func testUploadThrowsBadServerResponseForMalformedPayload() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 201,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data(#"{"not_url":"missing"}"#.utf8))
        }

        let client = UploadClient(session: makeSession())

        do {
            _ = try await client.upload(asset: sampleAsset(), settings: sampleSettings())
            XCTFail("Expected upload to throw for malformed payload")
        } catch let error as ClipforgeError {
            guard case .badServerResponse = error else {
                XCTFail("Expected badServerResponse, got \(error)")
                return
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testUploadReportsProgressWhenHandlerProvided() async throws {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 201,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let data = Data(#"{"url":"https://example.com/uploads/test.png"}"#.utf8)
            return (response, data)
        }

        let recorder = ProgressRecorder()
        let client = UploadClient(session: makeSession())

        _ = try await client.upload(asset: sampleAsset(), settings: sampleSettings()) { progress in
            recorder.append(progress)
        }

        let progressValues = recorder.values
        XCTAssertFalse(progressValues.isEmpty)
        XCTAssertEqual(progressValues.first ?? -1, 0, accuracy: 0.0001)
        XCTAssertEqual(progressValues.last ?? -1, 1, accuracy: 0.0001)
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private func sampleAsset() -> CapturedAsset {
        CapturedAsset(
            data: Data([0x89, 0x50, 0x4E, 0x47]),
            mimeType: "image/png",
            fileExtension: "png",
            filenameBase: "clipforge-test"
        )
    }

    private func sampleSettings() -> AppSettings {
        AppSettings(
            serverURL: "https://example.com",
            apiToken: "test-token",
            autoCopyLinkEnabled: true,
            annotationReviewEnabled: false,
            imageFormatMode: .automatic,
            jpegCompressionQuality: 0.92,
            saveLocalScreenshotEnabled: false,
            revealSavedFileAfterUploadEnabled: false,
            localSaveFolder: "/tmp",
            captureDestinationMode: .serverUpload,
            filenameMode: .randomHex,
            filenameTemplate: AppSettings.defaultCustomFilenameTemplate,
            uploadCopyFormat: .url,
            postUploadAction: .openLink
        )
    }
}

private final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private final class ProgressRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var recordedValues: [Double] = []

    var values: [Double] {
        lock.lock()
        defer { lock.unlock() }
        return recordedValues
    }

    func append(_ value: Double) {
        lock.lock()
        recordedValues.append(value)
        lock.unlock()
    }
}
