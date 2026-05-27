import SwiftUI

struct RecentTranslationsView: View {
    let entries: [WordTranslationEntry]
    let sourceLanguage: String
    let folderKey: String?
    let folderTitle: String?
    let onClear: () -> Void

    @EnvironmentObject private var vocabularyStore: VocabularyStore

    init(
        entries: [WordTranslationEntry],
        sourceLanguage: String = "pt",
        folderKey: String? = nil,
        folderTitle: String? = nil,
        onClear: @escaping () -> Void
    ) {
        self.entries = entries
        self.sourceLanguage = sourceLanguage
        self.folderKey = folderKey
        self.folderTitle = folderTitle
        self.onClear = onClear
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Последние переводы")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PortTheme.textSubtle)
                Spacer()
                if !entries.isEmpty {
                    Button("Очистить", action: onClear)
                        .font(.caption)
                        .foregroundStyle(PortTheme.accent)
                }
            }

            if entries.isEmpty {
                Text("Нажмите на слово в субтитрах")
                    .font(.caption)
                    .foregroundStyle(PortTheme.textMuted)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(entries.prefix(8)) { entry in
                        row(for: entry)
                    }
                }
            }
        }
        .padding(12)
        .portCard()
    }

    private func row(for entry: WordTranslationEntry) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(entry.source)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(PortTheme.heading)
                    Text("—")
                        .foregroundStyle(PortTheme.textMuted)
                    Text(entry.translation)
                        .font(.subheadline)
                        .foregroundStyle(PortTheme.textMuted)
                }
            }

            Spacer(minLength: 8)

            if vocabularyStore.contains(source: entry.source) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(PortTheme.accent)
            } else {
                Button {
                    vocabularyStore.add(
                        source: entry.source,
                        translation: entry.translation,
                        sourceLanguage: sourceLanguage,
                        bookTitle: folderTitle,
                        folderKey: folderKey,
                        folderTitle: folderTitle
                    )
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
}
