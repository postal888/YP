import Foundation
#if canImport(WebKit)
import WebKit
#endif

enum YouTubePlayerLoadStrategy: Equatable {
    case inlineHTML
    case hostedProxy
    case directEmbed
}

enum YouTubePlayerWebLoader {
    static let hostedProxyBaseURL = "https://cdn.jsdelivr.net/gh/postal888/YP@main/YouTubePlayer/Sources/YouTubePlayer/Resources/youtube-embed.html"
    static let referer = "https://www.youtube.com/"
    static let embedOrigin = "https://www.youtube.com"

    static func nextFallback(after strategy: YouTubePlayerLoadStrategy) -> YouTubePlayerLoadStrategy? {
        switch strategy {
        case .inlineHTML: return .hostedProxy
        case .hostedProxy: return .directEmbed
        case .directEmbed: return nil
        }
    }

    static func request(
        for configuration: YouTubePlayerConfiguration,
        strategy: YouTubePlayerLoadStrategy,
        captionLanguage: String = "pt"
    ) -> URLRequest? {
        switch strategy {
        case .inlineHTML:
            return nil
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

    static func inlineHTML(for configuration: YouTubePlayerConfiguration) -> String {
        let safeId = configuration.videoID.replacingOccurrences(of: "'", with: "")
        let safeLang = configuration.captionLanguage.replacingOccurrences(of: "'", with: "")
        let startJs = configuration.startTime > 1 ? "start: \(Int(configuration.startTime))," : ""
        let controls = configuration.showControls ? 1 : 0
        let autoplay = configuration.autoplay ? 1 : 0

        return """
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="referrer" content="strict-origin-when-cross-origin">
          <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1">
          <style>html,body{margin:0;height:100%;background:#000}#p{width:100%;height:100%}</style>
        </head>
        <body>
          <div id="p"></div>
          <script>
            function post(msg) {
              try { window.webkit.messageHandlers.youtube.postMessage(msg); } catch (e) {}
            }

            var playerReady = false;

            window.onYouTubeIframeAPIReady = function() {
              window.ytPlayer = new YT.Player('p', {
                host: 'https://www.youtube-nocookie.com',
                videoId: '\(safeId)',
                playerVars: {
                  playsinline: \(configuration.playsInline ? 1 : 0),
                  rel: 0,
                  enablejsapi: 1,
                  origin: '\(embedOrigin)',
                  widget_referrer: '\(embedOrigin)',
                  cc_load_policy: 1,
                  cc_lang_pref: '\(safeLang)',
                  modestbranding: 1,
                  controls: \(controls),
                  autoplay: \(autoplay),
                  \(startJs)
                },
                events: {
                  onReady: function() {
                    playerReady = true;
                    post({ event: 'ready' });
                    setInterval(function() {
                      if (!window.ytPlayer || !window.ytPlayer.getCurrentTime) return;
                      post({
                        event: 'time',
                        currentTime: window.ytPlayer.getCurrentTime(),
                        playerState: window.ytPlayer.getPlayerState()
                      });
                    }, 250);
                  },
                  onStateChange: function(e) { post({ event: 'state', playerState: e.data }); },
                  onError: function(e) { post({ event: 'error', code: e.data }); }
                }
              });
            };

            var apiTag = document.createElement('script');
            apiTag.src = 'https://www.youtube.com/iframe_api';
            apiTag.onerror = function() {
              post({ event: 'error', message: 'Failed to load YouTube iframe API' });
            };
            document.head.appendChild(apiTag);

            window.setTimeout(function() {
              if (!playerReady) {
                post({ event: 'error', message: 'YouTube iframe API load timeout' });
              }
            }, 12000);
          </script>
        </body>
        </html>
        """
    }

    static func directEmbedHTML(for configuration: YouTubePlayerConfiguration) -> String {
        guard let embedURL = directEmbedRequest(for: configuration)?.url?.absoluteString else {
            return inlineHTML(for: configuration)
        }
        let escapedURL = embedURL
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")

        return """
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="referrer" content="strict-origin-when-cross-origin">
          <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1">
          <style>html,body{margin:0;height:100%;background:#000}iframe{border:0;width:100%;height:100%}</style>
        </head>
        <body>
          <iframe id="player" referrerpolicy="strict-origin-when-cross-origin" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe>
          <script>
            function post(msg) {
              try { window.webkit.messageHandlers.youtube.postMessage(msg); } catch (e) {}
            }

            var iframe = document.getElementById('player');
            var readySent = false;

            function markReady() {
              if (readySent) return;
              readySent = true;
              post({ event: 'ready' });
            }

            iframe.src = '\(escapedURL)';

            window.addEventListener('message', function(event) {
              if (!event.origin || event.origin.indexOf('youtube.com') < 0) return;
              var data = event.data;
              if (typeof data === 'string') {
                try { data = JSON.parse(data); } catch (e) { return; }
              }
              if (!data || !data.event) return;
              if (data.event === 'onReady' || data.event === 'ready') {
                markReady();
              }
              if (data.event === 'infoDelivery' && data.info) {
                post({
                  event: 'time',
                  currentTime: data.info.currentTime || 0,
                  duration: data.info.duration || 0,
                  playerState: data.info.playerState
                });
              }
              if (data.event === 'onError' && typeof data.info === 'number') {
                post({ event: 'error', code: data.info });
              }
            });

            iframe.addEventListener('load', function() {
              window.setTimeout(function() {
                try {
                  iframe.contentWindow.postMessage(JSON.stringify({ event: 'listening', id: 1 }), '*');
                } catch (e) {}
                markReady();
              }, 500);
            });

            window.setTimeout(function() {
              if (!readySent) {
                post({ event: 'error', message: 'Direct embed iframe load timeout' });
              }
            }, 12000);
          </script>
        </body>
        </html>
        """
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

    #if canImport(WebKit)
    static func load(
        configuration: YouTubePlayerConfiguration,
        in webView: WKWebView,
        strategy: YouTubePlayerLoadStrategy
    ) -> Bool {
        switch strategy {
        case .inlineHTML:
            let html = inlineHTML(for: configuration)
            webView.loadHTMLString(html, baseURL: URL(string: referer))
            return true

        case .directEmbed:
            let html = directEmbedHTML(for: configuration)
            webView.loadHTMLString(html, baseURL: URL(string: referer))
            return true

        case .hostedProxy:
            guard let request = request(for: configuration, strategy: strategy, captionLanguage: configuration.captionLanguage) else {
                return false
            }
            webView.load(request)
            return true
        }
    }
    #endif

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

    static func isRecoverableLoadError(_ message: String) -> Bool {
        isRefererError(message)
            || message.lowercased().contains("timeout")
            || message.lowercased().contains("iframe api")
    }
}
