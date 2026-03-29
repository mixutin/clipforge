import Foundation
import SwiftUI

@MainActor
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    private enum Keys {
        static let legacyServerURL = "settings.serverURL"
        static let legacyAPIToken = "settings.apiToken"
        static let serverProfiles = "settings.serverProfiles"
        static let activeServerProfileID = "settings.activeServerProfileID"
        static let autoCopy = "settings.autoCopy"
        static let annotationReview = "settings.annotationReview"
        static let imageFormatMode = "settings.imageFormatMode"
        static let jpegCompressionQuality = "settings.jpegCompressionQuality"
        static let saveLocal = "settings.saveLocal"
        static let revealSavedFileAfterUpload = "settings.revealSavedFileAfterUpload"
        static let hasPresentedPermissionGuide = "settings.hasPresentedPermissionGuide"
        static let localFolder = "settings.localFolder"
        static let captureDestinationMode = "settings.captureDestinationMode"
        static let filenameMode = "settings.filenameMode"
        static let filenameTemplate = "settings.filenameTemplate"
        static let uploadCopyFormat = "settings.uploadCopyFormat"
        static let postUploadAction = "settings.postUploadAction"
        static let hotkeyKeyCode = "settings.hotkey.keyCode"
        static let hotkeyModifiers = "settings.hotkey.modifiers"
    }

    private let defaults: UserDefaults
    private let keychain: KeychainClient

    private var cachedServerProfiles: [ServerProfile]
    private var activeServerProfileIDCache: String
    private var apiTokenCache: String

    init(defaults: UserDefaults = .standard, keychain: KeychainClient = .live) {
        self.defaults = defaults
        self.keychain = keychain
        self.apiTokenCache = ""

        defaults.register(defaults: [
            Keys.autoCopy: AppSettings.default.autoCopyLinkEnabled,
            Keys.annotationReview: AppSettings.default.annotationReviewEnabled,
            Keys.imageFormatMode: AppSettings.default.imageFormatMode.rawValue,
            Keys.jpegCompressionQuality: AppSettings.default.jpegCompressionQuality,
            Keys.saveLocal: AppSettings.default.saveLocalScreenshotEnabled,
            Keys.revealSavedFileAfterUpload: AppSettings.default.revealSavedFileAfterUploadEnabled,
            Keys.localFolder: AppSettings.default.localSaveFolder,
            Keys.captureDestinationMode: AppSettings.default.captureDestinationMode.rawValue,
            Keys.filenameMode: AppSettings.default.filenameMode.rawValue,
            Keys.filenameTemplate: AppSettings.default.filenameTemplate,
            Keys.uploadCopyFormat: AppSettings.default.uploadCopyFormat.rawValue,
            Keys.postUploadAction: AppSettings.default.postUploadAction.rawValue,
            Keys.hotkeyKeyCode: HotkeyDescriptor.default.keyCode,
            Keys.hotkeyModifiers: HotkeyDescriptor.default.modifiers
        ])

        let persistedState = Self.loadOrMigrateServerProfiles(defaults: defaults, keychain: keychain)
        cachedServerProfiles = persistedState.profiles
        activeServerProfileIDCache = persistedState.activeProfileID
        apiTokenCache = keychain.loadToken(activeServerProfileIDCache)
    }

    var serverProfiles: [ServerProfile] {
        cachedServerProfiles
    }

    var activeServerProfileID: String {
        get { activeServerProfileIDCache }
        set { selectServerProfile(id: newValue) }
    }

    var activeServerProfile: ServerProfile {
        cachedServerProfiles.first(where: { $0.id == activeServerProfileIDCache }) ?? cachedServerProfiles[0]
    }

    var activeServerProfileDisplayName: String {
        activeServerProfile.displayName
    }

    var activeServerProfileName: String {
        get { activeServerProfile.name }
        set {
            updateActiveProfile { profile in
                profile.name = newValue
            }
        }
    }

    var canDeleteServerProfile: Bool {
        cachedServerProfiles.count > 1
    }

    var serverURL: String {
        get { activeServerProfile.serverURL }
        set {
            updateActiveProfile { profile in
                profile.serverURL = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
    }

    var apiToken: String {
        get { apiTokenCache }
        set {
            let trimmedValue = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            apiTokenCache = trimmedValue

            if trimmedValue.isEmpty {
                _ = keychain.deleteToken(activeServerProfileIDCache)
            } else {
                _ = keychain.saveToken(trimmedValue, activeServerProfileIDCache)
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

    var annotationReviewEnabled: Bool {
        get { defaults.bool(forKey: Keys.annotationReview) }
        set {
            defaults.set(newValue, forKey: Keys.annotationReview)
            objectWillChange.send()
        }
    }

    var imageFormatMode: AppSettings.ImageFormatMode {
        get {
            let rawValue = defaults.string(forKey: Keys.imageFormatMode) ?? AppSettings.default.imageFormatMode.rawValue
            return AppSettings.ImageFormatMode(rawValue: rawValue) ?? .automatic
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.imageFormatMode)
            objectWillChange.send()
        }
    }

    var jpegCompressionQuality: Double {
        get {
            let storedValue = defaults.double(forKey: Keys.jpegCompressionQuality)
            let resolvedValue = storedValue == 0 ? AppSettings.default.jpegCompressionQuality : storedValue
            return min(max(resolvedValue, 0.4), 1.0)
        }
        set {
            defaults.set(min(max(newValue, 0.4), 1.0), forKey: Keys.jpegCompressionQuality)
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

    var filenameTemplate: String {
        get { defaults.string(forKey: Keys.filenameTemplate) ?? AppSettings.default.filenameTemplate }
        set {
            let trimmedTemplate = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            defaults.set(trimmedTemplate.isEmpty ? AppSettings.default.filenameTemplate : trimmedTemplate, forKey: Keys.filenameTemplate)
            objectWillChange.send()
        }
    }

    var uploadCopyFormat: AppSettings.UploadCopyFormat {
        get {
            let rawValue = defaults.string(forKey: Keys.uploadCopyFormat) ?? AppSettings.default.uploadCopyFormat.rawValue
            return AppSettings.UploadCopyFormat(rawValue: rawValue) ?? .url
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.uploadCopyFormat)
            objectWillChange.send()
        }
    }

    var postUploadAction: AppSettings.PostUploadAction {
        get {
            let rawValue = defaults.string(forKey: Keys.postUploadAction) ?? AppSettings.default.postUploadAction.rawValue
            return AppSettings.PostUploadAction(rawValue: rawValue) ?? .openLink
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.postUploadAction)
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
            serverURL: activeServerProfile.trimmedServerURL,
            apiToken: apiToken,
            autoCopyLinkEnabled: autoCopyLinkEnabled,
            annotationReviewEnabled: annotationReviewEnabled,
            imageFormatMode: imageFormatMode,
            jpegCompressionQuality: jpegCompressionQuality,
            saveLocalScreenshotEnabled: saveLocalScreenshotEnabled,
            revealSavedFileAfterUploadEnabled: revealSavedFileAfterUploadEnabled,
            localSaveFolder: localSaveFolder,
            captureDestinationMode: captureDestinationMode,
            filenameMode: filenameMode,
            filenameTemplate: filenameTemplate,
            uploadCopyFormat: uploadCopyFormat,
            postUploadAction: postUploadAction
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

    var shouldPresentPermissionGuideOnLaunch: Bool {
        defaults.bool(forKey: Keys.hasPresentedPermissionGuide) == false
    }

    func markPermissionGuidePresented() {
        defaults.set(true, forKey: Keys.hasPresentedPermissionGuide)
    }

    func uploadConfigurationState() -> UploadConfigurationState {
        let trimmedURL = activeServerProfile.trimmedServerURL
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

    func createServerProfile() {
        let newProfile = ServerProfile(
            name: suggestedNewProfileName(),
            serverURL: ""
        )

        cachedServerProfiles.append(newProfile)
        activeServerProfileIDCache = newProfile.id
        apiTokenCache = ""
        persistServerProfiles()
        defaults.set(newProfile.id, forKey: Keys.activeServerProfileID)
        objectWillChange.send()
    }

    func deleteActiveServerProfile() {
        guard canDeleteServerProfile else { return }

        let profileToDelete = activeServerProfile
        cachedServerProfiles.removeAll { $0.id == profileToDelete.id }
        _ = keychain.deleteToken(profileToDelete.id)

        let fallbackProfileID = cachedServerProfiles.first?.id ?? Self.defaultServerProfile().id
        activeServerProfileIDCache = fallbackProfileID
        apiTokenCache = keychain.loadToken(fallbackProfileID)
        persistServerProfiles()
        defaults.set(fallbackProfileID, forKey: Keys.activeServerProfileID)
        objectWillChange.send()
    }

    private func selectServerProfile(id: String) {
        guard cachedServerProfiles.contains(where: { $0.id == id }) else { return }
        guard activeServerProfileIDCache != id else { return }

        activeServerProfileIDCache = id
        defaults.set(id, forKey: Keys.activeServerProfileID)
        apiTokenCache = keychain.loadToken(id)
        objectWillChange.send()
    }

    private func updateActiveProfile(_ mutate: (inout ServerProfile) -> Void) {
        guard let index = cachedServerProfiles.firstIndex(where: { $0.id == activeServerProfileIDCache }) else {
            return
        }

        var profile = cachedServerProfiles[index]
        mutate(&profile)
        cachedServerProfiles[index] = profile
        persistServerProfiles()
        objectWillChange.send()
    }

    private func persistServerProfiles() {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(cachedServerProfiles) else { return }
        defaults.set(data, forKey: Keys.serverProfiles)
    }

    private func suggestedNewProfileName() -> String {
        var index = max(cachedServerProfiles.count + 1, 2)

        while true {
            let candidate = "Server \(index)"
            let isTaken = cachedServerProfiles.contains {
                $0.displayName.localizedCaseInsensitiveCompare(candidate) == .orderedSame
            }

            if isTaken == false {
                return candidate
            }

            index += 1
        }
    }

    private static func loadOrMigrateServerProfiles(
        defaults: UserDefaults,
        keychain: KeychainClient
    ) -> PersistedServerProfileState {
        if
            let data = defaults.data(forKey: Keys.serverProfiles),
            let decodedProfiles = try? JSONDecoder().decode([ServerProfile].self, from: data),
            decodedProfiles.isEmpty == false
        {
            let activeProfileID = resolvedActiveProfileID(
                storedProfileID: defaults.string(forKey: Keys.activeServerProfileID),
                profiles: decodedProfiles
            )

            defaults.set(activeProfileID, forKey: Keys.activeServerProfileID)
            return PersistedServerProfileState(
                profiles: decodedProfiles,
                activeProfileID: activeProfileID
            )
        }

        let migratedProfile = migratedLegacyServerProfile(defaults: defaults)
        let migratedProfiles = [migratedProfile]
        let legacyToken = loadLegacyToken(defaults: defaults, keychain: keychain)

        if legacyToken.isEmpty == false {
            _ = keychain.saveToken(legacyToken, migratedProfile.id)
        }

        defaults.removeObject(forKey: Keys.legacyServerURL)
        defaults.removeObject(forKey: Keys.legacyAPIToken)
        _ = keychain.deleteLegacyToken()

        let encoder = JSONEncoder()
        if let data = try? encoder.encode(migratedProfiles) {
            defaults.set(data, forKey: Keys.serverProfiles)
        }
        defaults.set(migratedProfile.id, forKey: Keys.activeServerProfileID)

        return PersistedServerProfileState(
            profiles: migratedProfiles,
            activeProfileID: migratedProfile.id
        )
    }

    private static func migratedLegacyServerProfile(defaults: UserDefaults) -> ServerProfile {
        let legacyURL = defaults.string(forKey: Keys.legacyServerURL)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let name = profileName(for: legacyURL, fallback: ServerProfile.defaultName)

        return ServerProfile(
            name: name,
            serverURL: legacyURL
        )
    }

    private static func loadLegacyToken(defaults: UserDefaults, keychain: KeychainClient) -> String {
        let keychainToken = keychain.loadLegacyToken().trimmingCharacters(in: .whitespacesAndNewlines)
        if keychainToken.isEmpty == false {
            return keychainToken
        }

        return defaults.string(forKey: Keys.legacyAPIToken)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private static func resolvedActiveProfileID(
        storedProfileID: String?,
        profiles: [ServerProfile]
    ) -> String {
        if let storedProfileID, profiles.contains(where: { $0.id == storedProfileID }) {
            return storedProfileID
        }

        return profiles.first?.id ?? defaultServerProfile().id
    }

    private static func defaultServerProfile() -> ServerProfile {
        ServerProfile()
    }

    private static func profileName(for serverURL: String, fallback: String) -> String {
        guard
            serverURL.isEmpty == false,
            let url = URL(string: serverURL),
            let host = url.host
        else {
            return fallback
        }

        if host == "127.0.0.1" || host == "localhost" {
            return "Local Server"
        }

        return host
    }
}

private struct PersistedServerProfileState {
    let profiles: [ServerProfile]
    let activeProfileID: String
}

enum UploadConfigurationState {
    case ready(AppSettings)
    case notConfigured
    case invalid(ClipforgeError)
}

extension Notification.Name {
    static let clipforgeHotkeyDidChange = Notification.Name("clipforge.hotkeyDidChange")
}
