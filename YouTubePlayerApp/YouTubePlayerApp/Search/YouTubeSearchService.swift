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

    func search(query: String) async throws -> [YouTubeSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw YouTubeSearchError.emptyQuery }

        var request = URLRequest(url: searchURL, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(
            "com.google.android.youtube/\(clientVersion) (Linux; U; Android 14)",
            forHTTPHeaderField: "User-Agent"
        )

        let body: [String: Any] = [
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
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw YouTubeSearchError.network("Нет ответа от YouTube.")
        }
        guard http.statusCode == 200 else {
            throw YouTubeSearchError.network("YouTube вернул HTTP \(http.statusCode).")
        }

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw YouTubeSearchError.parseFailed
        }

        let renderers = collectVideoRenderers(from: json)
        var seen = Set<String>()
        var results: [YouTubeSearchResult] = []

        for renderer in renderers {
            guard let parsed = parseVideoRenderer(renderer), !seen.contains(parsed.videoID) else {
                continue
            }
            seen.insert(parsed.videoID)
            results.append(parsed)
            if results.count >= 24 {
                break
            }
        }

        return results
    }

    private func collectVideoRenderers(from json: Any) -> [[String: Any]] {
        var output: [[String: Any]] = []

        if let dictionary = json as? [String: Any] {
            for key in ["videoRenderer", "gridVideoRenderer", "compactVideoRenderer", "playlistVideoRenderer"] {
                if let renderer = dictionary[key] as? [String: Any] {
                    output.append(renderer)
                }
            }
            for value in dictionary.values {
                output.append(contentsOf: collectVideoRenderers(from: value))
            }
        } else if let array = json as? [Any] {
            for value in array {
                output.append(contentsOf: collectVideoRenderers(from: value))
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
