import Foundation
import Combine

@MainActor
final class YouTubeSessionStore: ObservableObject {
    @Published var selectedVideoID: String?

    let playerHolder = YouTubePlayerHolder()

    var isPlayerOpen: Bool {
        selectedVideoID != nil
    }

    func openVideo(_ videoID: String) {
        selectedVideoID = videoID
    }

    func closePlayer() {
        selectedVideoID = nil
    }

    func pause() {
        playerHolder.pause()
    }

    func applyBackgroundPlaybackPolicy(enabled: Bool) {
        playerHolder.applyBackgroundPlaybackPolicy(enabled: enabled)
    }
}
