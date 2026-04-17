import Combine
import Foundation

@MainActor
final class LibraryViewModel: ObservableObject {
    @Published private(set) var books: [Book] = []
    @Published var isImporting = false
    @Published var importErrorMessage: String?

    private let importer: DocumentImporter
    private let bookStore: BookStore

    init(importer: DocumentImporter, bookStore: BookStore) {
        self.importer = importer
        self.bookStore = bookStore
        reload()
    }

    func reload() {
        books = bookStore.loadBooks()
    }

    func importFile(at url: URL) async {
        isImporting = true
        defer { isImporting = false }

        do {
            let imported = try importer.importLocalFile(at: url)
            _ = try bookStore.addBook(from: imported)
            reload()
        } catch {
            importErrorMessage = error.localizedDescription
        }
    }

    func importFromArticleURL(_ text: String) async {
        guard let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            importErrorMessage = "链接格式无效。"
            return
        }

        isImporting = true
        defer { isImporting = false }

        do {
            let imported = try await importer.importArticle(from: url)
            _ = try bookStore.addBook(from: imported)
            reload()
        } catch {
            importErrorMessage = error.localizedDescription
        }
    }

    func handleIncomingURL(_ url: URL) async {
        if url.isFileURL {
            await importFile(at: url)
            return
        }

        if let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) {
            await importFromArticleURL(url.absoluteString)
        }
    }
}
