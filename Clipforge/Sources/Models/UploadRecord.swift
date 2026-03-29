import Foundation

struct UploadRecord: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let localFilename: String
    let remoteURL: String
    let thumbnailPNGData: Data?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        localFilename: String,
        remoteURL: String,
        thumbnailPNGData: Data? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.localFilename = localFilename
        self.remoteURL = remoteURL
        self.thumbnailPNGData = thumbnailPNGData
        self.createdAt = createdAt
    }
}
