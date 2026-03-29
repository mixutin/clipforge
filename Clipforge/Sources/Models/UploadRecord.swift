import Foundation

struct UploadRecord: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let localFilename: String
    let remoteURL: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        localFilename: String,
        remoteURL: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.localFilename = localFilename
        self.remoteURL = remoteURL
        self.createdAt = createdAt
    }
}
