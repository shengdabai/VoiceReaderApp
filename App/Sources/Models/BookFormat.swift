import Foundation

enum BookFormat: String, Codable, CaseIterable {
    case pdf
    case epub
    case markdown
    case txt

    static func from(fileExtension ext: String) -> BookFormat? {
        switch ext.lowercased() {
        case "pdf": return .pdf
        case "epub": return .epub
        case "md", "markdown": return .markdown
        case "txt": return .txt
        default: return nil
        }
    }
}
