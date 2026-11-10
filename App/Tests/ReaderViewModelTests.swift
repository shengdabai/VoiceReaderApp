import XCTest
@testable import VoiceReaderApp

@MainActor
final class ReaderViewModelTests: XCTestCase {
    func testPlaybackObservationDoesNotRetainReader() async throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".txt")
        try "A readable paragraph.".write(to: file, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: file) }
        let suite = "ReaderViewModelTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let engine = PlaybackEngine(driver: ReaderPlaybackDriver(), synthesize: { _ in
            .remoteAudioFile(file)
        }, removeAudioFile: { _ in })
        let book = Book(id: UUID(), title: "Test", format: .txt, fileURL: file, createdAt: Date())
        var model: ReaderViewModel? = ReaderViewModel(book: book, parserFactory: ParserFactory(),
            progressStore: ReadingProgressStore(defaults: defaults), playbackEngine: engine,
            selectedVoiceProvider: { nil })
        weak var releasedModel = model

        await model?.playCurrentParagraph()
        await flushMainQueue()
        XCTAssertEqual(model?.playbackState, .playing)
        engine.pause()
        await flushMainQueue()
        XCTAssertEqual(model?.playbackState, .paused)

        model = nil
        await flushMainQueue()
        XCTAssertNil(releasedModel, "Playback observation must release the reader and its parsed book")
    }

    private func flushMainQueue() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
    }
}

@MainActor
private final class ReaderPlaybackDriver: PlaybackDriving {
    var onCompletion: ((Bool) -> Void)?
    func start(_ output: SpeechOutput) throws {}
    func pause() {}
    func resume() -> Bool { true }
    func stop() {}
}
