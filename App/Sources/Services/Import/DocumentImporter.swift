import Foundation

final class DocumentImporter {
    private let fileManager: FileManager
    private let urlExtractor: URLArticleExtractor
    private let booksRoot: URL

    init(fileManager: FileManager = .default, urlExtractor: URLArticleExtractor = URLArticleExtractor()) {
        self.fileManager = fileManager
        self.urlExtractor = urlExtractor

        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.booksRoot = documents.appendingPathComponent("Books", isDirectory: true)

        if !fileManager.fileExists(atPath: booksRoot.path) {
            try? fileManager.createDirectory(at: booksRoot, withIntermediateDirectories: true)
        }
    }

    func importLocalFile(at sourceURL: URL) throws -> ImportedDocument {
        guard let format = BookFormat.from(fileExtension: sourceURL.pathExtension) else {
            throw ImportError.unsupportedFormat
        }

        let title = sourceURL.deletingPathExtension().lastPathComponent
        let destination = booksRoot
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(sourceURL.pathExtension.lowercased())

        let scoped = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if scoped { sourceURL.stopAccessingSecurityScopedResource() }
        }

        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: sourceURL, to: destination)

        return ImportedDocument(title: title, format: format, localURL: destination)
    }

    func importArticle(from remoteURL: URL) async throws -> ImportedDocument {
        let article = try await urlExtractor.extractArticle(from: remoteURL)
        let safeTitle = article.title.replacingOccurrences(
            of: "[^a-zA-Z0-9\\u4e00-\\u9fa5_-]",
            with: "-",
            options: .regularExpression
        )
        let normalizedTitle = safeTitle.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let destination = booksRoot
            .appendingPathComponent("\(UUID().uuidString)-\(normalizedTitle.isEmpty ? "article" : normalizedTitle)")
            .appendingPathExtension("txt")

        try article.text.write(to: destination, atomically: true, encoding: .utf8)
        return ImportedDocument(title: article.title, format: .txt, localURL: destination)
    }
}

enum ImportError: LocalizedError {
    case unsupportedFormat

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return "暂不支持该文件格式。"
        }
    }
}
