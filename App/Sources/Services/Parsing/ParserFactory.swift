import Foundation

struct ParserFactory {
    func parser(for format: BookFormat) -> TextParser {
        switch format {
        case .pdf:
            return PDFTextParser()
        case .epub:
            return EpubTextParser()
        case .markdown:
            return MarkdownTextParser()
        case .txt:
            return TXTTextParser()
        }
    }
}
