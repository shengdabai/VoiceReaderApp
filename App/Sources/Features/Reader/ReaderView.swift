import SwiftUI

struct ReaderView: View {
    @StateObject private var viewModel: ReaderViewModel

    init(viewModel: ReaderViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 16) {
            if viewModel.paragraphs.isEmpty {
                ContentUnavailableView("无法读取内容", systemImage: "exclamationmark.triangle")
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("段落 \(viewModel.currentParagraphIndex + 1) / \(viewModel.paragraphs.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(viewModel.currentParagraph)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                }

                controls
            }
        }
        .padding(.bottom)
        .alert("阅读错误", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { _ in viewModel.errorMessage = nil }
        )) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "未知错误")
        }
    }

    private var controls: some View {
        VStack(spacing: 12) {
            HStack {
                Picker("语言", selection: $viewModel.selectedLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal)

            HStack {
                Picker("语速", selection: $viewModel.selectedSpeed) {
                    ForEach(SpeedPreset.allCases) { speed in
                        Text(speed.rawValue).tag(speed)
                    }
                }
            }
            .padding(.horizontal)

            HStack(spacing: 20) {
                Button(action: viewModel.previousParagraph) {
                    Label("上一段", systemImage: "chevron.left")
                }

                Button {
                    Task { await viewModel.playCurrentParagraph() }
                } label: {
                    Label("播放", systemImage: "play.fill")
                }

                Button(action: viewModel.pause) {
                    Label("暂停", systemImage: "pause.fill")
                }

                Button(action: viewModel.resume) {
                    Label("继续", systemImage: "playpause.fill")
                }

                Button(action: viewModel.nextParagraph) {
                    Label("下一段", systemImage: "chevron.right")
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
