import Foundation

struct Book: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var format: BookFormat
    var fileURL: URL
    var createdAt: Date
}
