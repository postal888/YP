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

enum WordTranslationContext {
    case subtitle
    case reader
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

    func translate(
        _ sourceWord: String,
        sourceLanguage: String,
        context: WordTranslationContext = .subtitle,
        useChatGPT: Bool = false,
        backendBaseURL: String = AppSettings.defaultBackendURL
    ) async throws -> String {
        let trimmed = sourceWord.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw WordTranslationError.emptyInput }

        let targetLanguage = Self.targetLanguage(for: sourceLanguage)
        let key = cacheKey(trimmed, sourceLanguage: sourceLanguage, targetLanguage: targetLanguage, useChatGPT: useChatGPT, context: context)
        if let cached = cache[key] {
            return cached
        }

        let translated: String
        if useChatGPT {
            switch context {
            case .subtitle:
                translated = try await PortuPrepBackendService.shared.translateWord(trimmed, baseURL: backendBaseURL)
            case .reader:
                translated = try await PortuPrepBackendService.shared.translateBookText(trimmed, baseURL: backendBaseURL)
            }
        } else {
            translated = try await translateViaMyMemory(trimmed, sourceLanguage: sourceLanguage, targetLanguage: targetLanguage)
        }

        cache[key] = translated
        return translated
    }

    func cachedTranslation(
        for sourceWord: String,
        sourceLanguage: String,
        context: WordTranslationContext = .subtitle,
        useChatGPT: Bool = false
    ) -> String? {
        let targetLanguage = Self.targetLanguage(for: sourceLanguage)
        return cache[cacheKey(sourceWord, sourceLanguage: sourceLanguage, targetLanguage: targetLanguage, useChatGPT: useChatGPT, context: context)]
    }

    private func translateViaMyMemory(
        _ trimmed: String,
        sourceLanguage: String,
        targetLanguage: String
    ) async throws -> String {
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

        return cleaned
    }

    private func cacheKey(
        _ word: String,
        sourceLanguage: String,
        targetLanguage: String,
        useChatGPT: Bool,
        context: WordTranslationContext
    ) -> String {
        let backend = useChatGPT ? "gpt" : "mm"
        let ctx = context == .subtitle ? "sub" : "book"
        return "\(word.lowercased())::\(sourceLanguage)->\(targetLanguage)::\(backend)::\(ctx)"
    }
}
