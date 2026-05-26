import Combine
import Foundation
import YouTubePlayerKit

@MainActor
final class YouTubePlayerHolder: ObservableObject {
    let player: YouTubePlayer

    private var cancellables = Set<AnyCancellable>()
    private var timeTimer: Timer?
    private var lastTimeReported: Double = -1

    private var onProgress: ((Double, Double) -> Void)?
    private var onState: ((String) -> Void)?
    private var onEnded: (() -> Void)?
    private var onError: ((String) -> Void)?
    private var onDebug: ((String) -> Void)?

    init() {
        player = YouTubePlayer(
            parameters: .init(showControls: true),
            configuration: .init(
                fullscreenMode: .system,
                allowsInlineMediaPlayback: true,
                allowsPictureInPictureMediaPlayback: true
            )
        )
    }

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

        cancellables.removeAll()
        subscribeToPlayer()
        load(videoID: videoID, captionLanguage: captionLanguage)
        startTimeReporting()
    }

    func load(videoID: String, captionLanguage: String) {
        onDebug?("Loading videoID=\(videoID), lang=\(captionLanguage)")

        player.source = .video(id: videoID)
        var parameters = player.parameters
        parameters.autoPlay = false
        parameters.captionLanguage = captionLanguage
        parameters.language = captionLanguage
        parameters.showCaptions = true
        parameters.showControls = true
        parameters.showFullscreenButton = true
        parameters.restrictRelatedVideosToSameChannel = true
        player.parameters = parameters
    }

    func play() {
        Task {
            do {
                try await player.play()
            } catch {
                onError?("Play failed: \(error.localizedDescription)")
            }
        }
    }

    func pause() {
        Task {
            do {
                try await player.pause()
            } catch {
                onError?("Pause failed: \(error.localizedDescription)")
            }
        }
    }

    func seek(to seconds: Double) {
        Task {
            do {
                try await player.seek(
                    to: Measurement(value: seconds, unit: .seconds),
                    allowSeekAhead: true
                )
            } catch {
                onError?("Seek failed: \(error.localizedDescription)")
            }
        }
    }

    private func subscribeToPlayer() {
        player.statePublisher
            .sink { [weak self] state in
                guard let self else { return }
                switch state {
                case .idle:
                    onState?("Загрузка")
                case .ready:
                    onState?("Готов")
                    onDebug?("Player ready")
                case .error(let error):
                    let message = String(describing: error)
                    onState?("Ошибка")
                    onError?(message)
                }
            }
            .store(in: &cancellables)

        player.playbackStatePublisher
            .sink { [weak self] playbackState in
                guard let self else { return }
                onState?(Self.statusText(for: playbackState))
                if playbackState == .ended {
                    onEnded?()
                }
            }
            .store(in: &cancellables)
    }

    private func startTimeReporting() {
        timeTimer?.invalidate()
        timeTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                do {
                    let current = try await self.player.getCurrentTime()
                    let duration = try await self.player.getDuration()
                    let seconds = current.converted(to: .seconds).value
                    let total = duration.converted(to: .seconds).value

                    if abs(seconds - self.lastTimeReported) > 0.05 {
                        self.lastTimeReported = seconds
                        self.onProgress?(seconds, total)
                    }
                } catch {
                    // Ignore transient API errors during transitions.
                }
            }
        }
    }

    private static func statusText(for playbackState: YouTubePlayer.PlaybackState) -> String {
        switch playbackState {
        case .unstarted: return "Ожидание"
        case .ended: return "Завершено"
        case .playing: return "Воспроизведение"
        case .paused: return "Пауза"
        case .buffering: return "Буферизация"
        case .cued: return "Готов"
        @unknown default: return "Ожидание"
        }
    }
}
