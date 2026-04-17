import Foundation

final class ReadingProgressStore {
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func savePosition(_ position: ReadingPosition, for bookID: UUID) {
        let key = keyForBook(bookID)
        if let data = try? encoder.encode(position) {
            defaults.set(data, forKey: key)
        }
    }

    func loadPosition(for bookID: UUID) -> ReadingPosition {
        let key = keyForBook(bookID)
        guard let data = defaults.data(forKey: key),
              let position = try? decoder.decode(ReadingPosition.self, from: data) else {
            return .zero
        }

        return position
    }

    private func keyForBook(_ bookID: UUID) -> String {
        "reading.position.\(bookID.uuidString)"
    }
}
