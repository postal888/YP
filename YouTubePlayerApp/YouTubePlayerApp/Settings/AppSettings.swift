import Foundation
import Combine

@MainActor
final class AppSettings: ObservableObject {
    nonisolated static let defaultBackendURL = "https://gentechnet.com"

    private enum Keys {
        static let useChatGPT = "portulearn.settings.useChatGPTTranslation"
        static let backendURL = "portulearn.settings.backendBaseURL"
        static let backgroundVideoPlayback = "portulearn.settings.backgroundVideoPlayback"
        static let appLanguage = "portulearn.settings.appLanguage"
        static let readerFontScale = "portulearn.settings.readerFontScale"
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

    @Published var backgroundVideoPlayback: Bool {
        didSet { UserDefaults.standard.set(backgroundVideoPlayback, forKey: Keys.backgroundVideoPlayback) }
    }

    @Published var appLanguage: AppLanguage {
        didSet { UserDefaults.standard.set(appLanguage.rawValue, forKey: Keys.appLanguage) }
    }

    @Published var readerFontScale: Double {
        didSet {
            let clamped = min(max(readerFontScale, 0.85), 1.6)
            if clamped != readerFontScale {
                readerFontScale = clamped
                return
            }
            UserDefaults.standard.set(clamped, forKey: Keys.readerFontScale)
        }
    }

    init() {
        useChatGPTTranslation = UserDefaults.standard.bool(forKey: Keys.useChatGPT)
        backendBaseURL = UserDefaults.standard.string(forKey: Keys.backendURL) ?? Self.defaultBackendURL
        backgroundVideoPlayback = UserDefaults.standard.bool(forKey: Keys.backgroundVideoPlayback)
        let storedFontScale = UserDefaults.standard.object(forKey: Keys.readerFontScale) as? Double ?? 1.0
        readerFontScale = min(max(storedFontScale, 0.85), 1.6)
        if
            let raw = UserDefaults.standard.string(forKey: Keys.appLanguage),
            let language = AppLanguage(rawValue: raw)
        {
            appLanguage = language
        } else {
            appLanguage = .english
        }
    }

    var strings: AppStrings {
        AppStrings(language: appLanguage)
    }

    var normalizedBackendURL: String {
        var url = backendBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if url.hasSuffix("/") {
            url.removeLast()
        }
        return url.isEmpty ? Self.defaultBackendURL : url
    }
}
