import Foundation
import Combine
import YouTubePlayerKit

@MainActor
final class YouTubePlayerHolder: ObservableObject {
    /// Placeholder source required by YouTubePlayerKit 2.x init.
    private(set) var player: YouTubePlayer = YouTubePlayer(
        source: .video(id: "dQw4w9WgXcQ"),
        parameters: .init(
            autoPlay: false,
            showControls: true,
            showFullscreenButton: true,
            language: "pt",
            captionLanguage: "pt",
            showCaptions: true,
            restrictRelatedVideosToSameChannel: true
        ),
        configuration: .init(
            fullscreenMode: .system,
            allowsInlineMediaPlayback: true,
            allowsPictureInPictureMediaPlayback: true
        )
    )

    private var cancellables = Set<AnyCancellable>()
    private var timeTimer: Timer?

    private var onProgress: ((Double, Double) -> Void)?
    private var onState: ((String) -> Void)?
    private var onEnded: (() -> Void)?
    private var onError: ((String) -> Void)?
    private var onDebug: ((String) -> Void)?

    init() {}

    func configure(
        videoID: String,
        captionLanguage: String,
        onProgress: @escaping (Double, Double) -> Void,
        onState: @escaping (String) -> Void,
        onEnded: @escaping () -> Void,
        onError: @escaping (String) -> Void,
        onDebug: @escaping (String) -> Void
    ) {
        self.onProgress = onProgress
        self.onState = onState
        self.onEnded = onEnded
        self.onError = onError
        self.onDebug = onDebug

        subscribeToState()
        subscribeToPlaybackState()
        startTimer()

        load(videoID: videoID, captionLanguage: captionLanguage)
    }

    func load(videoID: String, captionLanguage: String) {
        var parameters = player.parameters
        parameters.language = captionLanguage
        parameters.captionLanguage = captionLanguage
        parameters.showCaptions = true
        player.parameters = parameters

        Task { @MainActor in
            do {
                try await player.load(source: .video(id: videoID))
                self.onDebug?("loaded videoID=\(videoID), lang=\(captionLanguage)")
            } catch {
                self.onError?("load failed: \(error.localizedDescription)")
            }
        }
    }

    func play() {
        Task { @MainActor in
            try? await player.play()
        }
    }

    func pause() {
        Task { @MainActor in
            try? await player.pause()
        }
    }

    func seek(to seconds: Double) {
        Task { @MainActor in
            try? await player.seek(
                to: Measurement(value: seconds, unit: UnitDuration.seconds),
                allowSeekAhead: true
            )
        }
    }

    private func subscribeToState() {
        player.statePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self else { return }
                switch state {
                case .idle:
                    self.onState?("Ожидание")
                case .ready:
                    self.onState?("Готов")
                    self.onDebug?("player ready")
                case .error(let err):
                    let msg = String(describing: err)
                    self.onError?(msg)
                    self.onState?("Ошибка")
                }
            }
            .store(in: &cancellables)
    }

    private func subscribeToPlaybackState() {
        player.playbackStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] playbackState in
                guard let self else { return }
                self.onState?(Self.playbackStatusText(for: playbackState))
                if playbackState == .ended {
                    self.onEnded?()
                }
            }
            .store(in: &cancellables)
    }

    /// PlaybackState in YouTubePlayerKit 2.x is a struct backed by Int, not an enum.
    private static func playbackStatusText(for playbackState: YouTubePlayer.PlaybackState) -> String {
        switch playbackState.value {
        case YouTubePlayer.PlaybackState.unstarted.value:
            return "Ожидание"
        case YouTubePlayer.PlaybackState.ended.value:
            return "Завершено"
        case YouTubePlayer.PlaybackState.playing.value:
            return "Воспроизведение"
        case YouTubePlayer.PlaybackState.paused.value:
            return "Пауза"
        case YouTubePlayer.PlaybackState.buffering.value:
            return "Буферизация"
        case YouTubePlayer.PlaybackState.cued.value:
            return "Готов"
        default:
            return playbackState.description
        }
    }

    private func startTimer() {
        timeTimer?.invalidate()
        timeTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                let cur = (try? await self.player.getCurrentTime().converted(to: .seconds).value) ?? 0
                let dur = (try? await self.player.getDuration().converted(to: .seconds).value) ?? 0
                self.onProgress?(cur, dur)
            }
        }
    }

    deinit {
        timeTimer?.invalidate()
    }
}
