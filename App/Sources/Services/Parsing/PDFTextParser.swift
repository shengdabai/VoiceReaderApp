import Foundation
import PDFKit

struct PDFTextParser: TextParser {
    func parse(from fileURL: URL) throws -> [String] {
        guard let document = PDFDocument(url: fileURL) else {
            throw TextParsingError.noExtractedText
        }

        var merged = ""
        for pageIndex in 0 ..< document.pageCount {
            if let pageText = document.page(at: pageIndex)?.string {
                merged.append(pageText)
                merged.append("\n")
            }
        }

        let paragraphs = normalizeParagraphs(from: merged)
        if paragraphs.isEmpty {
            throw TextParsingError.noExtractedText
        }

        return paragraphs
    }
}
