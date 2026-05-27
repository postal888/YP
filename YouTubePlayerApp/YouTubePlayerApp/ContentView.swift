import SwiftUI

@MainActor
struct ContentView: View {
    @StateObject private var errorLog = AppErrorLog()
    @StateObject private var vocabularyStore = VocabularyStore()
    @StateObject private var bookLibrary = BookLibraryStore()

    var body: some View {
        TabView {
            YouTubeRootView(errorLog: errorLog)
                .tabItem {
                    Label("YouTube", systemImage: "play.rectangle.fill")
                }

            BooksLibraryView()
                .tabItem {
                    Label("Книги", systemImage: "book.fill")
                }

            DictionaryView()
                .tabItem {
                    Label("Словарь", systemImage: "rectangle.stack.fill")
                }
        }
        .environmentObject(vocabularyStore)
        .environmentObject(bookLibrary)
        .preferredColorScheme(.dark)
        .accentColor(PortTheme.accent)
    }
}

#Preview {
    ContentView()
}
