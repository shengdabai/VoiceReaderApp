import SwiftUI

struct LibraryView: View {
    @ObservedObject var viewModel: LibraryViewModel

    @State private var showFileImporter = false
    @State private var showURLInput = false
    @State private var inputURL = ""

    var body: some View {
        List {
            Section {
                Button("导入本地或iCloud文件") {
                    showFileImporter = true
                }
                Button("导入网址链接") {
                    showURLInput = true
                }
            }

            Section("我的书籍") {
                if viewModel.books.isEmpty {
                    Text("还没有导入书籍")
                        .foregroundStyle(.secondary)
                }

                ForEach(viewModel.books) { book in
                    NavigationLink(value: book) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(book.title)
                                    .font(.headline)
                                Text(book.format.rawValue.uppercased())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                }
            }
        }
        .overlay {
            if viewModel.isImporting {
                ProgressView("正在导入...")
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .sheet(isPresented: $showFileImporter) {
            DocumentPicker { url in
                showFileImporter = false
                Task { await viewModel.importFile(at: url) }
            }
        }
        .alert("导入失败", isPresented: Binding(
            get: { viewModel.importErrorMessage != nil },
            set: { _ in viewModel.importErrorMessage = nil }
        )) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(viewModel.importErrorMessage ?? "未知错误")
        }
        .sheet(isPresented: $showURLInput) {
            NavigationStack {
                Form {
                    Section("网址") {
                        TextField("https://example.com/article", text: $inputURL)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                }
                .navigationTitle("链接导入")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { showURLInput = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("导入") {
                            let url = inputURL
                            showURLInput = false
                            inputURL = ""
                            Task { await viewModel.importFromArticleURL(url) }
                        }
                    }
                }
            }
        }
    }
}
