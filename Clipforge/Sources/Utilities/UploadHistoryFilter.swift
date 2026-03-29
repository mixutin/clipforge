import Foundation

enum UploadHistoryFilter {
    static func filter(_ items: [UploadRecord], query: String) -> [UploadRecord] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.isEmpty == false else { return items }

        let normalizedTokens = normalized(trimmedQuery)
            .split(separator: " ")
            .map(String.init)

        guard normalizedTokens.isEmpty == false else { return items }

        return items.filter { item in
            let searchableText = searchableText(for: item)
            return normalizedTokens.allSatisfy { searchableText.contains($0) }
        }
    }

    private static func searchableText(for item: UploadRecord) -> String {
        let dateText = item.createdAt.formatted(date: .abbreviated, time: .shortened)
        let isoText = ISO8601DateFormatter().string(from: item.createdAt)

        return normalized([
            item.localFilename,
            item.remoteURL,
            item.directURL ?? "",
            item.shareURL ?? "",
            dateText,
            isoText
        ].joined(separator: " "))
    }

    private static func normalized(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
    }
}
