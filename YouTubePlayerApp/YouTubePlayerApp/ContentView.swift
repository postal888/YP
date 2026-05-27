import SwiftUI

@MainActor
struct ContentView: View {
    @StateObject private var errorLog = AppErrorLog()
    @StateObject private var vocabularyStore = VocabularyStore()
    @StateObject private var bookLibrary = BookLibraryStore()
    @StateObject private var appSettings = AppSettings()
    @StateObject private var learningStats = LearningStatsStore()
    @State private var selectedTab: AppTab = .home

    var body: some View {
        tabContent
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                PortBottomNav(selected: $selectedTab)
            }
        .environmentObject(vocabularyStore)
        .environmentObject(bookLibrary)
        .environmentObject(appSettings)
        .environmentObject(learningStats)
        .preferredColorScheme(.dark)
        .accentColor(PortTheme.accent)
        .background(PortTheme.background.ignoresSafeArea())
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .home:
            HomeTabScreen { tab in
                selectedTab = tab
            }

        case .study:
            StudyTabScreen()

        case .reader:
            BooksLibraryView()

        case .video:
            YouTubeRootView(errorLog: errorLog)

        case .dictionary:
            DictionaryView()

        case .account:
            AccountTabScreen()
        }
    }
}

#Preview {
    ContentView()
}
