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
        // Keep the display title in metadata. A UUID avoids filename byte limits
        // for long titles, especially titles containing multibyte characters.
        let destination = booksRoot
            .appendingPathComponent(UUID().uuidString)
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
