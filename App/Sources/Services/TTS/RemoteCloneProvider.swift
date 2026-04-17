import Foundation

struct RemoteCloneProvider: SpeechProvider {
    private let session: URLSession
    private let userDefaults: UserDefaults

    private let endpointKey = "remote_clone_endpoint"
    private let apiKeyKey = "remote_clone_api_key"

    init(session: URLSession = .shared, userDefaults: UserDefaults = .standard) {
        self.session = session
        self.userDefaults = userDefaults
    }

    func synthesize(_ request: SpeechRequest) async throws -> SpeechOutput {
        guard request.voiceProfile?.providerType == .remoteClone else {
            throw SpeechSynthesisError.remoteUnsupported
        }

        guard let endpointText = userDefaults.string(forKey: endpointKey),
              let endpoint = URL(string: endpointText),
              !endpointText.isEmpty else {
            throw SpeechSynthesisError.remoteNotConfigured
        }

        let payload = RemotePayload(
            text: request.text,
            languageCode: request.language.rawValue,
            speed: request.speed.value,
            voiceID: request.voiceProfile?.remoteVoiceID
        )

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 30
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let apiKey = userDefaults.string(forKey: apiKeyKey), !apiKey.isEmpty {
            urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        urlRequest.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode), !data.isEmpty else {
            throw SpeechSynthesisError.remoteFailed
        }

        let outputURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("remote-\(UUID().uuidString).mp3")
        try data.write(to: outputURL, options: .atomic)

        return .remoteAudioFile(outputURL)
    }
}

private struct RemotePayload: Codable {
    var text: String
    var languageCode: String
    var speed: Float
    var voiceID: String?

    enum CodingKeys: String, CodingKey {
        case text
        case languageCode
        case speed
        case voiceID = "voiceId"
    }
}
