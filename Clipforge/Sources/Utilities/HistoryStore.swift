import Foundation

@MainActor
final class HistoryStore {
    static let shared = HistoryStore()

    private let fileManager = FileManager.default
    private let maxItems = 15

    private init() {}

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
        let directory = applicationSupportDirectory()
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(items) else { return }
        try? data.write(to: historyFileURL(), options: .atomic)
    }

    private func historyFileURL() -> URL {
        applicationSupportDirectory().appendingPathComponent("recent-uploads.json")
    }

    private func applicationSupportDirectory() -> URL {
        let baseDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return baseDirectory.appendingPathComponent("Clipforge", isDirectory: true)
    }
}
