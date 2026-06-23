import Combine
import Foundation

@MainActor
final class ReaderViewModel: ObservableObject {
    @Published private(set) var paragraphs: [String] = []
    @Published var currentParagraphIndex = 0
    @Published var selectedLanguage: AppLanguage = .zhHans
    @Published var selectedSpeed: SpeedPreset = .x1_0
    @Published var errorMessage: String?
    @Published private(set) var playbackState: PlaybackState = .idle

    let book: Book

    private let parserFactory: ParserFactory
    private let progressStore: ReadingProgressStore
    private let playbackEngine: PlaybackEngine
    private let selectedVoiceProvider: () -> VoiceProfile?
    private var cancellables: Set<AnyCancellable> = []

    init(book: Book,
         parserFactory: ParserFactory,
         progressStore: ReadingProgressStore,
         playbackEngine: PlaybackEngine,
         selectedVoiceProvider: @escaping () -> VoiceProfile?) {
        self.book = book
        self.parserFactory = parserFactory
        self.progressStore = progressStore
        self.playbackEngine = playbackEngine
        self.selectedVoiceProvider = selectedVoiceProvider
        loadContent()
        restoreProgress()

        // Mirror the playback engine's state so the reader controls can show
        // the right buttons for idle / playing / paused.
        playbackEngine.$state
            .receive(on: DispatchQueue.main)
            .assign(to: \.playbackState, on: self)
            .store(in: &cancellables)
    }

    var currentParagraph: String {
        guard paragraphs.indices.contains(currentParagraphIndex) else { return "" }
        return paragraphs[currentParagraphIndex]
    }

    var isPlaying: Bool { playbackState == .playing }
    var isPaused: Bool { playbackState == .paused }

    func playCurrentParagraph() async {
        let paragraph = currentParagraph
        guard !paragraph.isEmpty else { return }

        let request = SpeechRequest(
            text: paragraph,
            language: selectedLanguage,
            speed: selectedSpeed,
            voiceProfile: selectedVoiceProvider()
        )

        await playbackEngine.play(request: request)
        persistProgress()
    }

    func pause() {
        playbackEngine.pause()
    }

    func resume() {
        playbackEngine.resume()
    }

    func stop() {
        playbackEngine.stop()
    }

    func nextParagraph() {
        guard currentParagraphIndex < paragraphs.count - 1 else { return }
        currentParagraphIndex += 1
        persistProgress()
    }

    func previousParagraph() {
        guard currentParagraphIndex > 0 else { return }
        currentParagraphIndex -= 1
        persistProgress()
    }

    private func loadContent() {
        do {
            let parser = parserFactory.parser(for: book.format)
            paragraphs = try parser.parse(from: book.fileURL)
        } catch {
            errorMessage = error.localizedDescription
            paragraphs = []
        }
    }

    private func restoreProgress() {
        let position = progressStore.loadPosition(for: book.id)
        if position.paragraphIndex < paragraphs.count {
            currentParagraphIndex = position.paragraphIndex
        }
    }

    private func persistProgress() {
        let position = ReadingPosition(
            paragraphIndex: currentParagraphIndex,
            offsetInParagraph: 0,
            updatedAt: Date()
        )
        progressStore.savePosition(position, for: book.id)
    }
}
