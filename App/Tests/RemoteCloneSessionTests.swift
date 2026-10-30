import XCTest
@testable import VoiceReaderApp

final class RemoteCloneSessionTests: XCTestCase {
    func testLegacyPersistedEndpointAndKeyAreRemovedOnStartup() {
        let suiteName = "RemoteCloneSessionTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Could not create isolated UserDefaults suite")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("https://legacy.example/tts", forKey: "remote_clone_endpoint")
        defaults.set("legacy-test-key", forKey: "remote_clone_api_key")

        _ = RemoteCloneSession(userDefaults: defaults, removeLegacyKeychainKey: {})

        XCTAssertNil(defaults.object(forKey: "remote_clone_endpoint"))
        XCTAssertNil(defaults.object(forKey: "remote_clone_api_key"))
    }

    func testLegacyKeychainAPIKeyIsRemovedOnStartup() {
        var removeCalls = 0

        _ = RemoteCloneSession(removeLegacyKeychainKey: { removeCalls += 1 })

        XCTAssertEqual(removeCalls, 1)
        XCTAssertEqual(RemoteCloneSession.legacyKeychainAPIKeyAccount, "remote_clone_api_key")
    }

    func testRemoteCloneStartsDisabledWithoutPersistedContentOrKey() async {
        let session = RemoteCloneSession(removeLegacyKeychainKey: {})

        let configuration = await session.current()

        XCTAssertEqual(configuration, .disabled)
        XCTAssertNil(configuration.endpoint)
        XCTAssertNil(configuration.apiKey)
    }

    func testRemoteCloneRequiresHTTPSAndCanBeDisabled() async throws {
        let session = RemoteCloneSession(removeLegacyKeychainKey: {})

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
