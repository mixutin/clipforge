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
        static let localFolder = "settings.localFolder"
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
            Keys.localFolder: AppSettings.default.localSaveFolder,
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

    var localSaveFolder: String {
        get { defaults.string(forKey: Keys.localFolder) ?? AppSettings.default.localSaveFolder }
        set {
            defaults.set(newValue, forKey: Keys.localFolder)
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
            localSaveFolder: localSaveFolder,
            filenameMode: filenameMode
        )
    }

    func binding<Value>(for keyPath: ReferenceWritableKeyPath<SettingsStore, Value>) -> Binding<Value> {
        Binding(
            get: { self[keyPath: keyPath] },
            set: { self[keyPath: keyPath] = $0 }
        )
    }

    func validate() throws -> AppSettings {
        let settings = currentSettings

        guard let url = URL(string: settings.serverURL), url.scheme != nil, url.host != nil else {
            throw ClipforgeError.invalidServerURL
        }

        guard settings.apiToken.isEmpty == false else {
            throw ClipforgeError.missingAPIToken
        }

        return settings
    }

    func resetLocalFolderToDefault() {
        localSaveFolder = AppSettings.defaultLocalSaveFolder
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

extension Notification.Name {
    static let clipforgeHotkeyDidChange = Notification.Name("clipforge.hotkeyDidChange")
}
