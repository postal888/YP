import SwiftUI
import Combine
import YouTubePlayerKit

@MainActor
struct LessonPlayerView: View {
    let videoID: String
    @ObservedObject var session: YouTubeSessionStore
    @ObservedObject var errorLog: AppErrorLog
    var onClose: (() -> Void)? = nil

    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var vocabularyStore: VocabularyStore
    @EnvironmentObject private var appSettings: AppSettings

    private var strings: AppStrings { appSettings.strings }
    private var playerHolder: YouTubePlayerHolder { session.playerHolder }
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
    @State private var translationPreview: String?
    @State private var isTranslatingWord = false
    @State private var subtitleRefreshID = 0
    @State private var recentTranslations: [WordTranslationEntry] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                playerSection
                transportControls
                languagePicker
                subtitlesSection
                if lessonCompleted {
                    completionBadge
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(PortTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .onChange(of: session.selectedVideoTitle) { title in
            guard let title, !title.isEmpty else { return }
            vocabularyStore.ensureFolderTitle(
                key: VocabularyFolderKey.youtube(videoID),
                defaultTitle: title
            )
        }
        .onChange(of: session.videoTabActivationToken) { _ in
            subtitleRefreshID += 1
            translationPreview = nil
            isTranslatingWord = false
        }
        .task(id: transcriptKey) {
            await loadSubtitlesIfNeeded()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                closePlayer()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(PortTheme.textSubtle)
                    .frame(width: 36, height: 36)
                    .background(PortTheme.surfaceInput)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(strings.lessonTitle)
                    .font(.headline)
                    .foregroundStyle(PortTheme.heading)
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(PortTheme.textMuted)
            }

            Spacer()

            if duration > 0 {
                Text(progressLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(PortTheme.textMuted)
            }
        }
        .padding(.top, 8)
    }

    private var progressLabel: String {
        "\(formatClock(currentTime)) / \(formatClock(duration))"
    }

    private func formatClock(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        let minutes = total / 60
        let remainder = total % 60
        return String(format: "%d:%02d", minutes, remainder)
    }

    private var playerSection: some View {
        YouTubePlayerView(playerHolder.player) { state in
            switch state {
            case .idle:
                ZStack {
                    PortTheme.surfaceMuted
                    ProgressView()
                        .tint(PortTheme.accent)
                }
            case .ready:
                EmptyView()
            case .error(let error):
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(PortTheme.danger)
                    Text(strings.playerErrorTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PortTheme.heading)
                    Text(String(describing: error))
                        .font(.caption)
                        .foregroundStyle(PortTheme.textMuted)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
        }
        .id("\(videoID)-\(selectedLanguage.rawValue)")
        .frame(maxWidth: .infinity)
        .aspectRatio(16 / 9, contentMode: .fit)
        .background(PortTheme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: PortTheme.radiusLG, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PortTheme.radiusLG, style: .continuous)
                .stroke(PortTheme.cardBorder, lineWidth: 1)
        )
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
            playerHolder.load(videoID: newID, captionLanguage: selectedLanguage.rawValue, force: true)
            resetWatchState()
        }
        .onChange(of: selectedLanguage) { newLang in
            playerHolder.load(videoID: videoID, captionLanguage: newLang.rawValue, force: true)
        }
    }

    private var transportControls: some View {
        HStack(spacing: 10) {
            controlButton(icon: "gobackward.10", label: "−10") {
                playerHolder.seek(to: max(0, currentTime - 10))
            }
            controlButton(icon: playerHolder.isPlaying ? "pause.fill" : "play.fill", label: playerHolder.isPlaying ? strings.pause : strings.play) {
                if playerHolder.isPlaying {
                    playerHolder.pause()
                } else {
                    playerHolder.play()
                }
            }
            controlButton(icon: "goforward.10", label: "+10") {
                playerHolder.seek(to: currentTime + 10)
            }
        }
    }

    private func controlButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.body.weight(.semibold))
                Text(label)
                    .font(.caption2)
            }
            .foregroundStyle(PortTheme.textSubtle)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(PortTheme.surfaceInput)
            .clipShape(RoundedRectangle(cornerRadius: PortTheme.radiusMD, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var transcriptKey: String { "\(videoID):\(selectedLanguage.rawValue)" }

    private var languagePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(strings.subtitleLanguage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PortTheme.textSubtle)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(YouTubeSubtitleLanguage.allCases) { language in
                        Button(language.label) {
                            selectedLanguage = language
                        }
                        .buttonStyle(PortChipButtonStyle(isSelected: selectedLanguage == language))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var subtitlesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(strings.subtitles)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PortTheme.textSubtle)
                Spacer()
                if !subtitleLines.isEmpty {
                    Text("\(subtitleLines.count) \(strings.lines)")
                        .font(.caption)
                        .foregroundStyle(PortTheme.textMuted)
                }
            }

            if isLoadingSubtitles {
                HStack(spacing: 10) {
                    ProgressView().tint(PortTheme.accent)
                    Text(strings.loadingSubtitles)
                        .font(.subheadline)
                        .foregroundStyle(PortTheme.textMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .portCard()
            } else if let subtitleError {
                Text(subtitleError)
                    .font(.subheadline)
                    .foregroundStyle(PortTheme.danger)
                    .padding(14)
                    .portCard()
            } else if !subtitleLines.isEmpty {
                YouTubeSubtitlesView(
                    lines: subtitleLines,
                    playbackSec: currentTime,
                    sourceLanguage: selectedLanguage.rawValue,
                    translatedKeys: vocabularyStore.lookupKeys,
                    folderKey: VocabularyFolderKey.youtube(videoID),
                    folderTitle: session.selectedVideoTitle,
                    interactionToken: subtitleRefreshID,
                    translationPreview: $translationPreview,
                    isTranslating: $isTranslatingWord,
                    onTimestampTap: { line in
                        playerHolder.seek(to: line.startSec)
                        playerHolder.play()
                    },
                    onWordTranslated: { entry in
                        rememberTranslation(entry)
                    },
                    onTranslationError: { message in
                        errorLog.add(source: "Translate", message: message)
                    }
                )
                .id(subtitleRefreshID)
                .frame(minHeight: 240, maxHeight: 380)

                RecentTranslationsView(
                    entries: recentTranslations,
                    sourceLanguage: selectedLanguage.rawValue,
                    folderKey: VocabularyFolderKey.youtube(videoID),
                    folderTitle: session.selectedVideoTitle
                ) {
                    recentTranslations = []
                }
            } else {
                Text(strings.subtitlesNotLoaded)
                    .font(.subheadline)
                    .foregroundStyle(PortTheme.textMuted)
                    .padding(14)
                    .portCard()
            }
        }
    }

    private var completionBadge: some View {
        Label(strings.videoCompleted, systemImage: "checkmark.circle.fill")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(PortTheme.successText)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PortTheme.accentSoft)
            .clipShape(RoundedRectangle(cornerRadius: PortTheme.radiusMD, style: .continuous))
    }

    private func closePlayer() {
        if let onClose {
            onClose()
        } else {
            presentationMode.wrappedValue.dismiss()
        }
    }

    private func resetWatchState() {
        watchedSeconds = 0
        lessonCompleted = false
        currentTime = 0
        duration = 0
        translationPreview = nil
        recentTranslations = []
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

    private func rememberTranslation(_ entry: WordTranslationEntry) {
        recentTranslations.removeAll { $0.id == entry.id }
        recentTranslations.insert(entry, at: 0)
        if recentTranslations.count > 20 {
            recentTranslations = Array(recentTranslations.prefix(20))
        }
    }
}

#Preview {
    LessonPlayerView(
        videoID: "ysz5S6PUM-U",
        session: YouTubeSessionStore(),
        errorLog: AppErrorLog()
    )
    .environmentObject(VocabularyStore())
    .environmentObject(AppSettings())
}
