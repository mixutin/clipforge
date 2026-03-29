import Foundation
import AppKit
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

    func testCustomTemplateUsesPlaceholdersAndSanitizesDisplayName() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        var settings = sampleSettings(imageFormatMode: .automatic, jpegCompressionQuality: 0.92)
        settings.filenameMode = .customTemplate
        settings.filenameTemplate = "shot-{date}-{time}-{display_name}-{random_suffix}"
        let expectedDate = formatted(date, pattern: "yyyyMMdd")
        let expectedTime = formatted(date, pattern: "HHmmss")

        let result = FilenameGenerator.makeBase(
            using: settings,
            context: FilenameGenerator.Context(
                now: date,
                displayName: "Studio Display",
                sourceName: "screen",
                randomSuffix: "abc123"
            )
        )

        XCTAssertEqual(result, "shot-\(expectedDate)-\(expectedTime)-studio-display-abc123")
    }

    func testCustomTemplateRemovesMissingPlaceholdersCleanly() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        var settings = sampleSettings(imageFormatMode: .automatic, jpegCompressionQuality: 0.92)
        settings.filenameMode = .customTemplate
        settings.filenameTemplate = "clipforge-{date}-{display_name}-{random_suffix}"
        let expectedDate = formatted(date, pattern: "yyyyMMdd")

        let result = FilenameGenerator.makeBase(
            using: settings,
            context: FilenameGenerator.Context(
                now: date,
                displayName: nil,
                sourceName: "clipboard",
                randomSuffix: "ff99aa"
            )
        )

        XCTAssertEqual(result, "clipforge-\(expectedDate)-ff99aa")
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

    func testAutomaticImageFormatUsesPNGForTransparentImages() throws {
        let asset = try CapturedAsset.from(
            nsImage: sampleImage(includeTransparency: true),
            filenameBase: "clipforge-test",
            settings: sampleSettings(imageFormatMode: .automatic, jpegCompressionQuality: 0.92)
        )

        XCTAssertEqual(asset.fileExtension, "png")
        XCTAssertEqual(asset.mimeType, "image/png")
    }

    func testJPEGImageFormatUsesConfiguredCompressionQuality() throws {
        let lowQualityAsset = try CapturedAsset.from(
            nsImage: sampleImage(includeTransparency: false),
            filenameBase: "clipforge-test",
            settings: sampleSettings(imageFormatMode: .jpeg, jpegCompressionQuality: 0.55)
        )
        let highQualityAsset = try CapturedAsset.from(
            nsImage: sampleImage(includeTransparency: false),
            filenameBase: "clipforge-test",
            settings: sampleSettings(imageFormatMode: .jpeg, jpegCompressionQuality: 0.95)
        )

        XCTAssertEqual(lowQualityAsset.fileExtension, "jpg")
        XCTAssertEqual(lowQualityAsset.mimeType, "image/jpeg")
        XCTAssertLessThan(lowQualityAsset.data.count, highQualityAsset.data.count)
    }

    private func sampleSettings(
        imageFormatMode: AppSettings.ImageFormatMode,
        jpegCompressionQuality: Double
    ) -> AppSettings {
        AppSettings(
            serverURL: "https://example.com",
            apiToken: "test-token",
            autoCopyLinkEnabled: true,
            annotationReviewEnabled: false,
            imageFormatMode: imageFormatMode,
            jpegCompressionQuality: jpegCompressionQuality,
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

    private func sampleImage(includeTransparency: Bool) -> NSImage {
        let size = NSSize(width: 240, height: 140)
        let image = NSImage(size: size)

        image.lockFocusFlipped(true)

        if includeTransparency {
            NSColor.clear.setFill()
        } else {
            NSColor.white.setFill()
        }

        NSRect(origin: .zero, size: size).fill()

        for stripeIndex in 0..<16 {
            let stripeRect = NSRect(
                x: CGFloat(stripeIndex) * 15,
                y: 0,
                width: 10,
                height: size.height
            )
            NSColor(
                calibratedRed: CGFloat(stripeIndex % 4) * 0.2 + 0.2,
                green: CGFloat((stripeIndex + 1) % 5) * 0.15 + 0.2,
                blue: CGFloat((stripeIndex + 2) % 6) * 0.1 + 0.2,
                alpha: includeTransparency && stripeIndex.isMultiple(of: 3) ? 0.45 : 1
            ).setFill()
            stripeRect.fill()
        }

        NSColor.systemBlue.setFill()
        NSBezierPath(ovalIn: NSRect(x: 24, y: 26, width: 78, height: 78)).fill()

        NSColor.systemOrange.setFill()
        NSBezierPath(roundedRect: NSRect(x: 118, y: 22, width: 96, height: 88), xRadius: 16, yRadius: 16).fill()

        image.unlockFocus()
        return image
    }

    private func formatted(_ date: Date, pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}
