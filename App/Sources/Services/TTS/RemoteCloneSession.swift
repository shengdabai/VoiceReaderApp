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

/// Where the remote API key lives between launches. Injectable for tests.
struct RemoteCloneKeyStore {
    /// Keychain account holding the API key (device-only, not synced).
    static let keychainAccount = "remote_clone_api_key"

    let load: () -> String?
    /// Stores the key, or deletes it when nil or empty.
    let save: (String?) -> Void

    static let keychain = RemoteCloneKeyStore(
        load: { KeychainStore().string(for: keychainAccount) },
        save: { KeychainStore().set($0, for: keychainAccount) }
    )
}

/// Opt-in remote configuration. Remote reading is enabled for the current
/// launch only and the endpoint is kept in memory; the API key is kept in the
/// Keychain so it does not have to be re-entered after every launch.
/// Reading content and credentials are never written to UserDefaults.
actor RemoteCloneSession {
    private static let legacyPersistedKeys = [
        "remote_clone_endpoint",
        "remote_clone_api_key",
    ]

    private let keyStore: RemoteCloneKeyStore
    private var configuration: RemoteCloneConfiguration = .disabled

    /// Deletes the plaintext endpoint and API key that earlier builds wrote to
    /// UserDefaults. The Keychain entry is kept.
    init(userDefaults: UserDefaults = .standard, keyStore: RemoteCloneKeyStore = .keychain) {
        for key in Self.legacyPersistedKeys {
            userDefaults.removeObject(forKey: key)
        }
        self.keyStore = keyStore
    }

    func current() -> RemoteCloneConfiguration {
        configuration
    }

    /// The API key saved in the Keychain by an earlier `configure`, if any.
    func storedAPIKey() -> String? {
        keyStore.load()
    }

    /// Deletes the saved API key. Remote reading that is already enabled for
    /// this launch keeps working until it is disabled.
    func forgetStoredAPIKey() {
        keyStore.save(nil)
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
        keyStore.save(normalizedKey)
    }

    func disable() {
        configuration = .disabled
    }
}
