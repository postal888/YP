import SwiftUI

@MainActor
struct YouTubeSubtitlesView: View {
    let lines: [YouTubeSubtitleLine]
    let playbackSec: Double?
    let sourceLanguage: String
    let translatedKeys: Set<String>
    let folderKey: String?
    let folderTitle: String?
    let interactionToken: Int
    @Binding var activeWord: ActiveSubtitleWord?
    @Binding var translationPreview: String?
    @Binding var isTranslating: Bool
    let onTimestampTap: ((YouTubeSubtitleLine) -> Void)?
    let onTranslationError: (String) -> Void

    @State private var userScrollUntil: Date = .distantPast

    init(
        lines: [YouTubeSubtitleLine],
        playbackSec: Double?,
        sourceLanguage: String,
        translatedKeys: Set<String>,
        folderKey: String? = nil,
        folderTitle: String? = nil,
        interactionToken: Int = 0,
        activeWord: Binding<ActiveSubtitleWord?>,
        translationPreview: Binding<String?>,
        isTranslating: Binding<Bool>,
        onTimestampTap: ((YouTubeSubtitleLine) -> Void)? = nil,
        onTranslationError: @escaping (String) -> Void
    ) {
        self.lines = lines
        self.playbackSec = playbackSec
        self.sourceLanguage = sourceLanguage
        self.translatedKeys = translatedKeys
        self.folderKey = folderKey
        self.folderTitle = folderTitle
        self.interactionToken = interactionToken
        self._activeWord = activeWord
        self._translationPreview = translationPreview
        self._isTranslating = isTranslating
        self.onTimestampTap = onTimestampTap
        self.onTranslationError = onTranslationError
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(lines) { line in
                        subtitleRow(for: line)
                            .id(line.id)
                    }
                }
                .padding(.vertical, 4)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 8).onChanged { _ in
                    userScrollUntil = Date().addingTimeInterval(4)
                }
            )
            .onChange(of: activeLineID) { newID in
                guard let newID, Date() >= userScrollUntil else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(newID, anchor: .center)
                }
            }
        }
        .padding(8)
        .portCard()
    }

    private var activeLineID: String? {
        guard let playbackSec else { return nil }
        if let current = lines.first(where: { playbackSec >= $0.startSec && playbackSec < $0.endSec }) {
            return current.id
        }
        return lines.last(where: { playbackSec >= $0.endSec })?.id
    }

    @ViewBuilder
    private func subtitleRow(for line: YouTubeSubtitleLine) -> some View {
        let tone = youtubeSubtitleTone(for: line, playbackSec: playbackSec)

        HStack(alignment: .top, spacing: 10) {
            Button {
                onTimestampTap?(line)
            } label: {
                Text(formatSubtitleClock(line.startSec))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(timeColor(for: tone))
                    .frame(width: 42, alignment: .leading)
            }
            .buttonStyle(.plain)

            InteractiveSubtitleText(
                text: line.text,
                lineID: line.id,
                sourceLanguage: sourceLanguage,
                translatedKeys: translatedKeys,
                interactionToken: interactionToken,
                activeWord: $activeWord,
                translationPreview: $translationPreview,
                isTranslating: $isTranslating,
                onTranslationError: onTranslationError
            )
            .foregroundStyle(textColor(for: tone))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(backgroundColor(for: tone))
        .clipShape(RoundedRectangle(cornerRadius: PortTheme.radiusMD, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(formatSubtitleClock(line.startSec)). \(line.text)")
    }

    private func timeColor(for tone: YouTubeSubtitleTone) -> Color {
        switch tone {
        case .future: return PortTheme.textMuted
        case .current: return PortTheme.accent
        case .spoken: return PortTheme.textMuted.opacity(0.85)
        }
    }

    private func textColor(for tone: YouTubeSubtitleTone) -> Color {
        switch tone {
        case .future: return PortTheme.textPrimary.opacity(0.72)
        case .current: return PortTheme.textPrimary
        case .spoken: return PortTheme.textMuted
        }
    }

    private func backgroundColor(for tone: YouTubeSubtitleTone) -> Color {
        switch tone {
        case .future: return PortTheme.surfaceMuted
        case .current: return PortTheme.accentSoft
        case .spoken: return PortTheme.surfaceInput.opacity(0.55)
        }
    }
}

#if DEBUG
struct YouTubeSubtitlesView_Previews: PreviewProvider {
    static var previews: some View {
        YouTubeSubtitlesView(
            lines: [
                YouTubeSubtitleLine(id: "1", text: "Olá, como você está?", startSec: 0, endSec: 3),
                YouTubeSubtitleLine(id: "2", text: "Hoje vamos aprender português.", startSec: 3, endSec: 7)
            ],
            playbackSec: 3.5,
            sourceLanguage: "pt",
            translatedKeys: ["olá"],
            interactionToken: 0,
            activeWord: .constant(nil),
            translationPreview: .constant("Olá — hello"),
            isTranslating: .constant(false),
            onTranslationError: { _ in }
        )
        .padding()
        .background(PortTheme.background)
    }
}
#endif
