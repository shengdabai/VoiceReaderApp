import XCTest
@testable import VoiceReaderApp

final class RemoteCloneSessionTests: XCTestCase {
    func testRemoteCloneStartsDisabledWithoutPersistedContentOrKey() async {
        let session = RemoteCloneSession()

        let configuration = await session.current()

        XCTAssertEqual(configuration, .disabled)
        XCTAssertNil(configuration.endpoint)
        XCTAssertNil(configuration.apiKey)
    }

    func testRemoteCloneRequiresHTTPSAndCanBeDisabled() async throws {
        let session = RemoteCloneSession()

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
