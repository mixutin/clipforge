import Foundation

enum FilenameGenerator {
    struct Context: Sendable {
        var now: Date = Date()
        var displayName: String?
        var sourceName: String?
        var randomSuffix: String?
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "HHmmss"
        return formatter
    }()

    static func makeBase(using mode: AppSettings.FilenameMode, now: Date = Date()) -> String {
        var settings = AppSettings.default
        settings.filenameMode = mode
        return makeBase(using: settings, context: Context(now: now))
    }

    static func makeBase(using settings: AppSettings, context: Context = Context()) -> String {
        switch settings.filenameMode {
        case .randomHex:
            let randomSuffix = context.randomSuffix ?? makeRandomHex(length: 12)
            return "clipforge-\(String(randomSuffix.prefix(12)))"
        case .timestamp:
            return "clipforge-\(timestampFormatter.string(from: context.now))"
        case .dateTimeDisplay:
            return render(
                template: AppSettings.defaultCustomFilenameTemplate,
                context: context
            )
        case .customTemplate:
            return render(
                template: settings.filenameTemplate,
                context: context
            )
        }
    }

    static func previewBase(using settings: AppSettings) -> String {
        makeBase(
            using: settings,
            context: Context(
                now: Date(),
                displayName: "Studio Display",
                sourceName: "Screen",
                randomSuffix: "a1b2c3d4e5f6"
            )
        )
    }

    private static func render(template: String, context: Context) -> String {
        let randomSuffix = context.randomSuffix ?? makeRandomHex(length: 6)
        var result = template

        let replacements: [String: String] = [
            "{date}": dateFormatter.string(from: context.now),
            "{time}": timeFormatter.string(from: context.now),
            "{timestamp}": timestampFormatter.string(from: context.now),
            "{display_name}": sanitizeToken(context.displayName),
            "{source_name}": sanitizeToken(context.sourceName),
            "{random_suffix}": randomSuffix
        ]

        for (placeholder, value) in replacements {
            result = result.replacingOccurrences(of: placeholder, with: value)
        }

        result = result.replacingOccurrences(
            of: #"\{[^}]+\}"#,
            with: "",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"[\/\\:\*\?\"<>\|]+"#,
            with: "-",
            options: .regularExpression
        )
        result = result.replacingOccurrences(of: #"\s+"#, with: "-", options: .regularExpression)
        result = result.replacingOccurrences(of: #"-{2,}"#, with: "-", options: .regularExpression)
        result = result.replacingOccurrences(of: #"_{2,}"#, with: "_", options: .regularExpression)
        result = result.trimmingCharacters(in: CharacterSet(charactersIn: "-_. "))
        result = result.lowercased()

        return result.isEmpty ? "clipforge-\(randomSuffix)" : result
    }

    private static func sanitizeToken(_ value: String?) -> String {
        guard let value, value.isEmpty == false else {
            return ""
        }

        return value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(
                of: #"[\/\\:\*\?\"<>\|]+"#,
                with: "-",
                options: .regularExpression
            )
            .replacingOccurrences(of: #"\s+"#, with: "-", options: .regularExpression)
            .replacingOccurrences(of: #"-{2,}"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-_. "))
    }

    private static func makeRandomHex(length: Int) -> String {
        let random = UUID().uuidString
            .replacingOccurrences(of: "-", with: "")
            .lowercased()

        return String(random.prefix(length))
    }
}
