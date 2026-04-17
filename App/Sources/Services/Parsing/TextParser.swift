import Foundation

protocol TextParser {
    func parse(from fileURL: URL) throws -> [String]
}

enum TextParsingError: LocalizedError {
    case noExtractedText

    var errorDescription: String? {
        switch self {
        case .noExtractedText:
            return "无法从文件中提取可朗读文本。"
        }
    }
}

func normalizeParagraphs(from text: String) -> [String] {
    text
        .replacingOccurrences(of: "\r", with: "\n")
        .components(separatedBy: CharacterSet.newlines)
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
}
