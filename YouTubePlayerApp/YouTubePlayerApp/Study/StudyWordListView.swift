import SwiftUI

@MainActor
struct StudyWordListView: View {
    @EnvironmentObject private var vocabularyStore: VocabularyStore
    @EnvironmentObject private var learningStats: LearningStatsStore
    @EnvironmentObject private var studySelection: StudyWordSelectionStore
    @EnvironmentObject private var appSettings: AppSettings

    @State private var searchText = ""

    private var strings: AppStrings { appSettings.strings }

    private var filteredCards: [VocabularyCard] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return vocabularyStore.cards }
        return vocabularyStore.cards.filter { card in
            card.source.lowercased().contains(query)
                || card.translation.lowercased().contains(query)
                || (card.example?.lowercased().contains(query) ?? false)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            summaryHeader

            PortSearchBar(
                text: $searchText,
                placeholder: strings.searchDictionary,
                onSubmit: {}
            )

            if filteredCards.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(filteredCards) { card in
                        studyWordRow(card)
                    }
                }
            }
        }
    }

    private var summaryHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(strings.studyWordListHint)
                .font(.caption)
                .foregroundStyle(PortTheme.textMuted)
            Text(strings.studyWordsSelected(studySelection.includedCount(in: vocabularyStore.cards), total: vocabularyStore.cards.count))
                .font(.caption.weight(.semibold))
                .foregroundStyle(PortTheme.accent)
        }
        .padding(12)
        .portCard()
    }

    private func studyWordRow(_ card: VocabularyCard) -> some View {
        let stats = learningStats.stats(for: card.id)
        let included = studySelection.isIncludedInQuiz(card.id)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Button {
                    studySelection.setIncludedInQuiz(card.id, included: !included)
                } label: {
                    Image(systemName: included ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(included ? PortTheme.accent : PortTheme.textMuted)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(included ? strings.includedInQuiz : strings.excludedFromQuiz)

                if vocabularyStore.hasImage(for: card.id) {
                    VocabularyCardImageView(
                        cardID: card.id,
                        style: .thumbnail,
                        image: vocabularyStore.image(for: card.id)
                    )
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(card.source)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(PortTheme.heading)
                        Text("—")
                            .foregroundStyle(PortTheme.textMuted)
                        Text(card.translation)
                            .font(.subheadline)
                            .foregroundStyle(PortTheme.textSubtle)
                    }

                    Text(vocabularyStore.folderDisplayName(for: card.resolvedFolderKey))
                        .font(.caption2)
                        .foregroundStyle(PortTheme.textMuted)
                }

                Spacer(minLength: 0)
            }

            CardStatsBar(stats: stats, strings: strings)
        }
        .padding(12)
        .portCard()
        .opacity(included ? 1 : 0.72)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(strings.dictionaryEmpty)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PortTheme.textSubtle)
            Text(strings.dictionaryEmptyHint)
                .font(.caption)
                .foregroundStyle(PortTheme.textMuted)
        }
        .padding(16)
        .portCard()
    }
}

#if DEBUG
struct StudyWordListView_Previews: PreviewProvider {
    static var previews: some View {
        StudyWordListView()
            .environmentObject(VocabularyStore())
            .environmentObject(LearningStatsStore())
            .environmentObject(StudyWordSelectionStore())
            .environmentObject(AppSettings())
            .padding()
            .background(PortTheme.background)
    }
}
#endif
