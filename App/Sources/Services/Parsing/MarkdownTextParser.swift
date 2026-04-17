import Foundation

struct MarkdownTextParser: TextParser {
    func parse(from fileURL: URL) throws -> [String] {
        let raw = try String(contentsOf: fileURL, encoding: .utf8)

        let rendered: String
        if let attributed = try? AttributedString(markdown: raw) {
            rendered = String(attributed.characters)
        } else {
            rendered = raw
        }

        let paragraphs = normalizeParagraphs(from: rendered)
        if paragraphs.isEmpty {
            throw TextParsingError.noExtractedText
        }

        return paragraphs
    }
}
