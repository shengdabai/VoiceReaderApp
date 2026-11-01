import XCTest
@testable import VoiceReaderApp

final class RemoteCloneSessionTests: XCTestCase {
    /// In-memory stand-in for the Keychain.
    private final class FakeKeyStore {
        var value: String?
        var saveCalls = 0

        var store: RemoteCloneKeyStore {
            RemoteCloneKeyStore(
                load: { self.value },
                save: { newValue in
                    self.saveCalls += 1
                    self.value = (newValue?.isEmpty ?? true) ? nil : newValue
                }
            )
        }
    }

    func testLegacyPersistedEndpointAndKeyAreRemovedOnStartup() {
        let suiteName = "RemoteCloneSessionTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Could not create isolated UserDefaults suite")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("https://legacy.example/tts", forKey: "remote_clone_endpoint")
        defaults.set("legacy-test-key", forKey: "remote_clone_api_key")

        _ = RemoteCloneSession(userDefaults: defaults, keyStore: FakeKeyStore().store)

        XCTAssertNil(defaults.object(forKey: "remote_clone_endpoint"))
        XCTAssertNil(defaults.object(forKey: "remote_clone_api_key"))
    }

    func testStartupKeepsTheKeychainAPIKey() async {
        let keys = FakeKeyStore()
        keys.value = "saved-key"

        let session = RemoteCloneSession(keyStore: keys.store)

        let stored = await session.storedAPIKey()
        XCTAssertEqual(stored, "saved-key")
        XCTAssertEqual(keys.saveCalls, 0)
        XCTAssertEqual(RemoteCloneKeyStore.keychainAccount, "remote_clone_api_key")
    }

    func testRemoteCloneStartsDisabledEvenWithASavedKey() async {
        let keys = FakeKeyStore()
        keys.value = "saved-key"
        let session = RemoteCloneSession(keyStore: keys.store)

        let configuration = await session.current()

        XCTAssertEqual(configuration, .disabled)
        XCTAssertNil(configuration.endpoint)
        XCTAssertNil(configuration.apiKey)
    }

    func testConfigureSavesTheTrimmedKeyAndForgetDeletesIt() async throws {
        let keys = FakeKeyStore()
        let session = RemoteCloneSession(keyStore: keys.store)

        try await session.configure(endpointText: "https://example.com/tts", apiKey: "  test-key \n")
        XCTAssertEqual(keys.value, "test-key")

        await session.disable()
        let afterDisable = await session.storedAPIKey()
        XCTAssertEqual(afterDisable, "test-key", "Disabling remote reading keeps the saved key")

        await session.forgetStoredAPIKey()
        let afterForget = await session.storedAPIKey()
        XCTAssertNil(afterForget)
    }

    func testRejectedConfigurationDoesNotSaveTheKey() async {
        let keys = FakeKeyStore()
        let session = RemoteCloneSession(keyStore: keys.store)

        do {
            try await session.configure(endpointText: "http://example.com/tts", apiKey: "test-key")
            XCTFail("HTTP endpoint should not be accepted")
        } catch {}

        XCTAssertNil(keys.value)
        XCTAssertEqual(keys.saveCalls, 0)
    }

    func testRemoteCloneRequiresHTTPSAndCanBeDisabled() async throws {
        let session = RemoteCloneSession(keyStore: FakeKeyStore().store)

        do {
            try await session.configure(endpointText: "http://example.com/tts", apiKey: "test-key")
            XCTFail("HTTP endpoint should not be accepted")
        } catch let error as RemoteCloneConfigurationError {
            guard case .secureEndpointRequired = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }

        try await session.configure(endpointText: "https://example.com/tts", apiKey: "test-key")
        let enabledConfiguration = await session.current()
        XCTAssertTrue(enabledConfiguration.enabled)

        await session.disable()
        let disabledConfiguration = await session.current()
        XCTAssertEqual(disabledConfiguration, .disabled)
    }
}
