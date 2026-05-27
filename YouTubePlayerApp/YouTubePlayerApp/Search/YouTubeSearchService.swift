import Foundation

struct YouTubeSearchResult: Identifiable, Equatable, Sendable {
    let id: String
    let videoID: String
    let title: String
    let channelTitle: String
    let viewCountText: String
    let durationText: String
    let thumbnailURL: URL?

    var thumbnailFallbackURL: URL? {
        URL(string: "https://i.ytimg.com/vi/\(videoID)/mqdefault.jpg")
    }
}

enum YouTubeSearchError: LocalizedError, Sendable {
    case emptyQuery
    case network(String)
    case parseFailed

    var errorDescription: String? {
        switch self {
        case .emptyQuery:
            return "Введите запрос для поиска."
        case .network(let details):
            return details
        case .parseFailed:
            return "Не удалось разобрать результаты поиска YouTube."
        }
    }
}

actor YouTubeSearchService {
    static let shared = YouTubeSearchService()

    private let session: URLSession
    private let searchURL = URL(string: "https://www.youtube.com/youtubei/v1/search?prettyPrint=false")!
    private let clientVersion = "20.10.38"

    init(session: URLSession = .shared) {
        self.session = session
    }

    func search(query: String, filter: YouTubeSearchFilter = .video) async throws -> YouTubeSearchResponse {
        let trimmed = query.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw YouTubeSearchError.emptyQuery }

        var request = URLRequest(url: searchURL, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(
            "com.google.android.youtube/\(clientVersion) (Linux; U; Android 14)",
            forHTTPHeaderField: "User-Agent"
        )

        var params: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "ANDROID",
                    "clientVersion": clientVersion,
                    "hl": "ru",
                    "gl": "RU"
                ]
            ],
            "query": trimmed
        ]

        if filter == .channel {
            params["params"] = "EgIQAg=="
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: params)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw YouTubeSearchError.network("Нет ответа от YouTube.")
        }
        guard http.statusCode == 200 else {
            throw YouTubeSearchError.network("YouTube вернул HTTP \(http.statusCode).")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw YouTubeSearchError.parseFailed
        }

        return parseSearchResponse(json, filter: filter)
    }

    func fetchQuerySuggestions(query: String) async -> [String] {
        let trimmed = query.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }

        guard var components = URLComponents(string: "https://clients1.google.com/complete/search") else {
            return []
        }
        components.queryItems = [
            URLQueryItem(name: "client", value: "youtube"),
            URLQueryItem(name: "hl", value: "ru"),
            URLQueryItem(name: "ds", value: "yt"),
            URLQueryItem(name: "q", value: trimmed)
        ]

        guard let url = components.url else { return [] }

        var request = URLRequest(url: url, timeoutInterval: 8)
        request.setValue("YouTubePlayerApp/1.0", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return []
            }

            guard let raw = String(data: data, encoding: .utf8) else { return [] }
            let jsonText = raw.hasPrefix("window.google.ac.h(")
                ? String(raw.dropFirst("window.google.ac.h(".count).dropLast(1))
                : raw

            guard
                let jsonData = jsonText.data(using: .utf8),
                let parsed = try JSONSerialization.jsonObject(with: jsonData) as? [Any],
                parsed.count > 1,
                let suggestions = parsed[1] as? [String]
            else {
                return []
            }

            return Array(suggestions.prefix(6))
        } catch {
            return []
        }
    }

    func buildSuggestionItems(
        query: String,
        filter: YouTubeSearchFilter,
        includeQuerySuggestions: Bool = true
    ) async throws -> [YouTubeSearchSuggestionItem] {
        async let querySuggestionsTask: [String] = includeQuerySuggestions
            ? fetchQuerySuggestions(query: query)
            : []
        async let searchTask = search(query: query, filter: filter)

        let querySuggestions = await querySuggestionsTask
        let response = try await searchTask

        var items: [YouTubeSearchSuggestionItem] = []
        var seen = Set<String>()

        for suggestion in querySuggestions {
            let key = suggestion.lowercased()
            guard seen.insert(key).inserted else { continue }
            items.append(.query(suggestion))
        }

        switch filter {
        case .video:
            for video in response.videos.prefix(12) {
                items.append(.video(video))
            }
        case .channel:
            for channel in response.channels.prefix(12) {
                items.append(.channel(channel))
            }
        }

        return items
    }

    private func parseSearchResponse(_ json: [String: Any], filter: YouTubeSearchFilter) -> YouTubeSearchResponse {
        let videoRenderers = collectRenderers(from: json, keys: [
            "videoRenderer",
            "gridVideoRenderer",
            "compactVideoRenderer",
            "playlistVideoRenderer"
        ])
        let channelRenderers = collectRenderers(from: json, keys: ["channelRenderer"])

        var seenVideos = Set<String>()
        var videos: [YouTubeSearchResult] = []
        for renderer in videoRenderers {
            guard let parsed = parseVideoRenderer(renderer), seenVideos.insert(parsed.videoID).inserted else {
                continue
            }
            videos.append(parsed)
            if videos.count >= 24 { break }
        }

        var seenChannels = Set<String>()
        var channels: [YouTubeChannelResult] = []
        for renderer in channelRenderers {
            guard let parsed = parseChannelRenderer(renderer), seenChannels.insert(parsed.channelID).inserted else {
                continue
            }
            channels.append(parsed)
            if channels.count >= 24 { break }
        }

        if filter == .channel, channels.isEmpty {
            for renderer in videoRenderers {
                guard let channelTitle = text(from: renderer["ownerText"])
                    ?? text(from: renderer["longBylineText"])
                    ?? text(from: renderer["shortBylineText"]) else {
                    continue
                }
                let key = channelTitle.lowercased()
                guard seenChannels.insert(key).inserted else { continue }
                channels.append(
                    YouTubeChannelResult(
                        id: key,
                        channelID: key,
                        title: channelTitle,
                        subscriberCountText: "",
                        videoCountText: "",
                        thumbnailURL: thumbnailURL(from: renderer["channelThumbnail"])
                            ?? thumbnailURL(from: renderer["thumbnail"])
                    )
                )
                if channels.count >= 12 { break }
            }
        }

        return YouTubeSearchResponse(videos: videos, channels: channels)
    }

    private func collectRenderers(from json: Any, keys: [String]) -> [[String: Any]] {
        var output: [[String: Any]] = []

        if let dictionary = json as? [String: Any] {
            for key in keys {
                if let renderer = dictionary[key] as? [String: Any] {
                    output.append(renderer)
                }
            }
            for value in dictionary.values {
                output.append(contentsOf: collectRenderers(from: value, keys: keys))
            }
        } else if let array = json as? [Any] {
            for value in array {
                output.append(contentsOf: collectRenderers(from: value, keys: keys))
            }
        }

        return output
    }

    private func parseVideoRenderer(_ renderer: [String: Any]) -> YouTubeSearchResult? {
        guard let videoID = renderer["videoId"] as? String, !videoID.isEmpty else {
            return nil
        }

        let title = text(from: renderer["title"]) ?? "Без названия"
        let channel = text(from: renderer["ownerText"])
            ?? text(from: renderer["longBylineText"])
            ?? text(from: renderer["shortBylineText"])
            ?? "YouTube"
        let views = text(from: renderer["viewCountText"]) ?? ""
        let duration = text(from: renderer["lengthText"]) ?? ""
        let thumbnailURL = thumbnailURL(from: renderer["thumbnail"])

        return YouTubeSearchResult(
            id: videoID,
            videoID: videoID,
            title: title,
            channelTitle: channel,
            viewCountText: views,
            durationText: duration,
            thumbnailURL: thumbnailURL
        )
    }

    private func parseChannelRenderer(_ renderer: [String: Any]) -> YouTubeChannelResult? {
        let title = text(from: renderer["title"]) ?? "YouTube канал"
        let channelID = (renderer["channelId"] as? String)
            ?? browseChannelID(from: renderer["navigationEndpoint"])
            ?? title.lowercased()

        let subscribers = text(from: renderer["subscriberCountText"])
            ?? text(from: renderer["videoCountText"])
            ?? ""
        let videos = text(from: renderer["videoCountText"]) ?? ""

        return YouTubeChannelResult(
            id: channelID,
            channelID: channelID,
            title: title,
            subscriberCountText: subscribers,
            videoCountText: videos,
            thumbnailURL: thumbnailURL(from: renderer["thumbnail"])
        )
    }

    private func browseChannelID(from value: Any?) -> String? {
        guard
            let dictionary = value as? [String: Any],
            let endpoint = dictionary["browseEndpoint"] as? [String: Any],
            let browseID = endpoint["browseId"] as? String,
            !browseID.isEmpty
        else {
            return nil
        }
        return browseID
    }

    private func text(from value: Any?) -> String? {
        guard let value else { return nil }

        if let string = value as? String, !string.isEmpty {
            return string
        }

        if let dictionary = value as? [String: Any] {
            if let simple = dictionary["simpleText"] as? String, !simple.isEmpty {
                return simple
            }
            if let runs = dictionary["runs"] as? [[String: Any]] {
                let joined = runs.compactMap { $0["text"] as? String }.joined()
                return joined.isEmpty ? nil : joined
            }
        }

        return nil
    }

    private func thumbnailURL(from value: Any?) -> URL? {
        guard
            let dictionary = value as? [String: Any],
            let thumbnails = dictionary["thumbnails"] as? [[String: Any]]
        else {
            return nil
        }

        let urlString = thumbnails.compactMap { $0["url"] as? String }.last
        guard let urlString, let url = URL(string: urlString) else {
            return nil
        }
        return url
    }
}

enum YouTubeSearchSuggestions {
    static let categories: [(title: String, query: String)] = [
        ("Português", "português para iniciantes"),
        ("Conversação", "conversação português"),
        ("Gramática", "gramática portuguesa"),
        ("Brasil", "vlog brasil português"),
        ("Música", "música brasileira legendada"),
        ("Podcast", "podcast português"),
    ]
}
