import SwiftUI

@MainActor
struct DictionaryView: View {
    @EnvironmentObject private var vocabularyStore: VocabularyStore
    @EnvironmentObject private var appSettings: AppSettings
    @ObservedObject private var ttsService = WordTTSService.shared

    @State private var searchText = ""
    @State private var editingCard: VocabularyCard?

    private var filteredCards: [VocabularyCard] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return vocabularyStore.cards }
        return vocabularyStore.cards.filter {
            $0.source.lowercased().contains(query)
                || $0.translation.lowercased().contains(query)
                || ($0.example?.lowercased().contains(query) ?? false)
                || ($0.bookTitle?.lowercased().contains(query) ?? false)
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                header

                if vocabularyStore.cards.isEmpty {
                    emptyState
                } else {
                    PortSearchBar(
                        text: $searchText,
                        placeholder: "Поиск в словаре…",
                        onSubmit: {}
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)

                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(filteredCards) { card in
                                cardRow(card)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                }
            }
            .background(PortTheme.background.ignoresSafeArea())
            .navigationBarHidden(true)
            .sheet(item: $editingCard) { card in
                VocabularyCardEditSheet(card: card) { source, translation, example in
                    vocabularyStore.update(card, source: source, translation: translation, example: example)
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.stack.fill")
                    .font(.title2)
                    .foregroundStyle(PortTheme.accent)
                Text("Словарь")
                    .font(.title2.bold())
                    .foregroundStyle(PortTheme.heading)
            }

            Text("\(vocabularyStore.cards.count) карточек · нажмите для редактирования")
                .font(.subheadline)
                .foregroundStyle(PortTheme.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    private func cardRow(_ card: VocabularyCard) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                editingCard = card
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(card.source)
                            .font(.headline)
                            .foregroundStyle(PortTheme.heading)
                        Text("—")
                            .foregroundStyle(PortTheme.textMuted)
                        Text(card.translation)
                            .font(.body)
                            .foregroundStyle(PortTheme.textSubtle)
                    }

                    if let example = card.example, !example.isEmpty {
                        Text(example)
                            .font(.caption)
                            .foregroundStyle(PortTheme.textMuted)
                            .lineLimit(2)
                    }

                    HStack(spacing: 8) {
                        Text(card.sourceLanguage.uppercased())
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(PortTheme.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(PortTheme.accentSoft)
                            .clipShape(Capsule())

                        if let bookTitle = card.bookTitle {
                            Text(bookTitle)
                                .font(.caption)
                                .foregroundStyle(PortTheme.textMuted)
                                .lineLimit(1)
                        }

                        Spacer()

                        Text(card.createdAt, style: .date)
                            .font(.caption2)
                            .foregroundStyle(PortTheme.textMuted)
                    }
                }
            }
            .buttonStyle(.plain)

            VStack(spacing: 8) {
                Button {
                    ttsService.speak(
                        text: card.source,
                        languageCode: card.sourceLanguage,
                        cardID: card.id,
                        settings: appSettings
                    )
                } label: {
                    Image(systemName: ttsService.playingCardID == card.id ? "speaker.wave.2.fill" : "speaker.wave.2")
                        .foregroundStyle(PortTheme.accent)
                }
                .buttonStyle(.plain)
                .disabled(ttsService.isPlaying && ttsService.playingCardID != card.id)

                Button(role: .destructive) {
                    vocabularyStore.remove(card)
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(PortTheme.danger)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .portCard()
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "character.book.closed")
                .font(.system(size: 42))
                .foregroundStyle(PortTheme.textMuted)
            Text("Словарь пуст")
                .font(.headline)
                .foregroundStyle(PortTheme.heading)
            Text("Нажимайте на слова в PDF или субтитрах и сохраняйте перевод.")
                .font(.subheadline)
                .foregroundStyle(PortTheme.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }
}

#if DEBUG
struct DictionaryView_Previews: PreviewProvider {
    static var previews: some View {
        DictionaryView()
            .environmentObject(VocabularyStore())
            .environmentObject(AppSettings())
    }
}
#endif
