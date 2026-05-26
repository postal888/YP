import Foundation

public actor YouTubeTranscriptFetcher {
    public static let shared = YouTubeTranscriptFetcher()

    private let session: URLSession
    private let innertubeURL = URL(string: "https://www.youtube.com/youtubei/v1/player?prettyPrint=false")!
    private let innertubeAndroidVersion = "20.10.38"
    private let captionUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/85.0.4183.83 Safari/537.36,gzip(gfe)"

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func fetchSubtitleLines(videoID: String, preferredLanguage: String = "pt") async throws -> [YouTubeSubtitleLine] {
        let langCandidates = languageCandidates(for: preferredLanguage)
        var lastError = YouTubeTranscriptError.emptyTranscript("Субтитры недоступны.")

        for language in langCandidates {
            do {
                let segments = try await fetchTranscript(videoID: videoID, preferredLanguage: language)
                let lines = YouTubeTranscriptParser.mergeSegmentsIntoLines(segments)
                if !lines.isEmpty {
                    return lines
                }
                lastError = .emptyTranscript("Субтитры пустые после обработки.")
            } catch let error as YouTubeTranscriptError {
                lastError = error
            } catch {
                lastError = .network(error.localizedDescription)
            }
        }

        throw lastError
    }

    public func fetchTranscript(videoID: String, preferredLanguage: String? = nil) async throws -> [YouTubeTranscriptSegment] {
        var tracks = try await fetchCaptionTracksViaInnertube(videoID: videoID)
        if tracks.isEmpty {
            let html = try await fetchWatchPageHTML(videoID: videoID)
            tracks = extractCaptionTracks(from: html)
        }

        guard !tracks.isEmpty else {
            throw YouTubeTranscriptError.noCaptionTracks
        }

        guard let selected = pickCaptionTrack(from: tracks, preferredLanguage: preferredLanguage),
              let baseURL = selected.baseUrl else {
            throw YouTubeTranscriptError.noMatchingTrack
        }

        return try await downloadCaptionSegments(baseURL: baseURL, preferredLanguage: preferredLanguage)
    }

    private func languageCandidates(for language: String) -> [String?] {
        var seen = Set<String>()
        var result: [String?] = []

        func append(_ value: String?) {
            let key = value ?? ""
            guard !seen.contains(key) else { return }
            seen.insert(key)
            result.append(value)
        }

        append(language)
        append("pt")
        append("pt-BR")
        append("en")
        append(nil)
        return result
    }

    private func fetchCaptionTracksViaInnertube(videoID: String) async throws -> [CaptionTrack] {
        var request = URLRequest(url: innertubeURL, timeoutInterval: 12)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(
            "com.google.android.youtube/\(innertubeAndroidVersion) (Linux; U; Android 14)",
            forHTTPHeaderField: "User-Agent"
        )

        let body: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "ANDROID",
                    "clientVersion": innertubeAndroidVersion
                ]
            ],
            "videoId": videoID
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            return []
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }

        return captionTracks(from: json)
    }

    private func fetchWatchPageHTML(videoID: String) async throws -> String {
        guard let url = URL(string: "https://www.youtube.com/watch?v=\(videoID.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? videoID)&hl=pt") else {
            throw YouTubeTranscriptError.network("Некорректный URL видео.")
        }

        var request = URLRequest(url: url, timeoutInterval: 12)
        request.setValue(captionUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("pt-BR,pt;q=0.9,en-US;q=0.8,en;q=0.7", forHTTPHeaderField: "Accept-Language")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw YouTubeTranscriptError.network("Не удалось загрузить страницу видео.")
        }

        let html = String(data: data, encoding: .utf8) ?? ""
        guard html.count > 1000 else {
            throw YouTubeTranscriptError.network("Пустой ответ YouTube.")
        }
        return html
    }

    private func downloadCaptionSegments(baseURL: String, preferredLanguage: String?) async throws -> [YouTubeTranscriptSegment] {
        var captionURL = baseURL
        if !captionURL.hasPrefix("http") {
            captionURL = "https://www.youtube.com\(captionURL.hasPrefix("/") ? "" : "/")\(captionURL)"
        }

        let candidates = uniqueURLs([
            captionURL,
            captionURLWithFormat(captionURL, format: "srv3"),
            captionURLWithFormat(captionURL, format: "srv1"),
            captionURLWithFormat(captionURL, format: "vtt"),
            captionURLWithFormat(captionURL, format: "json3")
        ])

        var lastError = "Дорожка субтитров пустая или не распознана."

        for urlString in candidates {
            guard let url = URL(string: urlString) else { continue }

            var request = URLRequest(url: url, timeoutInterval: 12)
            request.setValue(captionUserAgent, forHTTPHeaderField: "User-Agent")
            if let preferredLanguage {
                request.setValue(preferredLanguage, forHTTPHeaderField: "Accept-Language")
            }

            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else { continue }
                guard http.statusCode == 200 else {
                    lastError = "HTTP \(http.statusCode)"
                    continue
                }

                let text = String(data: data, encoding: .utf8) ?? ""
                guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    lastError = "Пустой ответ YouTube timedtext"
                    continue
                }

                let parsed = YouTubeTranscriptParser.parseCaptionPayload(text)
                if !parsed.isEmpty {
                    return parsed
                }
            } catch {
                lastError = error.localizedDescription
            }
        }

        throw YouTubeTranscriptError.emptyTranscript(lastError)
    }

    private func captionURLWithFormat(_ baseURL: String, format: String) -> String {
        guard var components = URLComponents(string: baseURL) else {
            let separator = baseURL.contains("?") ? "&" : "?"
            return "\(baseURL)\(separator)fmt=\(format)"
        }
        var queryItems = components.queryItems ?? []
        queryItems.removeAll { $0.name == "fmt" }
        queryItems.append(URLQueryItem(name: "fmt", value: format))
        components.queryItems = queryItems
        return components.string ?? baseURL
    }

    private func uniqueURLs(_ urls: [String]) -> [String] {
        var seen = Set<String>()
        return urls.filter { seen.insert($0).inserted }
    }

    private func extractCaptionTracks(from html: String) -> [CaptionTrack] {
        if let regex = try? NSRegularExpression(pattern: #""captionTracks":(\[[\s\S]*?\])"#),
           let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..<html.endIndex, in: html)),
           let jsonRange = Range(match.range(at: 1), in: html),
           let data = String(html[jsonRange]).data(using: .utf8),
           let tracks = try? JSONDecoder().decode([CaptionTrack].self, from: data) {
            return tracks
        }

        for marker in ["ytInitialPlayerResponse =", "var ytInitialPlayerResponse ="] {
            guard let jsonObject = extractJSONObject(after: marker, in: html),
                  let data = jsonObject.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }
            let tracks = captionTracks(from: json)
            if !tracks.isEmpty {
                return tracks
            }
        }

        return []
    }

    private func extractJSONObject(after marker: String, in html: String) -> String? {
        guard let markerRange = html.range(of: marker) else { return nil }
        guard let startBrace = html[markerRange.upperBound...].firstIndex(of: "{") else { return nil }

        var depth = 0
        var inString = false
        var isEscaped = false

        let chars = Array(html[startBrace...])
        for (index, character) in chars.enumerated() {
            if inString {
                if isEscaped {
                    isEscaped = false
                } else if character == "\\" {
                    isEscaped = true
                } else if character == "\"" {
                    inString = false
                }
                continue
            }

            if character == "\"" {
                inString = true
                continue
            }

            if character == "{" {
                depth += 1
            } else if character == "}" {
                depth -= 1
                if depth == 0 {
                    let endIndex = html.index(startBrace, offsetBy: index)
                    return String(html[startBrace...endIndex])
                }
            }
        }

        return nil
    }

    private func captionTracks(from json: [String: Any]) -> [CaptionTrack] {
        guard let captions = json["captions"] as? [String: Any],
              let renderer = captions["playerCaptionsTracklistRenderer"] as? [String: Any],
              let rawTracks = renderer["captionTracks"] as? [[String: Any]] else {
            return []
        }

        return rawTracks.compactMap { track in
            CaptionTrack(
                languageCode: track["languageCode"] as? String,
                kind: track["kind"] as? String,
                baseUrl: track["baseUrl"] as? String
            )
        }
    }

    private func pickCaptionTrack(from tracks: [CaptionTrack], preferredLanguage: String?) -> CaptionTrack? {
        guard !tracks.isEmpty else { return nil }

        let languageOrder = [preferredLanguage, "pt-BR", "pt", "en"].compactMap { $0 }
        for language in languageOrder {
            if let track = tracks.first(where: {
                ($0.languageCode?.lowercased() ?? "") == language.lowercased() && $0.baseUrl != nil
            }) {
                return track
            }
        }

        if let portuguese = tracks.first(where: {
            ($0.languageCode?.lowercased() ?? "").hasPrefix("pt") && $0.baseUrl != nil
        }) {
            return portuguese
        }

        if let manual = tracks.first(where: { $0.kind != "asr" && $0.baseUrl != nil }) {
            return manual
        }

        return tracks.first(where: { $0.baseUrl != nil })
    }
}

private struct CaptionTrack: Decodable {
    let languageCode: String?
    let kind: String?
    let baseUrl: String?
}
