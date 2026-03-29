import Foundation

enum FilenameGenerator {
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()

    static func makeBase(using mode: AppSettings.FilenameMode, now: Date = Date()) -> String {
        switch mode {
        case .randomHex:
            let random = UUID().uuidString
                .replacingOccurrences(of: "-", with: "")
                .lowercased()
            return "clipforge-\(random.prefix(12))"
        case .timestamp:
            return "clipforge-\(formatter.string(from: now))"
        }
    }
}
