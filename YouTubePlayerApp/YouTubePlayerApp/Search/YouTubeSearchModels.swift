import Foundation

struct YouTubeChannelResult: Identifiable, Equatable, Sendable {
    let id: String
    let channelID: String
    let title: String
    let subscriberCountText: String
    let videoCountText: String
    let thumbnailURL: URL?
}

enum YouTubeSearchFilter: String, CaseIterable, Identifiable {
    case video
    case channel

    var id: String { rawValue }

    var label: String {
        switch self {
        case .video: return "Видео"
        case .channel: return "Канал"
        }
    }
}

enum YouTubeSearchSuggestionItem: Identifiable, Equatable {
    case query(String)
    case video(YouTubeSearchResult)
    case channel(YouTubeChannelResult)

    var id: String {
        switch self {
        case .query(let text):
            return "q-\(text)"
        case .video(let result):
            return "v-\(result.videoID)"
        case .channel(let result):
            return "c-\(result.channelID)"
        }
    }
}

struct YouTubeSearchResponse: Equatable, Sendable {
    let videos: [YouTubeSearchResult]
    let channels: [YouTubeChannelResult]
}
