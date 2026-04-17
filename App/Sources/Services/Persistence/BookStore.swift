import Foundation

final class BookStore {
    private let fileManager: FileManager
    private let catalogURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let directory = appSupport.appendingPathComponent("VoiceReader", isDirectory: true)

        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        self.catalogURL = directory.appendingPathComponent("books.json")
    }

    func loadBooks() -> [Book] {
        guard let data = try? Data(contentsOf: catalogURL),
              let books = try? decoder.decode([Book].self, from: data) else {
            return []
        }

        return books.sorted { $0.createdAt > $1.createdAt }
    }

    func addBook(from imported: ImportedDocument) throws -> Book {
        var books = loadBooks()
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
        var books = loadBooks()
        books.removeAll { $0.id == bookID }
        try save(books)
    }

    private func save(_ books: [Book]) throws {
        let data = try encoder.encode(books)
        try data.write(to: catalogURL, options: .atomic)
    }
}
