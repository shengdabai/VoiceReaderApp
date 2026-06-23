import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var environment: AppEnvironment

    @AppStorage("remote_clone_endpoint") private var remoteEndpoint = ""

    // API key is kept in the Keychain, not UserDefaults, so it is never
    // written in plaintext to the sandbox plist.
    private let keychain = KeychainStore()
    private let apiKeyKey = "remote_clone_api_key"
    @State private var remoteAPIKey = ""

    @State private var voiceName = "我的声音"
    @State private var remoteVoiceID = ""
    @State private var providerType: VoiceProviderType = .remoteClone

    @State private var currentSampleURL: URL?
    @State private var recordError: String?

    private var endpointIsHTTPS: Bool {
        URL(string: remoteEndpoint)?.scheme?.lowercased() == "https"
    }

    var body: some View {
        Form {
            Section("远程克隆") {
                TextField("API Endpoint", text: $remoteEndpoint)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                if !remoteEndpoint.isEmpty && !endpointIsHTTPS {
                    Text("⚠️ Endpoint 需为 HTTPS。非 HTTPS 地址会被 iOS 安全策略（ATS）拒绝，导致请求静默失败并回退本地语音。")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
                SecureField("API Key", text: $remoteAPIKey)
                    .onChange(of: remoteAPIKey) { _, newValue in
                        keychain.set(newValue, for: apiKeyKey)
                    }
                Text("远程克隆失败会自动回退本地离线语音。API Key 安全存储于钥匙串。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("录制声音样本") {
                Button(environment.voiceRecorder.isRecording ? "停止录制" : "开始录制") {
                    Task {
                        if environment.voiceRecorder.isRecording {
                            environment.voiceRecorder.stopRecording()
                        } else {
                            do {
                                currentSampleURL = try await environment.voiceRecorder.startRecording()
                            } catch {
                                recordError = error.localizedDescription
                            }
                        }
                    }
                }

                if let currentSampleURL {
                    Text("样本文件：\(currentSampleURL.lastPathComponent)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("声音档案") {
                TextField("名称", text: $voiceName)
                Picker("提供方", selection: $providerType) {
                    ForEach(VoiceProviderType.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                TextField("Remote Voice ID（可选）", text: $remoteVoiceID)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Button("保存档案") {
                    let profile = VoiceProfile(
                        id: UUID(),
                        name: voiceName,
                        providerType: providerType,
                        remoteVoiceID: remoteVoiceID.isEmpty ? nil : remoteVoiceID,
                        sampleFiles: currentSampleURL.map { [$0] } ?? [],
                        preferredLanguage: .zhHans,
                        createdAt: Date()
                    )

                    environment.voiceProfileStore.upsert(profile)
                    environment.voiceProfileStore.setSelectedProfile(profile.id)
                    voiceName = "我的声音"
                    remoteVoiceID = ""
                }

                ForEach(environment.voiceProfileStore.profiles) { profile in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(profile.name)
                            Text(profile.providerType.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if environment.voiceProfileStore.selectedProfileID == profile.id {
                            Text("已选中")
                                .font(.caption)
                        } else {
                            Button("使用") {
                                environment.voiceProfileStore.setSelectedProfile(profile.id)
                            }
                        }
                    }
                }
                .onDelete { offsets in
                    offsets.map { environment.voiceProfileStore.profiles[$0].id }
                        .forEach { environment.voiceProfileStore.delete($0) }
                }
            }
        }
        .alert("录制失败", isPresented: Binding(
            get: { recordError != nil },
            set: { _ in recordError = nil }
        )) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(recordError ?? "未知错误")
        }
        .onAppear(perform: loadAPIKey)
    }

    /// Loads the API key from the Keychain, migrating any legacy plaintext
    /// value left in UserDefaults by an older build.
    private func loadAPIKey() {
        if let stored = keychain.string(for: apiKeyKey), !stored.isEmpty {
            remoteAPIKey = stored
            return
        }
        if let legacy = UserDefaults.standard.string(forKey: apiKeyKey), !legacy.isEmpty {
            keychain.set(legacy, for: apiKeyKey)
            UserDefaults.standard.removeObject(forKey: apiKeyKey)
            remoteAPIKey = legacy
        }
    }
}
