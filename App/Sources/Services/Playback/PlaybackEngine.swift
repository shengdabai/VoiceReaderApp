import AVFoundation
import Combine
import MediaPlayer
import Foundation

enum PlaybackState: Equatable {
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
    private var remoteAudioFileURL: URL?
    private let ttsRouter: TTSRouter

    init(remoteCloneSession: RemoteCloneSession) {
        self.ttsRouter = TTSRouter(remoteProvider: RemoteCloneProvider(remoteCloneSession: remoteCloneSession))
        super.init()
        speechSynthesizer.delegate = self
        configureRemoteCommands()
    }

    func play(request: SpeechRequest) async {
        await configureAudioSession()
        let output = await ttsRouter.synthesize(request)

        // Stop any in-flight audio (local synth or remote player) before
        // starting a new one, so the two output paths never overlap.
        stop()

        switch output {
        case .localUtterance(let utterance):
            speechSynthesizer.speak(utterance)
            state = .playing

        case .remoteAudioFile(let fileURL):
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: fileURL)
                remoteAudioFileURL = fileURL
                audioPlayer?.delegate = self
                audioPlayer?.enableRate = true
                audioPlayer?.rate = request.speed.value
                audioPlayer?.prepareToPlay()
                audioPlayer?.play()
                state = .playing
            } catch {
                cleanupRemoteAudioFile()
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
        // Resume only the path that is actually paused. The two output paths
        // are mutually exclusive (play() stops the other first), so prefer the
        // paused local synth and otherwise fall back to the remote player.
        if speechSynthesizer.isPaused {
            speechSynthesizer.continueSpeaking()
            state = .playing
        } else if let audioPlayer, !audioPlayer.isPlaying {
            audioPlayer.play()
            state = .playing
        }
    }

    func stop() {
        speechSynthesizer.stopSpeaking(at: .immediate)
        audioPlayer?.stop()
        cleanupRemoteAudioFile()
        state = .idle
    }

    /// Deletes the temporary mp3 written by the remote TTS provider so the
    /// sandbox temp directory does not accumulate audio files over time.
    private func cleanupRemoteAudioFile() {
        guard let url = remoteAudioFileURL else { return }
        try? FileManager.default.removeItem(at: url)
        remoteAudioFileURL = nil
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
            cleanupRemoteAudioFile()
            state = .idle
        }
    }
}
