import Foundation

final class BookStore {
    private let fileManager: FileManager
    private let catalogURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileManager: FileManager = .default, catalogURL: URL? = nil) {
        self.fileManager = fileManager
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let directory = appSupport.appendingPathComponent("VoiceReader", isDirectory: true)

        if catalogURL == nil && !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        self.catalogURL = catalogURL ?? directory.appendingPathComponent("books.json")
    }

    func loadBooks() throws -> [Book] {
        do {
            let data = try Data(contentsOf: catalogURL)
            let books = try decoder.decode([Book].self, from: data)
            return books.sorted { $0.createdAt > $1.createdAt }
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return []
        } catch {
            throw CatalogError.unreadable
        }
    }

    enum CatalogError: LocalizedError {
        case unreadable
        var errorDescription: String? {
            "书架记录无法读取，原始文件已保留。请恢复有效备份后重试；未覆盖现有书架。"
        }
    }

    func addBook(from imported: ImportedDocument) throws -> Book {
        var books = try loadBooks()
        let book = Book(
            id: UUID(),
            title: imported.title,
            format: imported.format,
            fileURL: imported.localURL,
            createdAt: Date()
        )
        books.insert(book, at: 0)
        try save(books)
        return book
    }

    func remove(bookID: UUID) throws {
        var books = try loadBooks()
        books.removeAll { $0.id == bookID }
        try save(books)
    }

    private func save(_ books: [Book]) throws {
        let data = try encoder.encode(books)
        try data.write(to: catalogURL, options: .atomic)
    }
}
