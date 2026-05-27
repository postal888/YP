import Foundation
import Combine

@MainActor
final class YouTubeSessionStore: ObservableObject {
    @Published var selectedVideoID: String?
    @Published private(set) var selectedVideoTitle: String?
    @Published private(set) var videoTabActivationToken = UUID()

    let playerHolder = YouTubePlayerHolder()

    var isPlayerOpen: Bool {
        selectedVideoID != nil
    }

    var currentFolderKey: String? {
        selectedVideoID.map { VocabularyFolderKey.youtube($0) }
    }

    var currentFolderTitle: String? {
        selectedVideoTitle ?? selectedVideoID.map { VocabularyFolderKey.defaultTitle(for: VocabularyFolderKey.youtube($0)) }
    }

    func openVideo(_ videoID: String, title: String? = nil) {
        selectedVideoID = videoID
        selectedVideoTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)

        if selectedVideoTitle?.isEmpty != false {
            Task {
                await loadVideoTitleIfNeeded(videoID: videoID)
            }
        }
    }

    func closePlayer() {
        selectedVideoID = nil
        selectedVideoTitle = nil
    }

    func pause() {
        playerHolder.pause()
    }

    func applyBackgroundPlaybackPolicy(enabled: Bool) {
        playerHolder.applyBackgroundPlaybackPolicy(enabled: enabled)
    }

    func notifyVideoTabActivated() {
        videoTabActivationToken = UUID()
        MediaPlaybackAudioSession.activateForVideoPlayback()
    }

    private func loadVideoTitleIfNeeded(videoID: String) async {
        guard selectedVideoID == videoID, selectedVideoTitle?.isEmpty != false else { return }
        if let title = await YouTubeVideoMetadataService.fetchTitle(videoID: videoID) {
            guard selectedVideoID == videoID else { return }
            selectedVideoTitle = title
        }
    }
}
