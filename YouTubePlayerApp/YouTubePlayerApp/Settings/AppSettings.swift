import Foundation
import Combine

@MainActor
final class AppSettings: ObservableObject {
    static let defaultBackendURL = "https://gentechnet.com"

    private enum Keys {
        static let useChatGPT = "portulearn.settings.useChatGPTTranslation"
        static let backendURL = "portulearn.settings.backendBaseURL"
    }

    @Published var useChatGPTTranslation: Bool {
        didSet { UserDefaults.standard.set(useChatGPTTranslation, forKey: Keys.useChatGPT) }
    }

    @Published var backendBaseURL: String {
        didSet {
            let trimmed = backendBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalized = trimmed.isEmpty ? Self.defaultBackendURL : trimmed
            if normalized != backendBaseURL {
                backendBaseURL = normalized
            }
            UserDefaults.standard.set(normalized, forKey: Keys.backendURL)
        }
    }

    init() {
        useChatGPTTranslation = UserDefaults.standard.bool(forKey: Keys.useChatGPT)
        backendBaseURL = UserDefaults.standard.string(forKey: Keys.backendURL) ?? Self.defaultBackendURL
    }

    var normalizedBackendURL: String {
        var url = backendBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if url.hasSuffix("/") {
            url.removeLast()
        }
        return url.isEmpty ? Self.defaultBackendURL : url
    }
}
