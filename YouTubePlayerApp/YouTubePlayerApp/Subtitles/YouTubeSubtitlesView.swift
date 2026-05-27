import SwiftUI

@MainActor
struct YouTubeSubtitlesView: View {
    let lines: [YouTubeSubtitleLine]
    let playbackSec: Double?
    let sourceLanguage: String
    let translatedKeys: Set<String>
    @Binding var translationPreview: String?
    @Binding var isTranslating: Bool
    let onTimestampTap: ((YouTubeSubtitleLine) -> Void)?
    let onWordTranslated: (WordTranslationEntry) -> Void
    let onTranslationError: (String) -> Void

    @EnvironmentObject private var vocabularyStore: VocabularyStore

    @State private var userScrollUntil: Date = .distantPast
    @State private var activeWord: ActiveSubtitleWord?
    @State private var savedPreviewWordKey: String?

    init(
        lines: [YouTubeSubtitleLine],
        playbackSec: Double?,
        sourceLanguage: String,
        translatedKeys: Set<String>,
        translationPreview: Binding<String?>,
        isTranslating: Binding<Bool>,
        onTimestampTap: ((YouTubeSubtitleLine) -> Void)? = nil,
        onWordTranslated: @escaping (WordTranslationEntry) -> Void,
        onTranslationError: @escaping (String) -> Void
    ) {
        self.lines = lines
        self.playbackSec = playbackSec
        self.sourceLanguage = sourceLanguage
        self.translatedKeys = translatedKeys
        self._translationPreview = translationPreview
        self._isTranslating = isTranslating
        self.onTimestampTap = onTimestampTap
        self.onWordTranslated = onWordTranslated
        self.onTranslationError = onTranslationError
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if let translationPreview {
                        translationPreviewBar(translationPreview)
                    }

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
    private func translationPreviewBar(_ text: String) -> some View {
        HStack(spacing: 8) {
            if isTranslating {
                ProgressView()
                    .controlSize(.small)
                    .tint(PortTheme.accent)
            }
            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(PortTheme.heading)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let entry = translationEntry(from: text) {
                if vocabularyStore.contains(source: entry.source) || savedPreviewWordKey == entry.source {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(PortTheme.accent)
                } else {
                    Button {
                        addToVocabulary(entry)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.body)
                            .foregroundStyle(PortTheme.accent)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Добавить в словарь")
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(PortTheme.accentSoft)
        .clipShape(RoundedRectangle(cornerRadius: PortTheme.radiusMD, style: .continuous))
        .onChange(of: activeWord) { _ in
            savedPreviewWordKey = nil
        }
    }

    private func translationEntry(from preview: String) -> WordTranslationEntry? {
        guard !isTranslating else { return nil }
        guard let range = preview.range(of: " — ") else { return nil }
        let translation = String(preview[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !translation.isEmpty, translation != "…" else { return nil }

        let source = activeWord?.lookupKey
            ?? String(preview[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty else { return nil }

        return WordTranslationEntry(source: source, translation: translation)
    }

    private func addToVocabulary(_ entry: WordTranslationEntry) {
        vocabularyStore.add(
            source: entry.source,
            translation: entry.translation,
            sourceLanguage: sourceLanguage,
            bookTitle: "YouTube"
        )
        savedPreviewWordKey = entry.source
        onWordTranslated(entry)
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
                activeWord: $activeWord,
                translationPreview: $translationPreview,
                isTranslating: $isTranslating,
                onWordTranslated: onWordTranslated,
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
            translationPreview: .constant("Olá — привет"),
            isTranslating: .constant(false),
            onWordTranslated: { _ in },
            onTranslationError: { _ in }
        )
        .padding()
        .background(PortTheme.background)
    }
}
#endif
