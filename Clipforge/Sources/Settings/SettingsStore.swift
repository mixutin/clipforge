import Foundation
import SwiftUI

@MainActor
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    private enum Keys {
        static let serverURL = "settings.serverURL"
        static let apiToken = "settings.apiToken"
        static let autoCopy = "settings.autoCopy"
        static let saveLocal = "settings.saveLocal"
        static let localFolder = "settings.localFolder"
        static let filenameMode = "settings.filenameMode"
        static let hotkeyKeyCode = "settings.hotkey.keyCode"
        static let hotkeyModifiers = "settings.hotkey.modifiers"
    }

    private let defaults = UserDefaults.standard

    private init() {
        defaults.register(defaults: [
            Keys.serverURL: AppSettings.default.serverURL,
            Keys.apiToken: AppSettings.default.apiToken,
            Keys.autoCopy: AppSettings.default.autoCopyLinkEnabled,
            Keys.saveLocal: AppSettings.default.saveLocalScreenshotEnabled,
            Keys.localFolder: AppSettings.default.localSaveFolder,
            Keys.filenameMode: AppSettings.default.filenameMode.rawValue,
            Keys.hotkeyKeyCode: HotkeyDescriptor.default.keyCode,
            Keys.hotkeyModifiers: HotkeyDescriptor.default.modifiers
        ])
    }

    var serverURL: String {
        get { defaults.string(forKey: Keys.serverURL) ?? AppSettings.default.serverURL }
        set {
            defaults.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Keys.serverURL)
            objectWillChange.send()
        }
    }

    var apiToken: String {
        get { defaults.string(forKey: Keys.apiToken) ?? "" }
        set {
            defaults.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Keys.apiToken)
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
}
