import SwiftUI

@main
struct VoiceReaderApp: App {
    @StateObject private var environment = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(environment)
                .onOpenURL { incomingURL in
                    Task {
                        await environment.libraryViewModel.handleIncomingURL(incomingURL)
                    }
                }
        }
    }
}
