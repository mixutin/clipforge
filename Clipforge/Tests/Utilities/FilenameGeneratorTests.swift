import Foundation
import XCTest
@testable import Clipforge

final class FilenameGeneratorTests: XCTestCase {
    func testTimestampFilenameUsesProvidedDate() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyyMMdd-HHmmss"

        let result = FilenameGenerator.makeBase(using: .timestamp, now: date)

        XCTAssertEqual(result, "clipforge-\(formatter.string(from: date))")
    }

    func testRandomHexFilenameHasExpectedPrefixAndShape() {
        let result = FilenameGenerator.makeBase(using: .randomHex)

        XCTAssertTrue(result.hasPrefix("clipforge-"))

        let suffix = String(result.dropFirst("clipforge-".count))
        XCTAssertEqual(suffix.count, 12)
        XCTAssertNotNil(suffix.range(of: "^[0-9a-f]{12}$", options: .regularExpression))
    }

    func testMarkdownUploadCopyFormatUsesImageSyntax() {
        let result = AppSettings.UploadCopyFormat.markdownImage.formattedString(
            remoteURL: "https://example.com/uploads/clipforge-test.png",
            localFilename: "clipforge-test.png"
        )

        XCTAssertEqual(result, "![clipforge-test](<https://example.com/uploads/clipforge-test.png>)")
    }

    func testHTMLUploadCopyFormatEscapesAttributes() {
        let result = AppSettings.UploadCopyFormat.htmlImageTag.formattedString(
            remoteURL: "https://example.com/uploads/test?x=1&y=2",
            localFilename: "clip\"forge<test>.png"
        )

        XCTAssertEqual(
            result,
            "<img src=\"https://example.com/uploads/test?x=1&amp;y=2\" alt=\"clip&quot;forge&lt;test&gt;\" />"
        )
    }
}
