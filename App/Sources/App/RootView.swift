import SwiftUI

struct RootView: View {
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        TabView {
            NavigationStack {
                LibraryView(viewModel: environment.libraryViewModel)
                    .navigationTitle("书架")
                    .navigationDestination(for: Book.self) { book in
                        ReaderView(viewModel: environment.makeReaderViewModel(for: book))
                            .navigationTitle(book.title)
                            .navigationBarTitleDisplayMode(.inline)
                    }
            }
            .tabItem {
                Label("阅读", systemImage: "books.vertical")
            }

            NavigationStack {
                SettingsView()
                    .navigationTitle("设置")
            }
            .tabItem {
                Label("设置", systemImage: "slider.horizontal.3")
            }
        }
    }
}
