import Foundation

struct MarkdownTextParser: TextParser {
    func parse(from fileURL: URL) throws -> [String] {
        let raw = try String(contentsOf: fileURL, encoding: .utf8)

        let rendered: String
        if let attributed = try? AttributedString(markdown: raw) {
            // Full Markdown parsing stores block boundaries as presentation intents,
            // not newline characters. Preserve them for paragraph navigation.
            var text = ""
            var previousBlockID: Int?
            for run in attributed.runs {
                let blockID = run.presentationIntent?.components.first?.identity
                if !text.isEmpty, blockID != previousBlockID {
                    text.append("\n")
                }
                text.append(contentsOf: attributed[run.range].characters)
                previousBlockID = blockID
            }
            rendered = text
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
