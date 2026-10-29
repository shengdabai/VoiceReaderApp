import AVFoundation
import Combine
#if os(iOS)
import MediaPlayer
#endif
import Foundation

enum PlaybackState: Equatable {
    case idle
    case playing
    case paused
    case failed(String)
}

@MainActor
protocol PlaybackDriving: AnyObject {
    var onCompletion: ((Bool) -> Void)? { get set }
    func start(_ output: SpeechOutput) throws
    func pause()
    func resume() -> Bool
    func stop()
}

@MainActor
final class PlaybackEngine: ObservableObject {
    @Published private(set) var state: PlaybackState = .idle
    private let driver: PlaybackDriving
    private let synthesize: (SpeechRequest) async -> SpeechOutput
    private let configureAudioSession: () throws -> Void
    private var requestID = UUID()

    convenience init(remoteCloneSession: RemoteCloneSession) {
        let router = TTSRouter(remoteProvider: RemoteCloneProvider(remoteCloneSession: remoteCloneSession))
        self.init(driver: SystemPlaybackDriver(), synthesize: router.synthesize) {
            #if os(iOS)
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.allowAirPlay, .allowBluetooth])
            try session.setActive(true)
            #endif
        }
        #if os(iOS)
        configureRemoteCommands()
        #endif
    }

    init(driver: PlaybackDriving,
         synthesize: @escaping (SpeechRequest) async -> SpeechOutput,
         configureAudioSession: @escaping () throws -> Void = {}) {
        self.driver = driver
        self.synthesize = synthesize
        self.configureAudioSession = configureAudioSession
    }

    func play(request: SpeechRequest) async {
        stop()
        let id = requestID
        do {
            try configureAudioSession()
            let output = await synthesize(request)
            guard id == requestID, !Task.isCancelled else { return }
            driver.onCompletion = { [weak self] success in
                guard let self, self.requestID == id else { return }
                self.state = success ? .idle : .failed("音频播放失败。")
            }
            try driver.start(output)
            state = .playing
        } catch {
            guard id == requestID else { return }
            driver.stop()
            state = .failed("音频播放失败：\(error.localizedDescription)")
        }
    }

    func pause() {
        // Invalidate synthesis still in flight as well as pausing active audio.
        requestID = UUID()
        driver.pause()
        if state == .playing { state = .paused }
    }

    func resume() {
        guard state == .paused else { return }
        let id = requestID
        driver.onCompletion = { [weak self] success in
            guard let self, self.requestID == id else { return }
            self.state = success ? .idle : .failed("音频播放失败。")
        }
        if driver.resume() { state = .playing }
    }

    func stop() {
        requestID = UUID()
        driver.onCompletion = nil
        driver.stop()
        state = .idle
    }

    #if os(iOS)
    private func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.resume() }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }
            return .success
        }
        center.stopCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.stop() }
            return .success
        }
    }
    #endif
}

@MainActor
private final class SystemPlaybackDriver: NSObject, PlaybackDriving, AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate {
    var onCompletion: ((Bool) -> Void)?
    private lazy var speechSynthesizer: AVSpeechSynthesizer = {
        let synthesizer = AVSpeechSynthesizer()
        synthesizer.delegate = self
        return synthesizer
    }()
    private var activeUtterance: AVSpeechUtterance?
    private var audioPlayer: AVAudioPlayer?

    func start(_ output: SpeechOutput) throws {
        stop()
        switch output {
        case .localUtterance(let utterance):
            activeUtterance = utterance
            speechSynthesizer.speak(utterance)
        case .remoteAudioFile(let url):
            let player = try AVAudioPlayer(contentsOf: url)
            audioPlayer = player
            player.delegate = self
            // The remote API already synthesizes at the requested speed.
            guard player.prepareToPlay(), player.play() else {
                throw CocoaError(.fileReadUnknown)
            }
        }
    }

    func pause() {
        if activeUtterance != nil { speechSynthesizer.pauseSpeaking(at: .word) }
        audioPlayer?.pause()
    }

    func resume() -> Bool {
        if activeUtterance != nil { return speechSynthesizer.continueSpeaking() }
        return audioPlayer?.play() ?? false
    }

    func stop() {
        if activeUtterance != nil {
            activeUtterance = nil
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        audioPlayer?.stop()
        audioPlayer = nil
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            guard activeUtterance === utterance else { return }
            activeUtterance = nil
            onCompletion?(true)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            guard activeUtterance === utterance else { return }
            activeUtterance = nil
            onCompletion?(true)
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            guard audioPlayer === player else { return }
            audioPlayer = nil
            onCompletion?(flag)
        }
    }
}
