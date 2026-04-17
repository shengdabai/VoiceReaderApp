import AVFoundation
import Combine
import Foundation

@MainActor
final class VoiceRecorderService: NSObject, ObservableObject {
    @Published private(set) var isRecording = false

    private var recorder: AVAudioRecorder?

    func startRecording() async throws -> URL {
        let permissionGranted = await requestPermissionIfNeeded()
        guard permissionGranted else {
            throw VoiceRecorderError.permissionDenied
        }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)

        let outputURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("voice-sample-\(UUID().uuidString).m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        recorder = try AVAudioRecorder(url: outputURL, settings: settings)
        recorder?.record()
        isRecording = true
        return outputURL
    }

    func stopRecording() {
        recorder?.stop()
        isRecording = false
    }

    private func requestPermissionIfNeeded() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}

enum VoiceRecorderError: LocalizedError {
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "未授予麦克风权限，无法录制声音样本。"
        }
    }
}
