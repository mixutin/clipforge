import Foundation
import XCTest
@testable import Clipforge

final class UploadHistoryFilterTests: XCTestCase {
    func testFilterMatchesFilenameTokens() {
        let items = sampleItems()

        let result = UploadHistoryFilter.filter(items, query: "studio display")

        XCTAssertEqual(result.map(\.localFilename), ["clipforge-studio-display.png"])
    }

    func testFilterMatchesRemoteURLAndReturnsAllForEmptyQuery() {
        let items = sampleItems()

        XCTAssertEqual(
            UploadHistoryFilter.filter(items, query: "uploads/beta").map(\.remoteURL),
            ["https://example.com/uploads/beta.png"]
        )
        XCTAssertEqual(UploadHistoryFilter.filter(items, query: "   ").count, items.count)
    }

    private func sampleItems() -> [UploadRecord] {
        [
            UploadRecord(
                localFilename: "clipforge-studio-display.png",
                remoteURL: "https://example.com/uploads/alpha.png",
                createdAt: Date(timeIntervalSince1970: 1_700_000_000)
            ),
            UploadRecord(
                localFilename: "clipforge-terminal-window.png",
                remoteURL: "https://example.com/uploads/beta.png",
                createdAt: Date(timeIntervalSince1970: 1_700_000_100)
            )
        ]
    }
}
