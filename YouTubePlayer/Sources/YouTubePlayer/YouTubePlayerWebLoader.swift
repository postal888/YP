import Foundation

enum YouTubePlayerWebLoader {
    static let referer = "https://www.youtube.com/"
    static let embedOrigin = "https://www.youtube.com"

    static func inlineHTML(for configuration: YouTubePlayerConfiguration) -> String {
        let videoID = sanitize(configuration.videoID)
        let captionLanguage = sanitize(configuration.captionLanguage)
        let startSeconds = configuration.startTime > 1 ? Int(configuration.startTime) : 0
        let startLine = startSeconds > 0 ? "start: \(startSeconds)," : ""
        let pollMs = max(250, Int(configuration.progressPollingInterval * 1000))

        return """
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="referrer" content="strict-origin-when-cross-origin">
          <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1">
          <style>html,body{margin:0;height:100%;background:#000}#p{width:100%;height:100%}</style>
          <script src="https://www.youtube.com/iframe_api"></script>
        </head>
        <body>
          <div id="p"></div>
          <script>
            function post(msg) {
              try {
                window.webkit.messageHandlers.youtube.postMessage(msg);
              } catch (e) {}
            }
            function onYouTubeIframeAPIReady() {
              window.ytPlayer = new YT.Player('p', {
                host: 'https://www.youtube-nocookie.com',
                videoId: '\(videoID)',
                playerVars: {
                  playsinline: 1,
                  rel: 0,
                  enablejsapi: 1,
                  origin: '\(embedOrigin)',
                  widget_referrer: '\(embedOrigin)',
                  cc_load_policy: 1,
                  cc_lang_pref: '\(captionLanguage)',
                  modestbranding: 1,
                  controls: \(configuration.showControls ? 1 : 0),
                  fs: \(configuration.allowFullscreen ? 1 : 0),
                  autoplay: \(configuration.autoplay ? 1 : 0),
                  \(startLine)
                },
                events: {
                  onReady: function() {
                    post({ event: 'ready' });
                    setInterval(function() {
                      if (!window.ytPlayer || !window.ytPlayer.getCurrentTime) return;
                      post({
                        event: 'time',
                        currentTime: window.ytPlayer.getCurrentTime(),
                        duration: window.ytPlayer.getDuration(),
                        playerState: window.ytPlayer.getPlayerState()
                      });
                    }, \(pollMs));
                  },
                  onStateChange: function(e) {
                    post({ event: 'state', playerState: e.data });
                  },
                  onError: function(e) {
                    post({ event: 'error', code: e.data });
                  }
                }
              });
            }
          </script>
        </body>
        </html>
        """
    }

    static func proxyRequest(
        for configuration: YouTubePlayerConfiguration,
        captionLanguage: String = "pt"
    ) -> URLRequest? {
        let baseURL = "https://cdn.jsdelivr.net/gh/postal888/portmob_ios@main/youtube-embed.html"
        guard var components = URLComponents(string: baseURL) else { return nil }

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

    private static func sanitize(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "\n", with: "")
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
}
