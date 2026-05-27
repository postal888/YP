import Foundation

enum VocabularyFolderKey {
    static let misc = "misc"
    static let legacyYouTube = "yt:legacy"

    static func youtube(_ videoID: String) -> String {
        "yt:\(videoID)"
    }

    static func pdf(_ bookTitle: String) -> String {
        let normalized = bookTitle
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return normalized.isEmpty ? "pdf:unknown" : "pdf:\(normalized)"
    }

    static func defaultTitle(for key: String, fallback: String? = nil) -> String {
        if key == misc { return "Разное" }
        if key == legacyYouTube { return "YouTube" }
        if key.hasPrefix("yt:") {
            let videoID = String(key.dropFirst(3))
            return fallback ?? "YouTube · \(videoID)"
        }
        if key.hasPrefix("pdf:") {
            let slug = String(key.dropFirst(4))
            return slug.isEmpty ? "PDF" : slug.capitalized(with: Locale.current)
        }
        return fallback ?? key
    }
}

struct VocabularyFolderGroup: Identifiable, Equatable {
    let key: String
    let title: String
    let cards: [VocabularyCard]

    var id: String { key }

    var isYouTube: Bool {
        key.hasPrefix("yt:")
    }
}
