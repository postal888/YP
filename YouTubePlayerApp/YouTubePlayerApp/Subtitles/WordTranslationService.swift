import Foundation

struct WordTranslationEntry: Identifiable, Equatable {
    let id: String
    let source: String
    let translation: String

    init(source: String, translation: String) {
        self.source = source
        self.translation = translation
        self.id = source.lowercased()
    }
}

enum WordTranslationError: LocalizedError {
    case emptyInput
    case invalidResponse
    case network(String)

    var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "Пустое слово для перевода."
        case .invalidResponse:
            return "Сервис перевода вернул пустой ответ."
        case .network(let details):
            return details
        }
    }
}

actor WordTranslationService {
    static let shared = WordTranslationService()

    private var cache: [String: String] = [:]
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    static func targetLanguage(for sourceLanguage: String) -> String {
        sourceLanguage.lowercased() == "ru" ? "en" : "ru"
    }

    func cachedTranslation(for sourceWord: String, sourceLanguage: String) -> String? {
        let targetLanguage = Self.targetLanguage(for: sourceLanguage)
        return cache[cacheKey(sourceWord, sourceLanguage: sourceLanguage, targetLanguage: targetLanguage)]
    }

    func translate(
        _ sourceWord: String,
        sourceLanguage: String
    ) async throws -> String {
        let trimmed = sourceWord.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw WordTranslationError.emptyInput }

        let targetLanguage = Self.targetLanguage(for: sourceLanguage)
        let key = cacheKey(trimmed, sourceLanguage: sourceLanguage, targetLanguage: targetLanguage)
        if let cached = cache[key] {
            return cached
        }

        guard var components = URLComponents(string: "https://api.mymemory.translated.net/get") else {
            throw WordTranslationError.network("Некорректный URL перевода.")
        }

        components.queryItems = [
            URLQueryItem(name: "q", value: trimmed),
            URLQueryItem(name: "langpair", value: "\(sourceLanguage)|\(targetLanguage)")
        ]

        guard let url = components.url else {
            throw WordTranslationError.network("Некорректный URL перевода.")
        }

        var request = URLRequest(url: url, timeoutInterval: 12)
        request.setValue("YouTubePlayerApp/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw WordTranslationError.network("HTTP ошибка перевода.")
        }

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let responseData = json["responseData"] as? [String: Any],
            let translated = responseData["translatedText"] as? String
        else {
            throw WordTranslationError.invalidResponse
        }

        let cleaned = translated.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            throw WordTranslationError.invalidResponse
        }

        cache[key] = cleaned
        return cleaned
    }

    private func cacheKey(_ word: String, sourceLanguage: String, targetLanguage: String) -> String {
        "\(word.lowercased())::\(sourceLanguage)->\(targetLanguage)"
    }
}
