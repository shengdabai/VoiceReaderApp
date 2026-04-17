import Combine
import Foundation

@MainActor
final class AppEnvironment: ObservableObject {
    let importer: DocumentImporter
    let parserFactory: ParserFactory
    let bookStore: BookStore
    let progressStore: ReadingProgressStore
    let playbackEngine: PlaybackEngine
    let voiceProfileStore: VoiceProfileStore
    let voiceRecorder: VoiceRecorderService

    @Published var libraryViewModel: LibraryViewModel

    init() {
        self.importer = DocumentImporter()
        self.parserFactory = ParserFactory()
        self.bookStore = BookStore()
        self.progressStore = ReadingProgressStore()
        self.playbackEngine = PlaybackEngine()
        self.voiceProfileStore = VoiceProfileStore()
        self.voiceRecorder = VoiceRecorderService()

        self.libraryViewModel = LibraryViewModel(importer: importer, bookStore: bookStore)
    }

    func makeReaderViewModel(for book: Book) -> ReaderViewModel {
        ReaderViewModel(
            book: book,
            parserFactory: parserFactory,
            progressStore: progressStore,
            playbackEngine: playbackEngine,
            selectedVoiceProvider: { [weak voiceProfileStore] in
                voiceProfileStore?.selectedProfile()
            }
        )
    }
}
