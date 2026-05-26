import SwiftUI
import Combine
import YouTubePlayerKit

@MainActor
struct LessonPlayerView: View {
    let videoID: String
    @ObservedObject var errorLog: AppErrorLog

    @StateObject private var playerHolder = YouTubePlayerHolder()
    @State private var watchedSeconds: Double = 0
    @State private var lessonCompleted = false
    @State private var subtitleLines: [YouTubeSubtitleLine] = []
    @State private var selectedLanguage: YouTubeSubtitleLanguage = .portuguese
    @State private var isLoadingSubtitles = false
    @State private var subtitleError: String?
    @State private var loadedTranscriptKey: String?
    @State private var lastLoggedPlayerError: String?
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var statusText: String = "Ожидание"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Тестовый урок")
                .font(.headline)

            YouTubePlayerView(playerHolder.player) { state in
                switch state {
                case .idle:
                    ProgressView()
                case .ready:
                    EmptyView()
                case .error(let error):
                    Text("Ошибка плеера: \(String(describing: error))")
                        .foregroundColor(.red)
                        .padding()
                }
            }
            .id("\(videoID)-\(selectedLanguage.rawValue)")
            .frame(height: 220)
            .onAppear {
                playerHolder.configure(
                    videoID: videoID,
                    captionLanguage: selectedLanguage.rawValue,
                    onProgress: { time, dur in
                        currentTime = time
                        duration = dur
                        watchedSeconds = max(watchedSeconds, time)
                    },
                    onState: { text in statusText = text },
                    onEnded: { lessonCompleted = true },
                    onError: { msg in logPlayerError(msg) },
                    onDebug: { msg in errorLog.add(source: "Player", message: msg) }
                )
            }
            .onChange(of: videoID) { newID in
                playerHolder.load(videoID: newID, captionLanguage: selectedLanguage.rawValue)
                resetWatchState()
            }
            .onChange(of: selectedLanguage) { newLang in
                playerHolder.load(videoID: videoID, captionLanguage: newLang.rawValue)
            }

            HStack {
                Button("Play") { playerHolder.play() }
                Button("Pause") { playerHolder.pause() }
                Button("−10s") { playerHolder.seek(to: max(0, currentTime - 10)) }
                Button("+10s") { playerHolder.seek(to: currentTime + 10) }
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
    }

    private var transcriptKey: String { "\(videoID):\(selectedLanguage.rawValue)" }

    private var languagePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Субтитры").font(.subheadline.weight(.semibold))
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
                    Text("Загрузка субтитров...").font(.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            } else if let subtitleError {
                Text(subtitleError).font(.subheadline).foregroundStyle(.red)
            } else if !subtitleLines.isEmpty {
                Text("\(subtitleLines.count) строк · с устройства")
                    .font(.caption).foregroundStyle(.secondary)

                YouTubeSubtitlesView(
                    lines: subtitleLines,
                    playbackSec: currentTime,
                    onLineTap: { line in
                        playerHolder.seek(to: line.startSec)
                        playerHolder.play()
                    }
                )
                .frame(minHeight: 220, maxHeight: 360)
            } else {
                Text("Субтитры не загружены.").font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Статус: \(statusText)")
            Text("Просмотрено: \(Int(watchedSeconds)) сек")

            if duration > 0 {
                ProgressView(value: min(watchedSeconds, duration), total: duration)
            }

            if lessonCompleted {
                Label("Видео просмотрено до конца", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .font(.subheadline)
    }

    private func resetWatchState() {
        watchedSeconds = 0
        lessonCompleted = false
        currentTime = 0
        duration = 0
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

    private func logPlayerError(_ message: String) {
        guard lastLoggedPlayerError != message else { return }
        lastLoggedPlayerError = message
        errorLog.add(source: "Player", message: "videoID=\(videoID): \(message)")
    }
}

#Preview {
    LessonPlayerView(
        videoID: "ysz5S6PUM-U",
        errorLog: AppErrorLog()
    )
    .padding()
}
