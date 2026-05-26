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
        userContentController.addUserScript(
            WKUserScript(
                source: YouTubePlayerWebLoader.bridgeScriptSource,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
        )
        webConfiguration.userContentController = userContentController

        let webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        webView.navigationDelegate = context.coordinator

        context.coordinator.webView = webView
        context.coordinator.loadPlayer(configuration: configuration, in: webView, strategy: .inlineHTML)

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if context.coordinator.configuration != configuration {
            context.coordinator.configuration = configuration
            context.coordinator.loadPlayer(configuration: configuration, in: webView, strategy: .inlineHTML)
        }

        if let command = controller.consumePendingCommand() {
            context.coordinator.execute(command)
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var configuration: YouTubePlayerConfiguration
        weak var webView: WKWebView?
        private let controller: YouTubePlayerController
        private var loadStrategy: YouTubePlayerLoadStrategy = .inlineHTML

        init(controller: YouTubePlayerController, configuration: YouTubePlayerConfiguration? = nil) {
            self.controller = controller
            self.configuration = configuration ?? YouTubePlayerConfiguration(videoID: "")
        }

        func loadPlayer(
            configuration: YouTubePlayerConfiguration,
            in webView: WKWebView,
            strategy: YouTubePlayerLoadStrategy
        ) {
            self.configuration = configuration
            loadStrategy = strategy
            controller.markLoadingStarted()
            scheduleStrategyTimeout(for: webView)

            guard YouTubePlayerWebLoader.load(
                configuration: configuration,
                in: webView,
                strategy: strategy
            ) else {
                controller.handleBridgeMessage(.error("Failed to build YouTube player request"))
                return
            }
        }

        private func scheduleStrategyTimeout(for webView: WKWebView) {
            controller.scheduleLoadTimeout(seconds: 15) { [weak self] in
                guard let self else { return false }
                if YouTubePlayerWebLoader.nextFallback(after: loadStrategy) != nil {
                    retryWithNextStrategy(in: webView)
                    return true
                }
                return false
            }
        }

        private func retryWithNextStrategy(in webView: WKWebView) {
            guard let next = YouTubePlayerWebLoader.nextFallback(after: loadStrategy) else { return }
            loadPlayer(configuration: configuration, in: webView, strategy: next)
        }

        private func shouldRetry(for bridgeMessage: BridgeMessage) -> Bool {
            guard YouTubePlayerWebLoader.nextFallback(after: loadStrategy) != nil else { return false }
            if case .error(let text) = bridgeMessage {
                return YouTubePlayerErrorMessages.isRecoverableLoadError(text)
            }
            return false
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
                    loadPlayer(configuration: updated, in: webView, strategy: .inlineHTML)
                }
            }
        }

        private func evaluate(_ script: String) {
            webView?.evaluateJavaScript(script, completionHandler: nil)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Ready events come from injected page scripts.
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor [weak self] in
                guard let self else { return }
                if YouTubePlayerWebLoader.nextFallback(after: loadStrategy) != nil {
                    retryWithNextStrategy(in: webView)
                } else {
                    controller.handleBridgeMessage(.error("WebView load failed: \(error.localizedDescription)"))
                }
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor [weak self] in
                guard let self else { return }
                if YouTubePlayerWebLoader.nextFallback(after: loadStrategy) != nil {
                    retryWithNextStrategy(in: webView)
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

            Task { @MainActor [weak self] in
                guard let self, let webView else { return }

                if shouldRetry(for: bridgeMessage) {
                    retryWithNextStrategy(in: webView)
                    return
                }

                controller.handleBridgeMessage(bridgeMessage)
            }
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
        userContentController.addUserScript(
            WKUserScript(
                source: YouTubePlayerWebLoader.bridgeScriptSource,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
        )
        webConfiguration.userContentController = userContentController

        let webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = context.coordinator

        context.coordinator.webView = webView
        context.coordinator.loadPlayer(configuration: configuration, in: webView, strategy: .inlineHTML)

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        if context.coordinator.configuration != configuration {
            context.coordinator.configuration = configuration
            context.coordinator.loadPlayer(configuration: configuration, in: webView, strategy: .inlineHTML)
        }

        if let command = controller.consumePendingCommand() {
            context.coordinator.execute(command)
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var configuration: YouTubePlayerConfiguration
        weak var webView: WKWebView?
        private let controller: YouTubePlayerController
        private var loadStrategy: YouTubePlayerLoadStrategy = .inlineHTML

        init(controller: YouTubePlayerController, configuration: YouTubePlayerConfiguration? = nil) {
            self.controller = controller
            self.configuration = configuration ?? YouTubePlayerConfiguration(videoID: "")
        }

        func loadPlayer(
            configuration: YouTubePlayerConfiguration,
            in webView: WKWebView,
            strategy: YouTubePlayerLoadStrategy
        ) {
            self.configuration = configuration
            loadStrategy = strategy
            controller.markLoadingStarted()
            scheduleStrategyTimeout(for: webView)

            guard YouTubePlayerWebLoader.load(
                configuration: configuration,
                in: webView,
                strategy: strategy
            ) else {
                controller.handleBridgeMessage(.error("Failed to build YouTube player request"))
                return
            }
        }

        private func scheduleStrategyTimeout(for webView: WKWebView) {
            controller.scheduleLoadTimeout(seconds: 15) { [weak self] in
                guard let self else { return false }
                if YouTubePlayerWebLoader.nextFallback(after: loadStrategy) != nil {
                    retryWithNextStrategy(in: webView)
                    return true
                }
                return false
            }
        }

        private func retryWithNextStrategy(in webView: WKWebView) {
            guard let next = YouTubePlayerWebLoader.nextFallback(after: loadStrategy) else { return }
            loadPlayer(configuration: configuration, in: webView, strategy: next)
        }

        private func shouldRetry(for bridgeMessage: BridgeMessage) -> Bool {
            guard YouTubePlayerWebLoader.nextFallback(after: loadStrategy) != nil else { return false }
            if case .error(let text) = bridgeMessage {
                return YouTubePlayerErrorMessages.isRecoverableLoadError(text)
            }
            return false
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
                    loadPlayer(configuration: updated, in: webView, strategy: .inlineHTML)
                }
            }
        }

        private func evaluate(_ script: String) {
            webView?.evaluateJavaScript(script, completionHandler: nil)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Ready events come from injected page scripts.
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor [weak self] in
                guard let self else { return }
                if YouTubePlayerWebLoader.nextFallback(after: loadStrategy) != nil {
                    retryWithNextStrategy(in: webView)
                } else {
                    controller.handleBridgeMessage(.error("WebView load failed: \(error.localizedDescription)"))
                }
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor [weak self] in
                guard let self else { return }
                if YouTubePlayerWebLoader.nextFallback(after: loadStrategy) != nil {
                    retryWithNextStrategy(in: webView)
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

            Task { @MainActor [weak self] in
                guard let self, let webView else { return }

                if shouldRetry(for: bridgeMessage) {
                    retryWithNextStrategy(in: webView)
                    return
                }

                controller.handleBridgeMessage(bridgeMessage)
            }
        }
    }
}
#endif
