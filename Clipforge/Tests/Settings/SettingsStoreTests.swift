import Foundation
import XCTest
@testable import Clipforge

@MainActor
final class SettingsStoreTests: XCTestCase {
    func testBlankDefaultProfileStartsAsNotConfigured() {
        let store = makeStore()

        switch store.uploadConfigurationState() {
        case .notConfigured:
            break
        default:
            XCTFail("Expected a blank default profile to be treated as not configured")
        }
    }

    func testMigratesLegacyServerSettingsIntoNamedProfile() {
        let defaults = makeDefaults(suiteName: #function)
        defaults.set("https://uploads.example.com", forKey: "settings.serverURL")
        defaults.set("legacy-token-from-defaults", forKey: "settings.apiToken")

        let keychain = FakeKeychain()
        keychain.legacyToken = "legacy-token-from-keychain"

        let store = SettingsStore(defaults: defaults, keychain: keychain.client)

        XCTAssertEqual(store.serverProfiles.count, 1)
        XCTAssertEqual(store.activeServerProfileDisplayName, "uploads.example.com")
        XCTAssertEqual(store.serverURL, "https://uploads.example.com")
        XCTAssertEqual(store.apiToken, "legacy-token-from-keychain")
        XCTAssertEqual(keychain.tokens[store.activeServerProfileID], "legacy-token-from-keychain")
        XCTAssertNil(defaults.string(forKey: "settings.serverURL"))
        XCTAssertNil(defaults.string(forKey: "settings.apiToken"))
        XCTAssertTrue(keychain.didDeleteLegacyToken)
    }

    func testCreatingAndDeletingProfilesKeepsSelectionConsistent() {
        let keychain = FakeKeychain()
        let store = makeStore(keychain: keychain)
        let originalProfileID = store.activeServerProfileID

        store.activeServerProfileName = "Personal"
        store.serverURL = "https://personal.example.com"
        store.apiToken = "personal-token"

        store.createServerProfile()
        let workProfileID = store.activeServerProfileID

        XCTAssertEqual(store.serverProfiles.count, 2)
        XCTAssertNotEqual(workProfileID, originalProfileID)

        store.activeServerProfileName = "Work"
        store.serverURL = "https://work.example.com"
        store.apiToken = "work-token"
        XCTAssertEqual(keychain.tokens[workProfileID], "work-token")

        store.deleteActiveServerProfile()

        XCTAssertEqual(store.serverProfiles.count, 1)
        XCTAssertEqual(store.activeServerProfileID, originalProfileID)
        XCTAssertEqual(store.activeServerProfileDisplayName, "Personal")
        XCTAssertEqual(store.serverURL, "https://personal.example.com")
        XCTAssertEqual(store.apiToken, "personal-token")
        XCTAssertNil(keychain.tokens[workProfileID])
    }

    func testCurrentSettingsFollowTheSelectedProfile() {
        let keychain = FakeKeychain()
        let store = makeStore(keychain: keychain)

        store.activeServerProfileName = "Personal"
        store.serverURL = "https://personal.example.com"
        store.apiToken = "personal-token"

        store.createServerProfile()
        let workProfileID = store.activeServerProfileID
        store.activeServerProfileName = "Work"
        store.serverURL = "https://work.example.com"
        store.apiToken = "work-token"

        XCTAssertEqual(store.currentSettings.serverURL, "https://work.example.com")
        XCTAssertEqual(store.currentSettings.apiToken, "work-token")

        store.activeServerProfileID = workProfileID
        XCTAssertEqual(store.currentSettings.serverURL, "https://work.example.com")
        XCTAssertEqual(store.currentSettings.apiToken, "work-token")

        let personalProfileID = store.serverProfiles.first(where: { $0.displayName == "Personal" })?.id
        XCTAssertNotNil(personalProfileID)

        if let personalProfileID {
            store.activeServerProfileID = personalProfileID
        }

        XCTAssertEqual(store.currentSettings.serverURL, "https://personal.example.com")
        XCTAssertEqual(store.currentSettings.apiToken, "personal-token")
    }

    private func makeStore(
        suiteName: String = #function,
        keychain: FakeKeychain = FakeKeychain()
    ) -> SettingsStore {
        SettingsStore(defaults: makeDefaults(suiteName: suiteName), keychain: keychain.client)
    }

    private func makeDefaults(suiteName: String) -> UserDefaults {
        let suite = "Clipforge.SettingsStoreTests.\(suiteName)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}

private final class FakeKeychain: @unchecked Sendable {
    var tokens: [String: String] = [:]
    var legacyToken = ""
    var didDeleteLegacyToken = false

    var client: KeychainClient {
        KeychainClient(
            loadToken: { [weak self] profileID in
                self?.tokens[profileID] ?? ""
            },
            saveToken: { [weak self] token, profileID in
                self?.tokens[profileID] = token
                return true
            },
            deleteToken: { [weak self] profileID in
                self?.tokens.removeValue(forKey: profileID)
                return true
            },
            loadLegacyToken: { [weak self] in
                self?.legacyToken ?? ""
            },
            deleteLegacyToken: { [weak self] in
                self?.didDeleteLegacyToken = true
                self?.legacyToken = ""
                return true
            }
        )
    }
}
