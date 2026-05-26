import Foundation

/// Утилита для извлечения ID видео из разных форматов YouTube-ссылок.
public enum YouTubeVideoIDExtractor {
    public static func extract(from input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.range(of: #"^[a-zA-Z0-9_-]{11}$"#, options: .regularExpression) != nil {
            return trimmed
        }

        guard let url = URL(string: trimmed), let host = url.host?.lowercased() else {
            return nil
        }

        if host.contains("youtu.be") {
            let id = url.pathComponents.dropFirst().first
            return id?.count == 11 ? id : nil
        }

        if host.contains("youtube.com") {
            if url.path.contains("/embed/") {
                let id = url.pathComponents.last
                return id?.count == 11 ? id : nil
            }

            if let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
               let id = queryItems.first(where: { $0.name == "v" })?.value,
               id.count == 11 {
                return id
            }
        }

        return nil
    }
}
