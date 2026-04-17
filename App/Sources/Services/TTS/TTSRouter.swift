import AVFoundation
import Foundation

struct TTSRouter {
    private let localProvider: LocalSpeechSynthProvider
    private let remoteProvider: RemoteCloneProvider

    init(localProvider: LocalSpeechSynthProvider = LocalSpeechSynthProvider(),
         remoteProvider: RemoteCloneProvider = RemoteCloneProvider()) {
        self.localProvider = localProvider
        self.remoteProvider = remoteProvider
    }

    func synthesize(_ request: SpeechRequest) async -> SpeechOutput {
        if request.voiceProfile?.providerType == .remoteClone {
            if let output = try? await remoteProvider.synthesize(request) {
                return output
            }
        }

        if let output = try? await localProvider.synthesize(request) {
            return output
        }

        return .localUtterance(AVSpeechUtterance(string: request.text))
    }
}
