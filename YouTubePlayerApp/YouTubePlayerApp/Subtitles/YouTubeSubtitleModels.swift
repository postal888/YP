import Foundation

struct YouTubeTranscriptSegment: Equatable, Sendable {
    let text: String
    let offset: Double
    let duration: Double
}

struct YouTubeSubtitleLine: Identifiable, Equatable, Sendable {
    let id: String
    let text: String
    let startSec: Double
    let endSec: Double
}

enum YouTubeSubtitleTone: Sendable {
    case future
    case current
    case spoken
}

enum YouTubeSubtitleLanguage: String, CaseIterable, Identifiable, Sendable {
    case portuguese = "pt"
    case english = "en"
    case russian = "ru"
    case spanish = "es"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .portuguese: return "Português"
        case .english: return "English"
        case .russian: return "Русский"
        case .spanish: return "Español"
        }
    }
}

enum YouTubeTranscriptError: LocalizedError, Sendable {
    case noCaptionTracks
    case noMatchingTrack
    case emptyTranscript(String)
    case network(String)

    var errorDescription: String? {
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

func youtubeSubtitleTone(for line: YouTubeSubtitleLine, playbackSec: Double?) -> YouTubeSubtitleTone {
    guard let playbackSec else { return .future }
    if playbackSec >= line.endSec { return .spoken }
    if playbackSec >= line.startSec { return .current }
    return .future
}

func formatSubtitleClock(_ seconds: Double) -> String {
    let total = max(0, Int(seconds.rounded(.down)))
    let minutes = total / 60
    let remainder = total % 60
    return String(format: "%d:%02d", minutes, remainder)
}
