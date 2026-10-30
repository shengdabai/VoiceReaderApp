import Foundation

struct RemoteCloneConfiguration: Equatable {
    let enabled: Bool
    let endpoint: URL?
    let apiKey: String?

    static let disabled = RemoteCloneConfiguration(enabled: false, endpoint: nil, apiKey: nil)
}

enum RemoteCloneConfigurationError: LocalizedError {
    case secureEndpointRequired
    case apiKeyRequired

    var errorDescription: String? {
        switch self {
        case .secureEndpointRequired:
            return "远程服务必须使用有效的 HTTPS 地址。"
        case .apiKeyRequired:
            return "本次启动启用远程服务时必须输入 API Key。"
        }
    }
}

/// Volatile, opt-in configuration for the current app launch only.
/// Reading content and credentials are intentionally never written to UserDefaults.
actor RemoteCloneSession {
    private static let legacyPersistedKeys = [
        "remote_clone_endpoint",
        "remote_clone_api_key",
    ]

    /// Keychain account that an interim build used to persist the API key.
    static let legacyKeychainAPIKeyAccount = "remote_clone_api_key"

    private var configuration: RemoteCloneConfiguration = .disabled

    /// - Parameter removeLegacyKeychainKey: deletes the API key that an
    ///   interim build persisted in the Keychain. Injectable for tests.
    init(
        userDefaults: UserDefaults = .standard,
        removeLegacyKeychainKey: () -> Void = {
            KeychainStore().delete(RemoteCloneSession.legacyKeychainAPIKeyAccount)
        }
    ) {
        for key in Self.legacyPersistedKeys {
            userDefaults.removeObject(forKey: key)
        }
        removeLegacyKeychainKey()
    }

    func current() -> RemoteCloneConfiguration {
        configuration
    }

    func configure(endpointText: String, apiKey: String) throws {
        let normalizedEndpoint = endpointText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let endpoint = URL(string: normalizedEndpoint),
              endpoint.scheme?.lowercased() == "https",
              endpoint.host != nil else {
            throw RemoteCloneConfigurationError.secureEndpointRequired
        }

        let normalizedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedKey.isEmpty else {
            throw RemoteCloneConfigurationError.apiKeyRequired
        }

        configuration = RemoteCloneConfiguration(
            enabled: true,
            endpoint: endpoint,
            apiKey: normalizedKey
        )
    }

    func disable() {
        configuration = .disabled
    }
}
