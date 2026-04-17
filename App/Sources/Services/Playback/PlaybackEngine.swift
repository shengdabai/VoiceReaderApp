import AVFoundation
import Combine
import MediaPlayer
import Foundation

enum PlaybackState {
    case idle
    case playing
    case paused
    case failed(String)
}

@MainActor
final class PlaybackEngine: NSObject, ObservableObject {
    @Published private(set) var state: PlaybackState = .idle

    private let speechSynthesizer = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?
    private let ttsRouter: TTSRouter

    override init() {
        self.ttsRouter = TTSRouter()
        super.init()
        speechSynthesizer.delegate = self
        configureRemoteCommands()
    }

    func play(request: SpeechRequest) async {
        await configureAudioSession()
        let output = await ttsRouter.synthesize(request)

        switch output {
        case .localUtterance(let utterance):
            speechSynthesizer.stopSpeaking(at: .immediate)
            speechSynthesizer.speak(utterance)
            state = .playing

        case .remoteAudioFile(let fileURL):
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: fileURL)
                audioPlayer?.delegate = self
                audioPlayer?.enableRate = true
                audioPlayer?.rate = request.speed.value
                audioPlayer?.prepareToPlay()
                audioPlayer?.play()
                state = .playing
            } catch {
                state = .failed("音频播放失败：\(error.localizedDescription)")
            }
        }
    }

    func pause() {
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.pauseSpeaking(at: .word)
        }
        if audioPlayer?.isPlaying == true {
            audioPlayer?.pause()
        }
        state = .paused
    }

    func resume() {
        if speechSynthesizer.isPaused {
            speechSynthesizer.continueSpeaking()
        }
        if let audioPlayer, !audioPlayer.isPlaying {
            audioPlayer.play()
        }
        state = .playing
    }

    func stop() {
        speechSynthesizer.stopSpeaking(at: .immediate)
        audioPlayer?.stop()
        state = .idle
    }

    private func configureAudioSession() async {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .spokenAudio, options: [.allowAirPlay, .allowBluetooth])
            try session.setActive(true)
        } catch {
            state = .failed("音频会话配置失败：\(error.localizedDescription)")
        }
    }

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
}

extension PlaybackEngine: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            state = .idle
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            state = .idle
        }
    }
}

extension PlaybackEngine: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            state = .idle
        }
    }
}
