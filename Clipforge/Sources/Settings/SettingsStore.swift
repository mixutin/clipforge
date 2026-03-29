import Foundation
import SwiftUI

@MainActor
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    private enum Keys {
        static let serverURL = "settings.serverURL"
        static let legacyAPIToken = "settings.apiToken"
        static let autoCopy = "settings.autoCopy"
        static let saveLocal = "settings.saveLocal"
        static let revealSavedFileAfterUpload = "settings.revealSavedFileAfterUpload"
        static let localFolder = "settings.localFolder"
        static let captureDestinationMode = "settings.captureDestinationMode"
        static let filenameMode = "settings.filenameMode"
        static let hotkeyKeyCode = "settings.hotkey.keyCode"
        static let hotkeyModifiers = "settings.hotkey.modifiers"
    }

    private let defaults = UserDefaults.standard
    private var apiTokenCache: String

    private init() {
        apiTokenCache = ""

        defaults.register(defaults: [
            Keys.serverURL: AppSettings.default.serverURL,
            Keys.autoCopy: AppSettings.default.autoCopyLinkEnabled,
            Keys.saveLocal: AppSettings.default.saveLocalScreenshotEnabled,
            Keys.revealSavedFileAfterUpload: AppSettings.default.revealSavedFileAfterUploadEnabled,
            Keys.localFolder: AppSettings.default.localSaveFolder,
            Keys.captureDestinationMode: AppSettings.default.captureDestinationMode.rawValue,
            Keys.filenameMode: AppSettings.default.filenameMode.rawValue,
            Keys.hotkeyKeyCode: HotkeyDescriptor.default.keyCode,
            Keys.hotkeyModifiers: HotkeyDescriptor.default.modifiers
        ])

        migrateLegacyAPITokenIfNeeded()
        apiTokenCache = KeychainService.loadToken()
    }

    var serverURL: String {
        get { defaults.string(forKey: Keys.serverURL) ?? AppSettings.default.serverURL }
        set {
            defaults.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Keys.serverURL)
            objectWillChange.send()
        }
    }

    var apiToken: String {
        get { apiTokenCache }
        set {
            let trimmedValue = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            apiTokenCache = trimmedValue

            if trimmedValue.isEmpty {
                _ = KeychainService.deleteToken()
            } else {
                _ = KeychainService.saveToken(trimmedValue)
            }

            objectWillChange.send()
        }
    }

    var autoCopyLinkEnabled: Bool {
        get { defaults.bool(forKey: Keys.autoCopy) }
        set {
            defaults.set(newValue, forKey: Keys.autoCopy)
            objectWillChange.send()
        }
    }

    var saveLocalScreenshotEnabled: Bool {
        get { defaults.bool(forKey: Keys.saveLocal) }
        set {
            defaults.set(newValue, forKey: Keys.saveLocal)
            objectWillChange.send()
        }
    }

    var revealSavedFileAfterUploadEnabled: Bool {
        get { defaults.bool(forKey: Keys.revealSavedFileAfterUpload) }
        set {
            defaults.set(newValue, forKey: Keys.revealSavedFileAfterUpload)
            objectWillChange.send()
        }
    }

    var localSaveFolder: String {
        get { defaults.string(forKey: Keys.localFolder) ?? AppSettings.default.localSaveFolder }
        set {
            defaults.set(newValue, forKey: Keys.localFolder)
            objectWillChange.send()
        }
    }

    var captureDestinationMode: AppSettings.CaptureDestinationMode {
        get {
            let rawValue = defaults.string(forKey: Keys.captureDestinationMode) ?? AppSettings.default.captureDestinationMode.rawValue
            return AppSettings.CaptureDestinationMode(rawValue: rawValue) ?? .automatic
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.captureDestinationMode)
            objectWillChange.send()
        }
    }

    var filenameMode: AppSettings.FilenameMode {
        get {
            let rawValue = defaults.string(forKey: Keys.filenameMode) ?? AppSettings.default.filenameMode.rawValue
            return AppSettings.FilenameMode(rawValue: rawValue) ?? .randomHex
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.filenameMode)
            objectWillChange.send()
        }
    }

    var hotkey: HotkeyDescriptor {
        get {
            HotkeyDescriptor(
                keyCode: UInt32(defaults.integer(forKey: Keys.hotkeyKeyCode)),
                modifiers: UInt32(defaults.integer(forKey: Keys.hotkeyModifiers))
            )
        }
        set {
            defaults.set(Int(newValue.keyCode), forKey: Keys.hotkeyKeyCode)
            defaults.set(Int(newValue.modifiers), forKey: Keys.hotkeyModifiers)
            NotificationCenter.default.post(name: .clipforgeHotkeyDidChange, object: nil)
            objectWillChange.send()
        }
    }

    var currentSettings: AppSettings {
        AppSettings(
            serverURL: serverURL,
            apiToken: apiToken,
            autoCopyLinkEnabled: autoCopyLinkEnabled,
            saveLocalScreenshotEnabled: saveLocalScreenshotEnabled,
            revealSavedFileAfterUploadEnabled: revealSavedFileAfterUploadEnabled,
            localSaveFolder: localSaveFolder,
            captureDestinationMode: captureDestinationMode,
            filenameMode: filenameMode
        )
    }

    func binding<Value>(for keyPath: ReferenceWritableKeyPath<SettingsStore, Value>) -> Binding<Value> {
        Binding(
            get: { self[keyPath: keyPath] },
            set: { self[keyPath: keyPath] = $0 }
        )
    }

    var hasReadyUploadConfiguration: Bool {
        if case .ready = uploadConfigurationState() {
            return true
        }

        return false
    }

    func validate() throws -> AppSettings {
        try validatedUploadSettings()
    }

    func validatedUploadSettings() throws -> AppSettings {
        switch uploadConfigurationState() {
        case .ready(let settings):
            return settings
        case .notConfigured:
            throw ClipforgeError.invalidServerURL
        case .invalid(let error):
            throw error
        }
    }

    func resetLocalFolderToDefault() {
        localSaveFolder = AppSettings.defaultLocalSaveFolder
    }

    func uploadConfigurationState() -> UploadConfigurationState {
        let trimmedURL = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedToken = apiToken.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedURL.isEmpty && trimmedToken.isEmpty {
            return .notConfigured
        }

        if trimmedURL.isEmpty {
            return .invalid(.invalidServerURL)
        }

        guard let url = URL(string: trimmedURL), url.scheme != nil, url.host != nil else {
            return .invalid(.invalidServerURL)
        }

        guard trimmedToken.isEmpty == false else {
            return .invalid(.missingAPIToken)
        }

        return .ready(currentSettings)
    }

    private func migrateLegacyAPITokenIfNeeded() {
        let existingKeychainToken = KeychainService.loadToken()
        guard existingKeychainToken.isEmpty else {
            defaults.removeObject(forKey: Keys.legacyAPIToken)
            return
        }

        guard let legacyToken = defaults.string(forKey: Keys.legacyAPIToken)?.trimmingCharacters(in: .whitespacesAndNewlines),
              legacyToken.isEmpty == false
        else {
            defaults.removeObject(forKey: Keys.legacyAPIToken)
            return
        }

        _ = KeychainService.saveToken(legacyToken)
        defaults.removeObject(forKey: Keys.legacyAPIToken)
    }
}

enum UploadConfigurationState {
    case ready(AppSettings)
    case notConfigured
    case invalid(ClipforgeError)
}

extension Notification.Name {
    static let clipforgeHotkeyDidChange = Notification.Name("clipforge.hotkeyDidChange")
}
