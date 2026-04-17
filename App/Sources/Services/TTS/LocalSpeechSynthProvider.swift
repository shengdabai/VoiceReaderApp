import AVFoundation
import Foundation

struct LocalSpeechSynthProvider: SpeechProvider {
    func synthesize(_ request: SpeechRequest) async throws -> SpeechOutput {
        let utterance = AVSpeechUtterance(string: request.text)
        utterance.voice = AVSpeechSynthesisVoice(language: request.language.rawValue)
        utterance.rate = mapToSpeechRate(request.speed)
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        return .localUtterance(utterance)
    }

    private func mapToSpeechRate(_ speed: SpeedPreset) -> Float {
        let base = AVSpeechUtteranceDefaultSpeechRate
        let scaled = base * speed.value
        return min(max(scaled, AVSpeechUtteranceMinimumSpeechRate), AVSpeechUtteranceMaximumSpeechRate)
    }
}
