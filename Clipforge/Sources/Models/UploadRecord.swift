import Foundation

struct UploadRecord: Codable, Identifiable, Equatable, Sendable {
    enum MediaKind: String, Codable, Sendable {
        case image
        case video
    }

    let id: UUID
    let localFilename: String
    let remoteURL: String
    let thumbnailPNGData: Data?
    let mediaKind: MediaKind
    let recognizedText: String?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        localFilename: String,
        remoteURL: String,
        thumbnailPNGData: Data? = nil,
        mediaKind: MediaKind = .image,
        recognizedText: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.localFilename = localFilename
        self.remoteURL = remoteURL
        self.thumbnailPNGData = thumbnailPNGData
        self.mediaKind = mediaKind
        self.recognizedText = recognizedText
        self.createdAt = createdAt
    }

    var hasRecognizedText: Bool {
        recognizedText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case localFilename
        case remoteURL
        case thumbnailPNGData
        case mediaKind
        case recognizedText
        case createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        localFilename = try container.decode(String.self, forKey: .localFilename)
        remoteURL = try container.decode(String.self, forKey: .remoteURL)
        thumbnailPNGData = try container.decodeIfPresent(Data.self, forKey: .thumbnailPNGData)
        mediaKind = try container.decodeIfPresent(MediaKind.self, forKey: .mediaKind) ?? .image
        recognizedText = try container.decodeIfPresent(String.self, forKey: .recognizedText)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
}
