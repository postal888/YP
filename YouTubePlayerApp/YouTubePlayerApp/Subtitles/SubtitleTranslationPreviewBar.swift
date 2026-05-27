import SwiftUI

@MainActor
struct SubtitleTranslationPreviewBar: View {
    @Binding var translationPreview: String?
    @Binding var isTranslating: Bool
    @Binding var activeWord: ActiveSubtitleWord?
    let sourceLanguage: String
    let folderKey: String?
    let folderTitle: String?
    let onWordAdded: (WordTranslationEntry) -> Void

    @EnvironmentObject private var vocabularyStore: VocabularyStore
    @EnvironmentObject private var appSettings: AppSettings

    @State private var savedPreviewWordKey: String?

    private var strings: AppStrings { appSettings.strings }

    var body: some View {
        Group {
            if let translationPreview {
                previewContent(translationPreview)
            }
        }
        .onChange(of: activeWord) { _ in
            savedPreviewWordKey = nil
        }
    }

    @ViewBuilder
    private func previewContent(_ text: String) -> some View {
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
                    .accessibilityLabel(strings.addToDictionary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(PortTheme.accentSoft)
        .clipShape(RoundedRectangle(cornerRadius: PortTheme.radiusMD, style: .continuous))
    }

    private func translationEntry(from preview: String) -> WordTranslationEntry? {
        guard !isTranslating else { return nil }
        guard let range = preview.rangeOfTranslationSeparator else { return nil }
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
            bookTitle: folderTitle,
            folderKey: folderKey,
            folderTitle: folderTitle
        )
        savedPreviewWordKey = entry.source
        onWordAdded(entry)
    }
}
