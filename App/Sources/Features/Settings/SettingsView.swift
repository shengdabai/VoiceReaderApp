import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var environment: AppEnvironment

    @State private var remoteEnabled = false
    @State private var remoteEndpoint = ""
    @State private var remoteAPIKey = ""
    @State private var remoteConfigurationStatus = "本地演示模式：阅读内容不会发送到远程服务。"

    @State private var voiceName = "我的声音"
    @State private var remoteVoiceID = ""
    @State private var providerType: VoiceProviderType = .local

    @State private var currentSampleURL: URL?
    @State private var recordError: String?

    var body: some View {
        Form {
            Section("远程克隆") {
                Toggle("仅本次启动启用远程朗读", isOn: $remoteEnabled)
                    .onChange(of: remoteEnabled) { _, enabled in
                        guard !enabled else { return }
                        Task {
                            await environment.remoteCloneSession.disable()
                            remoteAPIKey = ""
                            providerType = .local
                            remoteConfigurationStatus = "本地演示模式：阅读内容不会发送到远程服务。"
                        }
                    }
                TextField("API Endpoint", text: $remoteEndpoint)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .disabled(!remoteEnabled)
                SecureField("API Key", text: $remoteAPIKey)
                    .disabled(!remoteEnabled)
                Button(remoteEnabled ? "应用本次启动的远程配置" : "保持本地演示模式") {
                    Task {
                        if remoteEnabled {
                            do {
                                try await environment.remoteCloneSession.configure(
                                    endpointText: remoteEndpoint,
                                    apiKey: remoteAPIKey
                                )
                                providerType = .remoteClone
                                remoteConfigurationStatus = "远程朗读已为本次启动启用；退出应用后配置会清除。"
                            } catch {
                                await environment.remoteCloneSession.disable()
                                providerType = .local
                                remoteConfigurationStatus = error.localizedDescription
                            }
                        } else {
                            await environment.remoteCloneSession.disable()
                            remoteAPIKey = ""
                            providerType = .local
                            remoteConfigurationStatus = "本地演示模式：阅读内容不会发送到远程服务。"
                        }
                    }
                }
                Text(remoteConfigurationStatus)
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
        .task {
            let current = await environment.remoteCloneSession.current()
            remoteEnabled = current.enabled
            remoteEndpoint = current.endpoint?.absoluteString ?? ""
            remoteAPIKey = current.apiKey ?? ""
            providerType = current.enabled ? .remoteClone : .local
        }
        .alert("录制失败", isPresented: Binding(
            get: { recordError != nil },
            set: { _ in recordError = nil }
        )) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(recordError ?? "未知错误")
        }
    }
}
