import SwiftUI

@MainActor
struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var errorLog = AppErrorLog()
    @StateObject private var vocabularyStore = VocabularyStore()
    @StateObject private var bookLibrary = BookLibraryStore()
    @StateObject private var appSettings = AppSettings()
    @StateObject private var learningStats = LearningStatsStore()
    @StateObject private var youtubeSession = YouTubeSessionStore()
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
        .onAppear {
            youtubeSession.applyBackgroundPlaybackPolicy(enabled: appSettings.backgroundVideoPlayback)
        }
        .onChange(of: appSettings.backgroundVideoPlayback) { enabled in
            youtubeSession.applyBackgroundPlaybackPolicy(enabled: enabled)
            if !enabled, selectedTab != .video {
                youtubeSession.pause()
            }
        }
        .onChange(of: selectedTab) { newTab in
            if newTab != .video, !appSettings.backgroundVideoPlayback {
                youtubeSession.pause()
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .background, !appSettings.backgroundVideoPlayback {
                youtubeSession.pause()
            }
        }
    }

    private var tabContent: some View {
        ZStack {
            HomeTabScreen { tab in
                selectedTab = tab
            }
            .zIndex(selectedTab == .home ? 1 : 0)
            .allowsHitTesting(selectedTab == .home)

            StudyTabScreen()
                .zIndex(selectedTab == .study ? 1 : 0)
                .allowsHitTesting(selectedTab == .study)

            BooksLibraryView()
                .zIndex(selectedTab == .reader ? 1 : 0)
                .allowsHitTesting(selectedTab == .reader)

            YouTubeRootView(session: youtubeSession, errorLog: errorLog)
                .zIndex(selectedTab == .video ? 1 : 0)
                .allowsHitTesting(selectedTab == .video)

            DictionaryView()
                .zIndex(selectedTab == .dictionary ? 1 : 0)
                .allowsHitTesting(selectedTab == .dictionary)

            AccountTabScreen()
                .zIndex(selectedTab == .account ? 1 : 0)
                .allowsHitTesting(selectedTab == .account)
        }
    }
}

#Preview {
    ContentView()
}
