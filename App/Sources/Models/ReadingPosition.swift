import Foundation

struct ReadingPosition: Codable, Equatable {
    var paragraphIndex: Int
    var offsetInParagraph: Int
    var updatedAt: Date

    static let zero = ReadingPosition(paragraphIndex: 0, offsetInParagraph: 0, updatedAt: Date())
}
