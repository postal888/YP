import Foundation

public struct YouTubeTranscriptSegment: Equatable, Sendable {
    public let text: String
    public let offset: Double
    public let duration: Double

    public init(text: String, offset: Double, duration: Double) {
        self.text = text
        self.offset = offset
        self.duration = duration
    }
}

public struct YouTubeSubtitleLine: Identifiable, Equatable, Sendable {
    public let id: String
    public let text: String
    public let startSec: Double
    public let endSec: Double

    public init(id: String, text: String, startSec: Double, endSec: Double) {
        self.id = id
        self.text = text
        self.startSec = startSec
        self.endSec = endSec
    }
}

public enum YouTubeSubtitleTone: Sendable {
    case future
    case current
    case spoken
}

public enum YouTubeSubtitleLanguage: String, CaseIterable, Identifiable, Sendable {
    case portuguese = "pt"
    case english = "en"
    case russian = "ru"
    case spanish = "es"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .portuguese: return "Português"
        case .english: return "English"
        case .russian: return "Русский"
        case .spanish: return "Español"
        }
    }
}

public enum YouTubeTranscriptError: LocalizedError, Sendable {
    case noCaptionTracks
    case noMatchingTrack
    case emptyTranscript(String)
    case network(String)

    public var errorDescription: String? {
        switch self {
        case .noCaptionTracks:
            return "У видео нет открытых субтитров."
        case .noMatchingTrack:
            return "Не найдена подходящая дорожка субтитров."
        case .emptyTranscript(let details):
            return details
        case .network(let details):
            return details
        }
    }
}

public func youtubeSubtitleTone(for line: YouTubeSubtitleLine, playbackSec: Double?) -> YouTubeSubtitleTone {
    guard let playbackSec else { return .future }
    if playbackSec >= line.endSec { return .spoken }
    if playbackSec >= line.startSec { return .current }
    return .future
}

public func formatSubtitleClock(_ seconds: Double) -> String {
    let total = max(0, Int(seconds.rounded(.down)))
    let minutes = total / 60
    let remainder = total % 60
    return String(format: "%d:%02d", minutes, remainder)
}
