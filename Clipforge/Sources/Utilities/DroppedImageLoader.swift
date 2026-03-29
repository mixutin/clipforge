import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
enum DroppedImageLoader {
    static func loadImageAsset(
        from providers: [NSItemProvider],
        filenameBase: String,
        settings: AppSettings
    ) async throws -> CapturedAsset {
        var lastError: Error?

        for provider in providers {
            do {
                if let asset = try await loadImageAsset(from: provider, filenameBase: filenameBase, settings: settings) {
                    return asset
                }
            } catch {
                lastError = error
            }
        }

        if let clipforgeError = lastError as? ClipforgeError {
            throw clipforgeError
        }

        if let lastError {
            throw ClipforgeError.generic(lastError.localizedDescription)
        }

        throw ClipforgeError.droppedItemNotSupported
    }

    private static func loadImageAsset(
        from provider: NSItemProvider,
        filenameBase: String,
        settings: AppSettings
    ) async throws -> CapturedAsset? {
        var lastError: Error?

        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            do {
                if
                    let fileURL = try await loadFileURL(from: provider),
                    let asset = try loadImageAsset(from: fileURL, filenameBase: filenameBase, settings: settings)
                {
                    return asset
                }
            } catch {
                lastError = error
            }
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            do {
                if let image = try await loadImage(from: provider) {
                    return try CapturedAsset.from(nsImage: image, filenameBase: filenameBase, settings: settings)
                }
            } catch {
                lastError = error
            }
        }

        if let clipforgeError = lastError as? ClipforgeError {
            throw clipforgeError
        }

        if let lastError {
            throw ClipforgeError.generic(lastError.localizedDescription)
        }

        return nil
    }

    private static func loadImageAsset(from fileURL: URL, filenameBase: String, settings: AppSettings) throws -> CapturedAsset? {
        let accessedScopedResource = fileURL.startAccessingSecurityScopedResource()
        defer {
            if accessedScopedResource {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        guard let image = NSImage(contentsOf: fileURL) else {
            return nil
        }

        return try CapturedAsset.from(nsImage: image, filenameBase: filenameBase, settings: settings)
    }

    private static func loadFileURL(from provider: NSItemProvider) async throws -> URL? {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                switch item {
                case let url as URL:
                    continuation.resume(returning: url)
                case let data as Data:
                    continuation.resume(returning: URL(dataRepresentation: data, relativeTo: nil))
                case let string as String:
                    continuation.resume(returning: URL(string: string))
                case let string as NSString:
                    continuation.resume(returning: URL(string: string as String))
                default:
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private static func loadImage(from provider: NSItemProvider) async throws -> NSImage? {
        var lastError: Error?

        for typeIdentifier in imageTypeIdentifiers(from: provider) {
            do {
                if
                    let data = try await loadDataRepresentation(from: provider, typeIdentifier: typeIdentifier),
                    let image = NSImage(data: data)
                {
                    return image
                }
            } catch {
                lastError = error
            }
        }

        if let lastError {
            throw lastError
        }

        return nil
    }

    private static func imageTypeIdentifiers(from provider: NSItemProvider) -> [String] {
        let providerImageTypes = provider.registeredTypeIdentifiers.filter { identifier in
            UTType(identifier)?.conforms(to: .image) == true
        }

        var orderedTypes: [String] = []
        var seen = Set<String>()

        for identifier in providerImageTypes + [
            UTType.image.identifier,
            UTType.png.identifier,
            UTType.jpeg.identifier,
            UTType.tiff.identifier
        ] {
            if seen.insert(identifier).inserted {
                orderedTypes.append(identifier)
            }
        }

        return orderedTypes
    }

    private static func loadDataRepresentation(
        from provider: NSItemProvider,
        typeIdentifier: String
    ) async throws -> Data? {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { data, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(returning: data)
            }
        }
    }
}
