import SwiftUI

@MainActor
struct DictionaryView: View {
    @EnvironmentObject private var vocabularyStore: VocabularyStore

    @State private var searchText = ""

    private var filteredCards: [VocabularyCard] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return vocabularyStore.cards }
        return vocabularyStore.cards.filter {
            $0.source.lowercased().contains(query)
                || $0.translation.lowercased().contains(query)
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

            Text("\(vocabularyStore.cards.count) карточек")
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

            Button(role: .destructive) {
                vocabularyStore.remove(card)
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(PortTheme.danger)
            }
            .buttonStyle(.plain)
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
    }
}
#endif
