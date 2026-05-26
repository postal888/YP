import Foundation

/// Состояние YouTube-плеера.
public enum YouTubePlayerState: Equatable, Sendable {
    case idle
    case loading
    case ready
    case playing
    case paused
    case buffering
    case ended
    case error(String)
}

/// События плеера для образовательной аналитики и UI.
public enum YouTubePlayerEvent: Equatable, Sendable {
    case ready
    case stateChanged(YouTubePlayerState)
    case progress(currentTime: Double, duration: Double)
    case ended
    case error(String)
    case debug(String)
}

/// Конфигурация встраиваемого YouTube-плеера.
public struct YouTubePlayerConfiguration: Equatable, Sendable {
    public var videoID: String
    public var autoplay: Bool
    public var startTime: Double
    public var showControls: Bool
    public var allowFullscreen: Bool
    public var playsInline: Bool
    public var progressPollingInterval: TimeInterval
    public var captionLanguage: String

    public init(
        videoID: String,
        autoplay: Bool = false,
        startTime: Double = 0,
        showControls: Bool = true,
        allowFullscreen: Bool = true,
        playsInline: Bool = true,
        progressPollingInterval: TimeInterval = 1.0,
        captionLanguage: String = "pt"
    ) {
        self.videoID = videoID
        self.autoplay = autoplay
        self.startTime = startTime
        self.showControls = showControls
        self.allowFullscreen = allowFullscreen
        self.playsInline = playsInline
        self.progressPollingInterval = progressPollingInterval
        self.captionLanguage = captionLanguage
    }
}

/// Команды управления плеером из SwiftUI / UIKit.
public enum YouTubePlayerCommand: Equatable, Sendable {
    case play
    case pause
    case seek(to: Double)
    case load(videoID: String, startTime: Double = 0)
}
