import Foundation
import ZIPFoundation

struct EpubTextParser: TextParser {
    func parse(from fileURL: URL) throws -> [String] {
        guard let archive = Archive(url: fileURL, accessMode: .read) else {
            throw TextParsingError.noExtractedText
        }

        var chapterTexts: [String] = []
        let entries = archive
            .filter { entry in
                let path = entry.path.lowercased()
                return path.hasSuffix(".xhtml") || path.hasSuffix(".html") || path.hasSuffix(".htm")
            }
            // Numeric-aware ordering so chapter files like "2.xhtml" sort
            // before "10.xhtml" instead of using pure lexicographic order.
            // (A full content.opf spine parse would be more correct, but this
            // matches the common zero/number-prefixed chapter naming scheme.)
            .sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }

        for entry in entries {
            var data = Data()
            _ = try archive.extract(entry) { chunk in
                data.append(chunk)
            }
            if let html = String(data: data, encoding: .utf8) {
                let plainText = stripHTML(html)
                chapterTexts.append(plainText)
            }
        }

        let combined = chapterTexts.joined(separator: "\n")
        let paragraphs = normalizeParagraphs(from: combined)
        if paragraphs.isEmpty {
            throw TextParsingError.noExtractedText
        }

        return paragraphs
    }

    private func stripHTML(_ html: String) -> String {
        html.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
    }
}
