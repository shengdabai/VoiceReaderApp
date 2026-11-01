import XCTest
@testable import VoiceReaderApp

@MainActor
final class PlaybackEngineTests: XCTestCase {
    private let output = SpeechOutput.remoteAudioFile(URL(fileURLWithPath: "/fixture-audio.mp3"))
    private func request(_ text: String = "first") -> SpeechRequest {
        SpeechRequest(text: text, language: .enUS, speed: .x2_0, voiceProfile: nil)
    }

    func testStopDiscardsDelayedSynthesis() async {
        let source = DeferredSpeech(), driver = FakePlaybackDriver()
        let engine = PlaybackEngine(driver: driver, synthesize: source.synthesize)
        let task = Task { await engine.play(request: request()) }
        await source.waitForRequest("first")
        engine.stop()
        source.finish("first", with: output)
        await task.value
        XCTAssertEqual(driver.starts, 0)
        XCTAssertEqual(engine.state, .idle)
    }

    func testStaleRemoteResultDeletesItsTempFile() async {
        let source = DeferredSpeech(), driver = FakePlaybackDriver()
        var removed: [URL] = []
        let engine = PlaybackEngine(driver: driver, synthesize: source.synthesize,
                                    removeAudioFile: { removed.append($0) })
        let task = Task { await engine.play(request: request()) }
        await source.waitForRequest("first")
        engine.stop()
        source.finish("first", with: output)
        await task.value
        XCTAssertEqual(driver.starts, 0)
        XCTAssertEqual(removed, [URL(fileURLWithPath: "/fixture-audio.mp3")])
    }

    func testLatestPlayWinsWhenResultsArriveOutOfOrder() async {
        let source = DeferredSpeech(), driver = FakePlaybackDriver()
        let engine = PlaybackEngine(driver: driver, synthesize: source.synthesize)
        let first = Task { await engine.play(request: request()) }
        await source.waitForRequest("first")
        let second = Task { await engine.play(request: request("second")) }
        await source.waitForRequest("second")
        source.finish("second", with: output)
        await second.value
        source.finish("first", with: output)
        await first.value
        XCTAssertEqual(driver.starts, 1)
        XCTAssertEqual(engine.state, .playing)
    }

    func testPauseDiscardsPendingSynthesis() async {
        let source = DeferredSpeech(), driver = FakePlaybackDriver()
        let engine = PlaybackEngine(driver: driver, synthesize: source.synthesize)
        let task = Task { await engine.play(request: request()) }
        await source.waitForRequest("first")
        engine.pause()
        source.finish("first", with: output)
        await task.value
        engine.resume()
        XCTAssertEqual(driver.starts, 0)
        XCTAssertEqual(driver.resumes, 0)
    }

    func testCancelledTaskDoesNotStartAudio() async {
        let source = DeferredSpeech(), driver = FakePlaybackDriver()
        let engine = PlaybackEngine(driver: driver, synthesize: source.synthesize)
        let task = Task { await engine.play(request: request()) }
        await source.waitForRequest("first")
        task.cancel()
        source.finish("first", with: output)
        await task.value
        XCTAssertEqual(driver.starts, 0)
    }

    func testOldCompletionCannotResetNewPlayback() async {
        let driver = FakePlaybackDriver()
        let engine = PlaybackEngine(driver: driver, synthesize: { _ in self.output })
        await engine.play(request: request())
        let oldCompletion = driver.onCompletion
        await engine.play(request: request("second"))
        oldCompletion?(true)
        XCTAssertEqual(engine.state, .playing)
        XCTAssertEqual(driver.stops, 2)
        driver.onCompletion?(false)
        guard case .failed = engine.state else { return XCTFail("Decode failure must be visible") }
    }

    func testSessionFailurePreventsSynthesis() async {
        let driver = FakePlaybackDriver()
        var synthesized = false
        let engine = PlaybackEngine(driver: driver, synthesize: { _ in
            synthesized = true
            return self.output
        }, configureAudioSession: { throw CocoaError(.fileReadUnknown) })
        await engine.play(request: request())
        XCTAssertFalse(synthesized)
        XCTAssertEqual(driver.starts, 0)
        guard case .failed = engine.state else { return XCTFail("Expected failed state") }
    }

    func testPauseResumeAndStopRespectActualOutput() async {
        let driver = FakePlaybackDriver()
        let engine = PlaybackEngine(driver: driver, synthesize: { _ in self.output })
        engine.resume()
        XCTAssertEqual(engine.state, .idle)
        await engine.play(request: request())
        engine.pause()
        XCTAssertEqual(engine.state, .paused)
        driver.canResume = false
        engine.resume()
        XCTAssertEqual(engine.state, .paused)
        driver.canResume = true
        engine.resume()
        XCTAssertEqual(engine.state, .playing)
        driver.onCompletion?(true)
        XCTAssertEqual(engine.state, .idle)
        engine.stop()
        engine.resume()
        XCTAssertEqual(engine.state, .idle)
    }
}

@MainActor
private final class FakePlaybackDriver: PlaybackDriving {
    var onCompletion: ((Bool) -> Void)?
    var starts = 0, stops = 0, resumes = 0
    var canResume = true
    func start(_ output: SpeechOutput) throws { starts += 1 }
    func pause() {}
    func resume() -> Bool { resumes += 1; return canResume }
    func stop() { stops += 1 }
}

@MainActor
private final class DeferredSpeech {
    private var pending: [String: CheckedContinuation<SpeechOutput, Never>] = [:]
    private var waiters: [String: CheckedContinuation<Void, Never>] = [:]
    func synthesize(_ request: SpeechRequest) async -> SpeechOutput {
        await withCheckedContinuation { continuation in
            pending[request.text] = continuation
            waiters.removeValue(forKey: request.text)?.resume()
        }
    }
    func waitForRequest(_ text: String) async {
        if pending[text] == nil {
            await withCheckedContinuation { waiters[text] = $0 }
        }
    }
    func finish(_ text: String, with output: SpeechOutput) {
        pending.removeValue(forKey: text)?.resume(returning: output)
    }
}
