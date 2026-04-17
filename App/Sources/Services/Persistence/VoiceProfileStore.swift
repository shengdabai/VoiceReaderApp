import Combine
import Foundation

final class VoiceProfileStore: ObservableObject {
    @Published private(set) var profiles: [VoiceProfile] = []
    @Published var selectedProfileID: UUID?

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private let profilesKey = "voice.profiles"
    private let selectedKey = "voice.selected.profile"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.profiles = loadProfiles()
        self.selectedProfileID = loadSelectedProfileID()
    }

    func upsert(_ profile: VoiceProfile) {
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
        } else {
            profiles.append(profile)
        }
        persistProfiles()
    }

    func delete(_ profileID: UUID) {
        profiles.removeAll { $0.id == profileID }
        if selectedProfileID == profileID {
            selectedProfileID = nil
            defaults.removeObject(forKey: selectedKey)
        }
        persistProfiles()
    }

    func setSelectedProfile(_ profileID: UUID?) {
        selectedProfileID = profileID
        if let profileID {
            defaults.set(profileID.uuidString, forKey: selectedKey)
        } else {
            defaults.removeObject(forKey: selectedKey)
        }
    }

    func selectedProfile() -> VoiceProfile? {
        guard let selectedProfileID else { return nil }
        return profiles.first(where: { $0.id == selectedProfileID })
    }

    private func loadProfiles() -> [VoiceProfile] {
        guard let data = defaults.data(forKey: profilesKey),
              let profiles = try? decoder.decode([VoiceProfile].self, from: data) else {
            return []
        }
        return profiles
    }

    private func loadSelectedProfileID() -> UUID? {
        guard let raw = defaults.string(forKey: selectedKey) else { return nil }
        return UUID(uuidString: raw)
    }

    private func persistProfiles() {
        guard let data = try? encoder.encode(profiles) else { return }
        defaults.set(data, forKey: profilesKey)
    }
}
