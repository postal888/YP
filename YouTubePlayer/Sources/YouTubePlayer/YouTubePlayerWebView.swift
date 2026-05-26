#if canImport(UIKit)
import SwiftUI
import WebKit

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

        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "youtube")
        webConfiguration.userContentController = userContentController

        let webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        webView.navigationDelegate = context.coordinator

        context.coordinator.webView = webView
        context.coordinator.loadPlayer(configuration: configuration, in: webView)

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if context.coordinator.configuration.videoID != configuration.videoID {
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

            guard let templateURL = Bundle.module.url(forResource: "youtube_player", withExtension: "html"),
                  var html = try? String(contentsOf: templateURL, encoding: .utf8) else {
                controller.handleBridgeMessage(.error("Failed to load player template"))
                return
            }

            let intervalMs = Int(configuration.progressPollingInterval * 1000)
            html = html.replacingOccurrences(of: "{{PROGRESS_INTERVAL_MS}}", with: String(intervalMs))

            webView.loadHTMLString(html, baseURL: URL(string: "https://localhost")!)
        }

        func execute(_ command: YouTubePlayerCommand) {
            switch command {
            case .play:
                evaluate("window.youtubeBridge.play();")

            case .pause:
                evaluate("window.youtubeBridge.pause();")

            case .seek(let seconds):
                evaluate("window.youtubeBridge.seekTo(\(seconds));")

            case .load(let videoID, let startTime):
                let escapedID = videoID.replacingOccurrences(of: "'", with: "\\'")
                evaluate("window.youtubeBridge.loadVideo('\(escapedID)', \(startTime));")
            }
        }

        private func evaluate(_ script: String) {
            webView?.evaluateJavaScript(script, completionHandler: nil)
        }

        private func createPlayerScript() -> String {
            let configJSON = """
            {
              "videoId": "\(configuration.videoID)",
              "autoplay": \(configuration.autoplay),
              "startTime": \(configuration.startTime),
              "showControls": \(configuration.showControls),
              "allowFullscreen": \(configuration.allowFullscreen),
              "playsInline": \(configuration.playsInline)
            }
            """
            return "window.youtubeBridge.createPlayer(\(configJSON));"
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.evaluate(self.createPlayerScript())
            }
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "youtube",
                  let bridgeMessage = BridgeMessage(body: message.body) else {
                return
            }

            Task { @MainActor in
                controller.handleBridgeMessage(bridgeMessage)
            }
        }
    }
}
#endif

#if canImport(AppKit)
import SwiftUI
import WebKit

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
        if context.coordinator.configuration.videoID != configuration.videoID {
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

            guard let templateURL = Bundle.module.url(forResource: "youtube_player", withExtension: "html"),
                  var html = try? String(contentsOf: templateURL, encoding: .utf8) else {
                controller.handleBridgeMessage(.error("Failed to load player template"))
                return
            }

            let intervalMs = Int(configuration.progressPollingInterval * 1000)
            html = html.replacingOccurrences(of: "{{PROGRESS_INTERVAL_MS}}", with: String(intervalMs))

            webView.loadHTMLString(html, baseURL: URL(string: "https://localhost")!)
        }

        func execute(_ command: YouTubePlayerCommand) {
            switch command {
            case .play:
                evaluate("window.youtubeBridge.play();")

            case .pause:
                evaluate("window.youtubeBridge.pause();")

            case .seek(let seconds):
                evaluate("window.youtubeBridge.seekTo(\(seconds));")

            case .load(let videoID, let startTime):
                let escapedID = videoID.replacingOccurrences(of: "'", with: "\\'")
                evaluate("window.youtubeBridge.loadVideo('\(escapedID)', \(startTime));")
            }
        }

        private func evaluate(_ script: String) {
            webView?.evaluateJavaScript(script, completionHandler: nil)
        }

        private func createPlayerScript() -> String {
            let configJSON = """
            {
              "videoId": "\(configuration.videoID)",
              "autoplay": \(configuration.autoplay),
              "startTime": \(configuration.startTime),
              "showControls": \(configuration.showControls),
              "allowFullscreen": \(configuration.allowFullscreen),
              "playsInline": \(configuration.playsInline)
            }
            """
            return "window.youtubeBridge.createPlayer(\(configJSON));"
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.evaluate(self.createPlayerScript())
            }
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "youtube",
                  let bridgeMessage = BridgeMessage(body: message.body) else {
                return
            }

            Task { @MainActor in
                controller.handleBridgeMessage(bridgeMessage)
            }
        }
    }
}
#endif
