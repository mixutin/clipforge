import Foundation
import XCTest
@testable import Clipforge

final class HistoryStoreTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }

        temporaryDirectory = nil
    }

    @MainActor
    func testLoadReturnsEmptyArrayWhenHistoryDoesNotExist() {
        let store = HistoryStore(baseDirectory: temporaryDirectory)

        XCTAssertEqual(store.load(), [])
    }

    @MainActor
    func testAddPersistsRecordsToDisk() {
        let store = HistoryStore(baseDirectory: temporaryDirectory)
        let record = UploadRecord(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            localFilename: "clipforge-001.png",
            remoteURL: "https://example.com/uploads/clipforge-001.png",
            thumbnailPNGData: Data([0x01, 0x02, 0x03]),
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        _ = store.add(record)

        let reloadedStore = HistoryStore(baseDirectory: temporaryDirectory)
        XCTAssertEqual(reloadedStore.load(), [record])
    }

    @MainActor
    func testAddKeepsNewestEntriesUpToLimit() {
        let store = HistoryStore(baseDirectory: temporaryDirectory, maxItems: 3)

        for index in 0..<5 {
            _ = store.add(
                UploadRecord(
                    localFilename: "clipforge-\(index).png",
                    remoteURL: "https://example.com/\(index)",
                    createdAt: Date(timeIntervalSince1970: TimeInterval(index))
                )
            )
        }

        let items = store.load()
        XCTAssertEqual(items.count, 3)
        XCTAssertEqual(items.map(\.localFilename), [
            "clipforge-4.png",
            "clipforge-3.png",
            "clipforge-2.png"
        ])
    }

    @MainActor
    func testLoadDecodesLegacyRecordsWithoutMediaKindOrRecognizedText() throws {
        let historyDirectory = temporaryDirectory!
        try FileManager.default.createDirectory(at: historyDirectory, withIntermediateDirectories: true)

        let legacyJSON = """
        [
          {
            "id": "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE",
            "localFilename": "clipforge-legacy.png",
            "remoteURL": "https://example.com/uploads/clipforge-legacy.png",
            "thumbnailPNGData": "AQID",
            "createdAt": "2023-11-14T22:13:20Z"
          }
        ]
        """

        let legacyData = try XCTUnwrap(legacyJSON.data(using: .utf8))
        try legacyData.write(
            to: historyDirectory.appendingPathComponent("recent-uploads.json"),
            options: .atomic
        )

        let store = HistoryStore(baseDirectory: historyDirectory)
        let items = store.load()

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.mediaKind, .image)
        XCTAssertNil(items.first?.recognizedText)
    }
}
