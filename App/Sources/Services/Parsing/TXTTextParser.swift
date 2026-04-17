import Foundation

struct TXTTextParser: TextParser {
    func parse(from fileURL: URL) throws -> [String] {
        let raw = try String(contentsOf: fileURL, encoding: .utf8)
        let paragraphs = normalizeParagraphs(from: raw)
        if paragraphs.isEmpty {
            throw TextParsingError.noExtractedText
        }

        return paragraphs
    }
}
