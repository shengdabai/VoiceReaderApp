import Foundation

struct RemoteCloneProvider: SpeechProvider {
    private let session: URLSession
    private let remoteCloneSession: RemoteCloneSession

    init(session: URLSession = Self.privateSession, remoteCloneSession: RemoteCloneSession = RemoteCloneSession()) {
        self.session = session
        self.remoteCloneSession = remoteCloneSession
    }

    func synthesize(_ request: SpeechRequest) async throws -> SpeechOutput {
        guard request.voiceProfile?.providerType == .remoteClone else {
            throw SpeechSynthesisError.remoteUnsupported
        }

        let configuration = await remoteCloneSession.current()
        guard configuration.enabled,
              let endpoint = configuration.endpoint,
              let apiKey = configuration.apiKey else {
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
        urlRequest.httpShouldHandleCookies = false
        urlRequest.cachePolicy = .reloadIgnoringLocalCacheData
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("no-store", forHTTPHeaderField: "Cache-Control")

        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        urlRequest.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: urlRequest, delegate: RemoteCloneRedirectPolicy())
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode), !data.isEmpty else {
            throw SpeechSynthesisError.remoteFailed
        }

        let outputURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("remote-\(UUID().uuidString).mp3")
        try data.write(to: outputURL, options: .atomic)

        return .remoteAudioFile(outputURL)
    }

    private static let privateSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        return URLSession(configuration: configuration)
    }()
}

/// A redirect must not move reading content or credentials away from the
/// endpoint the user explicitly enabled, including HTTP 307/308 POST replays.
final class RemoteCloneRedirectPolicy: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
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
