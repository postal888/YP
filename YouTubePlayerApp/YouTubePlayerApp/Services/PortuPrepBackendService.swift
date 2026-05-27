import Foundation

enum PortuPrepBackendError: LocalizedError {
    case invalidURL
    case http(Int)
    case invalidResponse
    case missingTranslation

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Некорректный адрес сервера."
        case .http(let code):
            return "Ошибка сервера (\(code))."
        case .invalidResponse:
            return "Сервер вернул некорректный ответ."
        case .missingTranslation:
            return "Перевод не найден в ответе сервера."
        }
    }
}

actor PortuPrepBackendService {
    static let shared = PortuPrepBackendService()

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func translateWord(_ word: String, baseURL: String) async throws -> String {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw WordTranslationError.emptyInput }

        let url = try endpoint("/api/transcript-translate", baseURL: baseURL)
        var request = URLRequest(url: url, timeoutInterval: 25)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("YouTubePlayerApp/1.0", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["words": [trimmed]])

        let (data, response) = try await session.data(for: request)
        try validate(response)

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let gloss = json["gloss"] as? [String: Any]
        else {
            throw PortuPrepBackendError.invalidResponse
        }

        if let direct = gloss[trimmed] as? String, !direct.isEmpty {
            return direct.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let lowered = trimmed.lowercased()
        for (key, value) in gloss {
            if key.lowercased() == lowered, let translation = value as? String, !translation.isEmpty {
                return translation.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        throw PortuPrepBackendError.missingTranslation
    }

    func translateBookText(_ text: String, baseURL: String) async throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw WordTranslationError.emptyInput }

        let url = try endpoint("/api/book-translate", baseURL: baseURL)
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("YouTubePlayerApp/1.0", forHTTPHeaderField: "User-Agent")
        let payload = ["text": String(trimmed.prefix(12000))]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)
        try validate(response)

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let translation = json["translation"] as? String
        else {
            throw PortuPrepBackendError.invalidResponse
        }

        let cleaned = translation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { throw PortuPrepBackendError.missingTranslation }
        return cleaned
    }

    func synthesizeSpeech(text: String, languageCode: String?, baseURL: String) async throws -> Data {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw WordTranslationError.emptyInput }

        let url = try endpoint("/api/elevenlabs-tts", baseURL: baseURL)
        var request = URLRequest(url: url, timeoutInterval: 45)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("YouTubePlayerApp/1.0", forHTTPHeaderField: "User-Agent")

        var payload: [String: String] = ["text": String(trimmed.prefix(2500))]
        if languageCode == "pt" || languageCode == "ru" {
            payload["language_code"] = languageCode
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)
        try validate(response)

        let contentType = (response as? HTTPURLResponse)?
            .value(forHTTPHeaderField: "Content-Type") ?? ""
        guard contentType.contains("audio"), !data.isEmpty else {
            throw PortuPrepBackendError.invalidResponse
        }
        return data
    }

    private func endpoint(_ path: String, baseURL: String) throws -> URL {
        var base = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if base.hasSuffix("/") { base.removeLast() }
        guard let url = URL(string: base + path) else {
            throw PortuPrepBackendError.invalidURL
        }
        return url
    }

    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw PortuPrepBackendError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw PortuPrepBackendError.http(http.statusCode)
        }
    }
}
