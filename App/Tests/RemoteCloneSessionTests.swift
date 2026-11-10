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

    func testRejectsCredentialsAndFragmentsInEndpoint() async {
        for endpoint in ["https://user:password@example.com/tts", "https://example.com/tts#other"] {
            let keys = FakeKeyStore()
            let session = RemoteCloneSession(keyStore: keys.store)
            do {
                try await session.configure(endpointText: endpoint, apiKey: "test-key")
                XCTFail("Ambiguous endpoint must be rejected")
            } catch {}
            let current = await session.current()
            XCTAssertEqual(current, .disabled)
            XCTAssertEqual(keys.saveCalls, 0)
        }
    }

    func testRejectsControlCharactersInAuthorizationValue() async {
        for key in ["test\r\nInjected: value", "test\u{0}key", "test\u{7F}key"] {
            let keys = FakeKeyStore()
            let session = RemoteCloneSession(keyStore: keys.store)
            do {
                try await session.configure(endpointText: "https://example.com/tts", apiKey: key)
                XCTFail("Header control characters must be rejected")
            } catch {}
            XCTAssertEqual(keys.saveCalls, 0)
        }
    }
}

final class RemoteCloneProviderTests: XCTestCase {
    func testRedirectsCannotReplayReadingContent() throws {
        let session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }
        let source = URL(string: "https://tts.example/voice")!
        let task = session.dataTask(with: source)
        for status in [301, 302, 303, 307, 308] {
            for target in ["https://other.example/voice", "http://tts.example/voice", "https://tts.example/moved"] {
                let response = try XCTUnwrap(HTTPURLResponse(url: source, statusCode: status,
                                                           httpVersion: nil, headerFields: nil))
                let completed = expectation(description: "Reject redirect")
                RemoteCloneRedirectPolicy().urlSession(session, task: task,
                    willPerformHTTPRedirection: response, newRequest: URLRequest(url: URL(string: target)!)) {
                    XCTAssertNil($0, "Redirect must not forward the POST body or Authorization")
                    completed.fulfill()
                }
                wait(for: [completed], timeout: 1)
            }
        }
    }

    func testSynthesisSendsExpectedPayloadAndRejectsNonSuccessResponse() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RemoteAudioProtocol.self]
        let urlSession = URLSession(configuration: configuration)
        defer { urlSession.invalidateAndCancel() }
        let keys = RemoteCloneKeyStore(load: { nil }, save: { _ in })
        let remote = RemoteCloneSession(keyStore: keys)
        let provider = RemoteCloneProvider(session: urlSession, remoteCloneSession: remote)
        let voice = VoiceProfile(id: UUID(), name: "test", providerType: .remoteClone,
            remoteVoiceID: "voice", sampleFiles: [], preferredLanguage: .enUS, createdAt: Date())
        let request = SpeechRequest(text: "Private reading text", language: .enUS, speed: .x1_0, voiceProfile: voice)
        try await remote.configure(endpointText: "https://tts.tests.invalid/ok", apiKey: "test-key")
        let output = try await provider.synthesize(request)
        guard case .remoteAudioFile(let file) = output else { return XCTFail("Expected audio file") }
        defer { try? FileManager.default.removeItem(at: file) }
        XCTAssertEqual(try Data(contentsOf: file), Data("audio".utf8))

        for path in ["redirect", "error", "empty"] {
            try await remote.configure(endpointText: "https://tts.tests.invalid/\(path)", apiKey: "test-key")
            do {
                _ = try await provider.synthesize(request)
                XCTFail("Non-success or empty responses must fail")
            } catch SpeechSynthesisError.remoteFailed {} catch { XCTFail("Unexpected error: \(error)") }
        }
    }
}

private final class RemoteAudioProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "tts.tests.invalid" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-key")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Cache-Control"), "no-store")
        XCTAssertFalse(request.httpShouldHandleCookies)
        XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalCacheData)
        if let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var data = Data(), buffer = [UInt8](repeating: 0, count: 1024)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                guard count > 0 else { break }
                data.append(contentsOf: buffer.prefix(count))
            }
            let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            XCTAssertEqual(payload?["text"] as? String, "Private reading text")
            XCTAssertEqual(payload?["voiceId"] as? String, "voice")
        } else {
            XCTFail("Expected a JSON request body")
        }
        let path = request.url!.lastPathComponent
        let status = path == "redirect" ? 307 : (path == "error" ? 500 : 200)
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil,
                                       headerFields: ["Content-Type": "audio/mpeg"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if path != "empty" { client?.urlProtocol(self, didLoad: Data("audio".utf8)) }
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
