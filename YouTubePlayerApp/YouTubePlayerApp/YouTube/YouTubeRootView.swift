import SwiftUI

@MainActor
struct YouTubeRootView: View {
    @ObservedObject var session: YouTubeSessionStore
    @ObservedObject var errorLog: AppErrorLog

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ZStack {
                    HomeView(errorLog: errorLog) { videoID, title in
                        session.openVideo(videoID, title: title)
                    }

                    NavigationLink(
                        destination: playerDestination,
                        tag: "player",
                        selection: Binding(
                            get: { session.selectedVideoID == nil ? nil : "player" },
                            set: { if $0 == nil { session.closePlayer() } }
                        )
                    ) {
                        EmptyView()
                    }
                    .hidden()
                }

                if session.selectedVideoID == nil {
                    ErrorLogPanelView(log: errorLog)
                }
            }
            .navigationBarHidden(true)
            .background(PortTheme.background.ignoresSafeArea())
        }
        .navigationViewStyle(.stack)
    }

    @ViewBuilder
    private var playerDestination: some View {
        if let videoID = session.selectedVideoID {
            LessonPlayerView(
                videoID: videoID,
                session: session,
                errorLog: errorLog,
                onClose: { session.closePlayer() }
            )
        } else {
            EmptyView()
        }
    }
}
