import Foundation

enum YouTubePlayerLoadStrategy: Equatable {
    case hostedProxy
    case directEmbed
}

enum YouTubePlayerWebLoader {
    static let hostedProxyBaseURL = "https://cdn.jsdelivr.net/gh/postal888/portmob_ios@main/youtube-embed.html"
    static let referer = "https://www.youtube.com/"
    static let embedOrigin = "https://www.youtube.com"

    static func request(
        for configuration: YouTubePlayerConfiguration,
        strategy: YouTubePlayerLoadStrategy,
        captionLanguage: String = "pt"
    ) -> URLRequest? {
        switch strategy {
        case .hostedProxy:
            return hostedProxyRequest(for: configuration, captionLanguage: captionLanguage)
        case .directEmbed:
            return directEmbedRequest(for: configuration)
        }
    }

    static func hostedProxyRequest(
        for configuration: YouTubePlayerConfiguration,
        captionLanguage: String = "pt"
    ) -> URLRequest? {
        guard var components = URLComponents(string: hostedProxyBaseURL) else { return nil }

        var queryItems = [
            URLQueryItem(name: "v", value: configuration.videoID),
            URLQueryItem(name: "cc_lang_pref", value: captionLanguage)
        ]

        if configuration.startTime > 1 {
            queryItems.append(URLQueryItem(name: "start", value: String(Int(configuration.startTime))))
        }

        components.queryItems = queryItems
        guard let url = components.url else { return nil }

        return configuredRequest(url: url)
    }

    static func directEmbedRequest(for configuration: YouTubePlayerConfiguration) -> URLRequest? {
        guard var components = URLComponents(
            string: "\(embedOrigin)/embed/\(configuration.videoID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? configuration.videoID)"
        ) else {
            return nil
        }

        var queryItems = [
            URLQueryItem(name: "playsinline", value: "1"),
            URLQueryItem(name: "enablejsapi", value: "1"),
            URLQueryItem(name: "origin", value: embedOrigin),
            URLQueryItem(name: "widget_referrer", value: embedOrigin),
            URLQueryItem(name: "rel", value: "0"),
            URLQueryItem(name: "modestbranding", value: "1"),
            URLQueryItem(name: "controls", value: configuration.showControls ? "1" : "0")
        ]

        if configuration.startTime > 1 {
            queryItems.append(URLQueryItem(name: "start", value: String(Int(configuration.startTime))))
        }

        components.queryItems = queryItems
        guard let url = components.url else { return nil }

        return configuredRequest(url: url)
    }

    static let bridgeScriptSource = """
    (function () {
      function forward(data) {
        if (!data || typeof data !== 'object') return;
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.youtube) {
          window.webkit.messageHandlers.youtube.postMessage(data);
        }
      }

      window.addEventListener('message', function (event) {
        var data = event.data;
        if (!data || typeof data !== 'object') return;
        if (data.source === 'portuprep-yt') {
          forward(data);
          return;
        }
        if (event.origin && event.origin.indexOf('youtube.com') >= 0 && data.event === 'infoDelivery' && data.info) {
          forward({
            event: 'time',
            currentTime: data.info.currentTime || 0,
            duration: data.info.duration || 0,
            playerState: data.info.playerState
          });
        }
      });
    })();
    """

    static let directEmbedBootstrapScript = """
    (function () {
      if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.youtube) {
        window.webkit.messageHandlers.youtube.postMessage({ event: 'ready' });
      }
    })();
    """

    private static func configuredRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue(referer, forHTTPHeaderField: "Referer")
        request.setValue(embedOrigin, forHTTPHeaderField: "Origin")
        return request
    }
}

enum YouTubePlayerErrorMessages {
    static func message(for code: Int) -> String {
        switch code {
        case 2: return "Invalid parameter (code 2)"
        case 5: return "HTML5 player error (code 5)"
        case 100: return "Video not found or private (code 100)"
        case 101: return "Embedding disabled by owner (code 101)"
        case 150: return "Embedding disabled by owner (code 150)"
        case 152: return "Playback blocked: invalid referer/origin (code 152)"
        case 153: return "Missing HTTP Referer header (code 153)"
        default: return "YouTube error code \(code)"
        }
    }

    static func isRefererError(_ message: String) -> Bool {
        message.contains("152") || message.contains("153") || message.lowercased().contains("referer")
    }
}
