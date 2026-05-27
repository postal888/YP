import SwiftUI

@MainActor
struct YouTubeRootView: View {
    @ObservedObject var errorLog: AppErrorLog

    @State private var selectedVideoID: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ZStack {
                    HomeView(errorLog: errorLog) { videoID in
                        selectedVideoID = videoID
                    }

                    NavigationLink(
                        destination: playerDestination,
                        tag: "player",
                        selection: Binding(
                            get: { selectedVideoID == nil ? nil : "player" },
                            set: { if $0 == nil { selectedVideoID = nil } }
                        )
                    ) {
                        EmptyView()
                    }
                    .hidden()
                }

                if selectedVideoID == nil {
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
        if let videoID = selectedVideoID {
            LessonPlayerView(
                videoID: videoID,
                errorLog: errorLog,
                onClose: { selectedVideoID = nil }
            )
        } else {
            EmptyView()
        }
    }
}
