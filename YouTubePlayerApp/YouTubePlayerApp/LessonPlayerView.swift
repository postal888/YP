import SwiftUI
import YouTubePlayer

@MainActor
struct LessonPlayerView: View {
    let videoID: String
    @ObservedObject var controller: YouTubePlayerController
    @ObservedObject var errorLog: AppErrorLog

    @State private var watchedSeconds: Double = 0
    @State private var lessonCompleted = false
    @State private var subtitleLines: [YouTubeSubtitleLine] = []
    @State private var selectedLanguage: YouTubeSubtitleLanguage = .portuguese
    @State private var isLoadingSubtitles = false
    @State private var subtitleError: String?
    @State private var loadedTranscriptKey: String?
    @State private var lastLoggedPlayerError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Тестовый урок")
                .font(.headline)

            YouTubePlayerView(
                videoID: videoID,
                controller: controller,
                showControls: true,
                progressPollingInterval: 0.25
            )
            .frame(height: 220)
            .onAppear {
                controller.onEvent = handlePlayerEvent
            }

            HStack {
                Button("Play") { controller.play() }
                Button("Pause") { controller.pause() }
                Button("−10s") {
                    controller.seek(to: max(0, controller.currentTime - 10))
                }
                Button("+10s") {
                    controller.seek(to: controller.currentTime + 10)
                }
            }
            .buttonStyle(.bordered)

            languagePicker
            subtitlesSection
            progressSection
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .task(id: transcriptKey) {
            await loadSubtitlesIfNeeded()
        }
        .onChange(of: controller.state) { newState in
            logPlayerStateIfNeeded(newState)
        }
    }

    private var transcriptKey: String {
        "\(videoID):\(selectedLanguage.rawValue)"
    }

    private var languagePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Субтитры")
                .font(.subheadline.weight(.semibold))

            Picker("Язык субтитров", selection: $selectedLanguage) {
                ForEach(YouTubeSubtitleLanguage.allCases) { language in
                    Text(language.label).tag(language)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    @ViewBuilder
    private var subtitlesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isLoadingSubtitles {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Загрузка субтитров...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            } else if let subtitleError {
                Text(subtitleError)
                    .font(.subheadline)
                    .foregroundStyle(.red)
            } else if !subtitleLines.isEmpty {
                Text("\(subtitleLines.count) строк · с устройства")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                YouTubeSubtitlesView(
                    lines: subtitleLines,
                    playbackSec: controller.currentTime,
                    onLineTap: { line in
                        controller.seek(to: line.startSec)
                        controller.play()
                    }
                )
                .frame(minHeight: 220, maxHeight: 360)
            } else {
                Text("Субтитры не загружены.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Статус: \(statusText)")
            Text("Просмотрено: \(Int(watchedSeconds)) сек")

            if controller.duration > 0 {
                ProgressView(value: watchedSeconds, total: controller.duration)
            }

            if lessonCompleted {
                Label("Видео просмотрено до конца", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .font(.subheadline)
    }

    private var statusText: String {
        switch controller.state {
        case .idle: return "Ожидание"
        case .loading: return "Загрузка"
        case .ready: return "Готов"
        case .playing: return "Воспроизведение"
        case .paused: return "Пауза"
        case .buffering: return "Буферизация"
        case .ended: return "Завершено"
        case .error: return "Ошибка"
        }
    }

    @MainActor
    private func loadSubtitlesIfNeeded() async {
        guard loadedTranscriptKey != transcriptKey else { return }

        isLoadingSubtitles = true
        subtitleError = nil
        subtitleLines = []

        do {
            let lines = try await YouTubeTranscriptFetcher.shared.fetchSubtitleLines(
                videoID: videoID,
                preferredLanguage: selectedLanguage.rawValue
            )
            subtitleLines = lines
            loadedTranscriptKey = transcriptKey
        } catch {
            let message = error.localizedDescription
            subtitleError = message
            loadedTranscriptKey = nil
            errorLog.add(
                source: "Subtitles",
                message: "videoID=\(videoID), lang=\(selectedLanguage.rawValue): \(message)"
            )
        }

        isLoadingSubtitles = false
    }

    private func handlePlayerEvent(_ event: YouTubePlayerEvent) {
        switch event {
        case .progress(let currentTime, _):
            watchedSeconds = max(watchedSeconds, currentTime)

        case .ended:
            lessonCompleted = true

        case .error(let message):
            logPlayerError(message)

        default:
            break
        }
    }

    private func logPlayerStateIfNeeded(_ state: YouTubePlayerState) {
        if case .error(let message) = state {
            logPlayerError(message)
        }
    }

    private func logPlayerError(_ message: String) {
        guard lastLoggedPlayerError != message else { return }
        lastLoggedPlayerError = message
        errorLog.add(source: "Player", message: "videoID=\(videoID): \(message)")
    }
}

#Preview {
    LessonPlayerView(
        videoID: "ysz5S6PUM-U",
        controller: YouTubePlayerController(),
        errorLog: AppErrorLog()
    )
    .padding()
}
