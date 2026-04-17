import AVFoundation
import Foundation

struct SpeechRequest {
    var text: String
    var language: AppLanguage
    var speed: SpeedPreset
    var voiceProfile: VoiceProfile?
}

enum SpeechOutput {
    case localUtterance(AVSpeechUtterance)
    case remoteAudioFile(URL)
}

enum SpeechSynthesisError: LocalizedError {
    case remoteNotConfigured
    case remoteUnsupported
    case remoteFailed

    var errorDescription: String? {
        switch self {
        case .remoteNotConfigured:
            return "远程克隆尚未配置 API Endpoint 或 Key。"
        case .remoteUnsupported:
            return "当前声音档案不支持远程克隆。"
        case .remoteFailed:
            return "远程克隆失败，已回退本地语音。"
        }
    }
}

protocol SpeechProvider {
    func synthesize(_ request: SpeechRequest) async throws -> SpeechOutput
}
