#if canImport(UIKit)
import SwiftUI
import WebKit

@MainActor
struct YouTubePlayerWebView: UIViewRepresentable {
    let configuration: YouTubePlayerConfiguration
    @ObservedObject var controller: YouTubePlayerController

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.allowsInlineMediaPlayback = true
        webConfiguration.mediaTypesRequiringUserActionForPlayback = []
        webConfiguration.defaultWebpagePreferences.allowsContentJavaScript = true

        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "youtube")
        webConfiguration.userContentController = userContentController

        let webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        webView.navigationDelegate = context.coordinator

        context.coordinator.webView = webView
        context.coordinator.loadPlayer(configuration: configuration, in: webView)

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if context.coordinator.configuration != configuration {
            context.coordinator.configuration = configuration
            context.coordinator.loadPlayer(configuration: configuration, in: webView)
        }

        if let command = controller.consumePendingCommand() {
            context.coordinator.execute(command)
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var configuration: YouTubePlayerConfiguration
        weak var webView: WKWebView?
        private let controller: YouTubePlayerController
        private var usingProxyFallback = false

        init(controller: YouTubePlayerController, configuration: YouTubePlayerConfiguration? = nil) {
            self.controller = controller
            self.configuration = configuration ?? YouTubePlayerConfiguration(videoID: "")
        }

        func loadPlayer(configuration: YouTubePlayerConfiguration, in webView: WKWebView) {
            self.configuration = configuration
            usingProxyFallback = false
            controller.markLoadingStarted()
            controller.scheduleLoadTimeout()

            let html = YouTubePlayerWebLoader.inlineHTML(for: configuration)
            webView.loadHTMLString(html, baseURL: URL(string: YouTubePlayerWebLoader.referer)!)
        }

        private func loadProxyFallback(in webView: WKWebView) {
            guard !usingProxyFallback,
                  let request = YouTubePlayerWebLoader.proxyRequest(
                    for: configuration,
                    captionLanguage: configuration.captionLanguage
                  ) else {
                controller.handleBridgeMessage(.error("Failed to load YouTube player"))
                return
            }

            usingProxyFallback = true
            controller.markLoadingStarted()
            controller.scheduleLoadTimeout()

            let userContentController = webView.configuration.userContentController
            userContentController.removeAllUserScripts()
            userContentController.addUserScript(
                WKUserScript(
                    source: YouTubePlayerWebLoader.bridgeScriptSource,
                    injectionTime: .atDocumentStart,
                    forMainFrameOnly: true
                )
            )

            webView.load(request)
        }

        func execute(_ command: YouTubePlayerCommand) {
            switch command {
            case .play:
                evaluate("if(window.ytPlayer){window.ytPlayer.playVideo();}")

            case .pause:
                evaluate("if(window.ytPlayer){window.ytPlayer.pauseVideo();}")

            case .seek(let seconds):
                evaluate("if(window.ytPlayer){window.ytPlayer.seekTo(\(seconds), true);}")

            case .load(let videoID, let startTime):
                var updated = configuration
                updated.videoID = videoID
                updated.startTime = startTime
                configuration = updated
                if let webView {
                    loadPlayer(configuration: updated, in: webView)
                }
            }
        }

        private func evaluate(_ script: String) {
            webView?.evaluateJavaScript(script, completionHandler: nil)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard !controller.state.isReady else { return }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor [weak self] in
                guard let self else { return }
                if !usingProxyFallback {
                    loadProxyFallback(in: webView)
                } else {
                    controller.handleBridgeMessage(.error("WebView load failed: \(error.localizedDescription)"))
                }
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor [weak self] in
                guard let self else { return }
                if !usingProxyFallback {
                    loadProxyFallback(in: webView)
                } else {
                    controller.handleBridgeMessage(.error("WebView load failed: \(error.localizedDescription)"))
                }
            }
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "youtube",
                  let bridgeMessage = BridgeMessage(body: message.body) else {
                return
            }

            Task { @MainActor [controller] in
                controller.handleBridgeMessage(bridgeMessage)
            }
        }
    }
}

private extension YouTubePlayerState {
    var isReady: Bool {
        switch self {
        case .ready, .playing, .paused, .buffering, .ended:
            return true
        case .idle, .loading, .error:
            return false
        }
    }
}
#endif

#if canImport(AppKit)
import SwiftUI
import WebKit

@MainActor
struct YouTubePlayerWebView: NSViewRepresentable {
    let configuration: YouTubePlayerConfiguration
    @ObservedObject var controller: YouTubePlayerController

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller)
    }

    func makeNSView(context: Context) -> WKWebView {
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.mediaTypesRequiringUserActionForPlayback = []

        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "youtube")
        webConfiguration.userContentController = userContentController

        let webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.setValue(false, forKey: "drawsBackground")

        context.coordinator.webView = webView
        context.coordinator.loadPlayer(configuration: configuration, in: webView)

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        if context.coordinator.configuration != configuration {
            context.coordinator.configuration = configuration
            context.coordinator.loadPlayer(configuration: configuration, in: webView)
        }

        if let command = controller.consumePendingCommand() {
            context.coordinator.execute(command)
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var configuration: YouTubePlayerConfiguration
        weak var webView: WKWebView?
        private let controller: YouTubePlayerController

        init(controller: YouTubePlayerController, configuration: YouTubePlayerConfiguration? = nil) {
            self.controller = controller
            self.configuration = configuration ?? YouTubePlayerConfiguration(videoID: "")
        }

        func loadPlayer(configuration: YouTubePlayerConfiguration, in webView: WKWebView) {
            self.configuration = configuration
            controller.markLoadingStarted()
            controller.scheduleLoadTimeout()

            let html = YouTubePlayerWebLoader.inlineHTML(for: configuration)
            webView.loadHTMLString(html, baseURL: URL(string: YouTubePlayerWebLoader.referer)!)
        }

        func execute(_ command: YouTubePlayerCommand) {
            switch command {
            case .play:
                evaluate("if(window.ytPlayer){window.ytPlayer.playVideo();}")

            case .pause:
                evaluate("if(window.ytPlayer){window.ytPlayer.pauseVideo();}")

            case .seek(let seconds):
                evaluate("if(window.ytPlayer){window.ytPlayer.seekTo(\(seconds), true);}")

            case .load(let videoID, let startTime):
                var updated = configuration
                updated.videoID = videoID
                updated.startTime = startTime
                configuration = updated
                if let webView {
                    loadPlayer(configuration: updated, in: webView)
                }
            }
        }

        private func evaluate(_ script: String) {
            webView?.evaluateJavaScript(script, completionHandler: nil)
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "youtube",
                  let bridgeMessage = BridgeMessage(body: message.body) else {
                return
            }

            Task { @MainActor [controller] in
                controller.handleBridgeMessage(bridgeMessage)
            }
        }
    }
}
#endif
