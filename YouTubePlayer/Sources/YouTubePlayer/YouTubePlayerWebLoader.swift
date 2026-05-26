import Foundation

enum YouTubePlayerWebLoader {
    static let proxyBaseURL = "https://cdn.jsdelivr.net/gh/postal888/YP@main/YouTubePlayer/Sources/YouTubePlayer/Resources/youtube-embed.html"
    static let fallbackProxyBaseURL = "https://cdn.jsdelivr.net/gh/postal888/portmob_ios@main/youtube-embed.html"
    static let referer = "https://www.youtube.com/"

    static func proxyRequest(
        for configuration: YouTubePlayerConfiguration,
        captionLanguage: String = "pt"
    ) -> URLRequest? {
        guard var components = URLComponents(string: proxyBaseURL) else { return nil }

        var queryItems = [
            URLQueryItem(name: "v", value: configuration.videoID),
            URLQueryItem(name: "cc_lang_pref", value: captionLanguage)
        ]

        if configuration.startTime > 1 {
            queryItems.append(URLQueryItem(name: "start", value: String(Int(configuration.startTime))))
        }

        components.queryItems = queryItems
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url, timeoutInterval: 30)
        request.setValue(referer, forHTTPHeaderField: "Referer")
        request.setValue(referer, forHTTPHeaderField: "Origin")
        return request
    }

    static let bridgeScriptSource = """
    (function () {
      window.addEventListener('message', function (event) {
        var data = event.data;
        if (!data || typeof data !== 'object' || data.source !== 'portuprep-yt') {
          return;
        }
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.youtube) {
          window.webkit.messageHandlers.youtube.postMessage(data);
        }
      });
    })();
    """
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
}
