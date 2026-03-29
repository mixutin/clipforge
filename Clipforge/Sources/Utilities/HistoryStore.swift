import Foundation

@MainActor
final class HistoryStore {
    static let shared = HistoryStore()

    private let fileManager: FileManager
    private let baseDirectory: URL
    private let maxItems: Int

    init(
        fileManager: FileManager = .default,
        baseDirectory: URL? = nil,
        maxItems: Int = 200
    ) {
        self.fileManager = fileManager
        self.baseDirectory = baseDirectory ?? Self.defaultBaseDirectory(fileManager: fileManager)
        self.maxItems = maxItems
    }

    func load() -> [UploadRecord] {
        let fileURL = historyFileURL()
        guard let data = try? Data(contentsOf: fileURL) else { return [] }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([UploadRecord].self, from: data)) ?? []
    }

    @discardableResult
    func add(_ record: UploadRecord) -> [UploadRecord] {
        var items = load()
        items.insert(record, at: 0)
        items = Array(items.prefix(maxItems))
        persist(items)
        return items
    }

    private func persist(_ items: [UploadRecord]) {
        try? fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(items) else { return }
        try? data.write(to: historyFileURL(), options: .atomic)
    }

    private func historyFileURL() -> URL {
        baseDirectory.appendingPathComponent("recent-uploads.json")
    }

    private static func defaultBaseDirectory(fileManager: FileManager) -> URL {
        let directory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return directory.appendingPathComponent("Clipforge", isDirectory: true)
    }
}
