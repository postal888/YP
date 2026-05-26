import SwiftUI
import YouTubePlayer

struct ContentView: View {
    @State private var inputURL = "https://www.youtube.com/watch?v=ysz5S6PUM-U"
    @State private var resolvedVideoID: String?
    @StateObject private var playerController = YouTubePlayerController()
    @StateObject private var errorLog = AppErrorLog()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("YouTube Player")
                            .font(.title2.bold())

                        Text("Вставьте ссылку на YouTube или video ID. Плеер покажет видео и субтитры с синхронизацией.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        TextField("YouTube URL или video ID", text: $inputURL)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)

                        Button("Загрузить видео") {
                            loadVideo()
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)

                        if let videoID = resolvedVideoID {
                            LessonPlayerView(
                                videoID: videoID,
                                controller: playerController,
                                errorLog: errorLog
                            )
                        } else if !inputURL.isEmpty {
                            Text("Не удалось распознать video ID")
                                .foregroundStyle(.red)
                        }
                    }
                    .padding()
                }

                ErrorLogPanelView(log: errorLog)
            }
            .navigationTitle("YouTube Player")
        }
    }

    private func loadVideo() {
        let trimmed = inputURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorLog.add(source: "Video", message: "Пустой ввод URL или video ID.")
            resolvedVideoID = nil
            return
        }

        if let videoID = YouTubeVideoIDExtractor.extract(from: trimmed) {
            resolvedVideoID = videoID
            playerController.load(videoID: videoID, startTime: 0)
        } else {
            resolvedVideoID = nil
            errorLog.add(
                source: "Video",
                message: "Не удалось распознать video ID из: \(trimmed)"
            )
        }
    }
}

#Preview {
    ContentView()
}
