import Foundation

enum YouTubeVideoMetadataService {
    static func fetchTitle(videoID: String) async -> String? {
        guard var components = URLComponents(string: "https://www.youtube.com/oembed") else {
            return nil
        }
        components.queryItems = [
            URLQueryItem(name: "url", value: "https://www.youtube.com/watch?v=\(videoID)"),
            URLQueryItem(name: "format", value: "json")
        ]
        guard let url = components.url else { return nil }

        do {
            var request = URLRequest(url: url, timeoutInterval: 12)
            request.setValue("YouTubePlayerApp/1.0", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            guard
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                let title = json["title"] as? String
            else { return nil }
            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        } catch {
            return nil
        }
    }
}
