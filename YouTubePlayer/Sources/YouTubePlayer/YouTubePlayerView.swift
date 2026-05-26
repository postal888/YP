import SwiftUI

/// Встраиваемый YouTube-плеер для образовательных экранов.
@MainActor
public struct YouTubePlayerView: View {
    private let configuration: YouTubePlayerConfiguration
    @ObservedObject private var controller: YouTubePlayerController

    public init(
        videoID: String,
        controller: YouTubePlayerController,
        autoplay: Bool = false,
        startTime: Double = 0,
        showControls: Bool = true,
        allowFullscreen: Bool = true,
        playsInline: Bool = true,
        progressPollingInterval: TimeInterval = 1.0,
        captionLanguage: String = "pt"
    ) {
        self.configuration = YouTubePlayerConfiguration(
            videoID: videoID,
            autoplay: autoplay,
            startTime: startTime,
            showControls: showControls,
            allowFullscreen: allowFullscreen,
            playsInline: playsInline,
            progressPollingInterval: progressPollingInterval,
            captionLanguage: captionLanguage
        )
        self._controller = ObservedObject(wrappedValue: controller)
    }

    public init(
        configuration: YouTubePlayerConfiguration,
        controller: YouTubePlayerController
    ) {
        self.configuration = configuration
        self._controller = ObservedObject(wrappedValue: controller)
    }

    public var body: some View {
        ZStack {
            Color.black

            YouTubePlayerWebView(
                configuration: configuration,
                controller: controller
            )

            if case .loading = controller.state {
                ProgressView()
                    .tint(.white)
            }

            if case .error(let message) = controller.state {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title2)
                        .foregroundStyle(.yellow)
                    Text(message)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .padding(.horizontal)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview {
    YouTubePlayerView(
        videoID: "dQw4w9WgXcQ",
        controller: YouTubePlayerController()
    )
    .frame(height: 220)
    .padding()
}
