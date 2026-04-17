import Foundation

enum VoiceProviderType: String, Codable, CaseIterable, Identifiable {
    case local
    case remoteClone

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .local:
            return "本地离线"
        case .remoteClone:
            return "远程克隆"
        }
    }
}

struct VoiceProfile: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var providerType: VoiceProviderType
    var remoteVoiceID: String?
    var sampleFiles: [URL]
    var preferredLanguage: AppLanguage
    var createdAt: Date
}
