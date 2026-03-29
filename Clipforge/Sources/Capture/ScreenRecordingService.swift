import AppKit
@preconcurrency import AVFoundation
import CoreImage
import ScreenCaptureKit

extension SCDisplay: @unchecked @retroactive Sendable {}

final class ScreenRecordingService: NSObject, SCStreamOutput, @unchecked Sendable {
    private let sampleQueue = DispatchQueue(label: "com.clipforge.screen-recording")
    private let ciContext = CIContext(options: nil)

    private var stream: SCStream?
    private var writer: AVAssetWriter?
    private var writerInput: AVAssetWriterInput?
    private var outputURL: URL?
    private var previewImage: NSImage?

    func recordShortClip(
        filenameBase: String,
        durationSeconds: Double = 8
    ) async throws -> CapturedAsset {
        try await PermissionManager.ensureScreenCaptureAccess()
        resetState()

        let display = try await Self.activeDisplay()
        let configuration = SCStreamConfiguration()
        configuration.width = display.width
        configuration.height = display.height
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 18)
        configuration.queueDepth = 4
        configuration.showsCursor = true
        configuration.capturesAudio = false
        configuration.colorSpaceName = CGColorSpace.sRGB

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        let writerInput = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: display.width,
                AVVideoHeightKey: display.height,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: max(display.width * display.height * 4, 3_000_000),
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                ]
            ]
        )
        writerInput.expectsMediaDataInRealTime = true
        writer.add(writerInput)

        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        let stream = SCStream(filter: filter, configuration: configuration, delegate: nil)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: sampleQueue)

        self.outputURL = outputURL
        self.writer = writer
        self.writerInput = writerInput
        self.stream = stream
        self.previewImage = nil

        do {
            try await stream.startCapture()
            try await Task.sleep(for: .milliseconds(Int(durationSeconds * 1000)))
            try await Self.finishRecording(
                stream: stream,
                writer: writer,
                writerInput: writerInput,
                sampleQueue: sampleQueue
            )
        } catch {
            cleanupTemporaryFile()
            resetState()
            throw error
        }

        guard let data = try? Data(contentsOf: outputURL) else {
            cleanupTemporaryFile()
            throw ClipforgeError.recordingUnavailable
        }

        let asset = CapturedAsset.video(
            data: data,
            filenameBase: filenameBase,
            thumbnailImage: previewImage,
            durationSeconds: durationSeconds
        )

        cleanupTemporaryFile()
        resetState()
        return asset
    }

    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of outputType: SCStreamOutputType
    ) {
        guard outputType == .screen else { return }
        guard CMSampleBufferDataIsReady(sampleBuffer) else { return }
        guard let writer, let writerInput else { return }

        if previewImage == nil, let cgImage = cgImage(from: sampleBuffer) {
            previewImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        }

        if writer.status == .unknown {
            let startTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            writer.startWriting()
            writer.startSession(atSourceTime: startTime)
        }

        guard writer.status == .writing else { return }
        guard writerInput.isReadyForMoreMediaData else { return }
        _ = writerInput.append(sampleBuffer)
    }

    private static func finishRecording(
        stream: SCStream,
        writer: AVAssetWriter,
        writerInput: AVAssetWriterInput,
        sampleQueue: DispatchQueue
    ) async throws {
        try await stream.stopCapture()
        let handles = RecordingWriterHandles(writer: writer, writerInput: writerInput)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sampleQueue.async {
                handles.finish(with: continuation)
            }
        }
    }

    private static func activeDisplay() async throws -> SCDisplay {
        let content = try await shareableContent()
        let screenNumber = await MainActor.run { Self.activeScreenNumber() }

        if let screenNumber,
           let matchedDisplay = content.displays.first(where: { $0.displayID == screenNumber }) {
            return matchedDisplay
        }

        guard let fallbackDisplay = content.displays.first else {
            throw ClipforgeError.recordingUnavailable
        }

        return fallbackDisplay
    }

    @MainActor
    private static func activeScreenNumber() -> UInt32? {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) ?? NSScreen.main
        return (screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }

    private static func shareableContent() async throws -> SCShareableContent {
        try await withCheckedThrowingContinuation { continuation in
            SCShareableContent.getExcludingDesktopWindows(true, onScreenWindowsOnly: true) { content, error in
                if let error {
                    continuation.resume(throwing: ClipforgeError.generic(error.localizedDescription))
                    return
                }

                guard let content else {
                    continuation.resume(throwing: ClipforgeError.recordingUnavailable)
                    return
                }

                continuation.resume(returning: content)
            }
        }
    }

    private func cgImage(from sampleBuffer: CMSampleBuffer) -> CGImage? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        return ciContext.createCGImage(image, from: image.extent)
    }

    private func cleanupTemporaryFile() {
        if let outputURL {
            try? FileManager.default.removeItem(at: outputURL)
        }
    }

    private func resetState() {
        stream = nil
        writer = nil
        writerInput = nil
        outputURL = nil
        previewImage = nil
    }
}

private final class RecordingWriterHandles: @unchecked Sendable {
    private let writer: AVAssetWriter
    private let writerInput: AVAssetWriterInput

    init(writer: AVAssetWriter, writerInput: AVAssetWriterInput) {
        self.writer = writer
        self.writerInput = writerInput
    }

    func finish(with continuation: CheckedContinuation<Void, Error>) {
        writerInput.markAsFinished()

        guard writer.status == .writing else {
            let error = writer.error?.localizedDescription ?? ClipforgeError.recordingUnavailable.localizedDescription
            continuation.resume(throwing: ClipforgeError.generic(error))
            return
        }

        writer.finishWriting {
            if self.writer.status == .completed {
                continuation.resume()
            } else {
                let error = self.writer.error?.localizedDescription ?? ClipforgeError.recordingUnavailable.localizedDescription
                continuation.resume(throwing: ClipforgeError.generic(error))
            }
        }
    }
}
