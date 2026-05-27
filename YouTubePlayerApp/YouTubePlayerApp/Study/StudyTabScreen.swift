import SwiftUI

@MainActor
struct StudyTabScreen: View {
    @EnvironmentObject private var vocabularyStore: VocabularyStore
    @EnvironmentObject private var learningStats: LearningStatsStore
    @EnvironmentObject private var studySelection: StudyWordSelectionStore
    @EnvironmentObject private var appSettings: AppSettings

    @State private var studyMode: StudyMode = .flashcards
    @State private var currentIndex = 0
    @State private var isRevealed = false

    private var strings: AppStrings { appSettings.strings }

    private var cards: [VocabularyCard] {
        studySelection.filterCards(vocabularyStore.cards)
    }

    private var currentCard: VocabularyCard? {
        guard !cards.isEmpty, currentIndex < cards.count else { return nil }
        return cards[currentIndex]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                Picker(strings.studyMode, selection: $studyMode) {
                    Text(strings.flashcards).tag(StudyMode.flashcards)
                    Text(strings.quiz).tag(StudyMode.quiz)
                    Text(strings.wordsTab).tag(StudyMode.words)
                }
                .pickerStyle(.segmented)

                switch studyMode {
                case .quiz:
                    QuizPanelView()
                case .words:
                    StudyWordListView()
                case .flashcards:
                    if let card = currentCard {
                        studyCard(card)
                        controls
                    } else {
                        emptyState
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(PortTheme.background.ignoresSafeArea())
        .onAppear {
            learningStats.beginStudySession()
        }
        .onDisappear {
            if studyMode == .flashcards, currentIndex > 0 {
                learningStats.recordReviewSession(cardsReviewed: currentIndex + 1)
            }
            learningStats.endStudySession()
        }
        .onChange(of: studySelection.disabledCardIDs) { _ in
            currentIndex = min(currentIndex, max(cards.count - 1, 0))
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(strings.tabStudy)
                .font(.title2.bold())
                .foregroundStyle(PortTheme.heading)
            Text(strings.studySubtitle)
                .font(.subheadline)
                .foregroundStyle(PortTheme.textMuted)
        }
    }

    private func studyCard(_ card: VocabularyCard) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isRevealed.toggle()
            }
        } label: {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 14) {
                    Text(isRevealed ? card.translation : card.source)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(PortTheme.heading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)

                    Text(isRevealed ? card.source : strings.tapToRevealTranslation)
                        .font(.subheadline)
                        .foregroundStyle(PortTheme.textMuted)

                    if let example = card.example, !example.isEmpty {
                        Text(example)
                            .font(.caption)
                            .foregroundStyle(PortTheme.textSubtle)
                    }

                    if let bookTitle = card.bookTitle {
                        Text(bookTitle)
                            .font(.caption)
                            .foregroundStyle(PortTheme.accent)
                    }

                    CardStatsBar(stats: learningStats.stats(for: card.id), strings: strings)
                }

                if vocabularyStore.hasImage(for: card.id) {
                    VocabularyCardImageView(
                        cardID: card.id,
                        style: .card,
                        image: vocabularyStore.image(for: card.id)
                    )
                }
            }
            .padding(20)
            .frame(minHeight: 192)
            .portCard()
        }
        .buttonStyle(.plain)
    }

    private var controls: some View {
        HStack(spacing: 10) {
            Button(strings.back) {
                step(-1)
            }
            .buttonStyle(.bordered)
            .tint(PortTheme.accent)
            .disabled(currentIndex == 0)

            Spacer()

            Text("\(currentIndex + 1) / \(cards.count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(PortTheme.textMuted)

            Spacer()

            Button(currentIndex >= cards.count - 1 ? strings.fromStart : strings.next) {
                step(1)
            }
            .buttonStyle(.borderedProminent)
            .tint(PortTheme.accent)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(strings.noCardsToReview, systemImage: "square.stack")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PortTheme.textSubtle)
            Text(strings.studyEmptyHint)
                .font(.subheadline)
                .foregroundStyle(PortTheme.textMuted)
        }
        .padding(16)
        .portCard()
    }

    private func step(_ delta: Int) {
        guard !cards.isEmpty else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            if delta > 0, currentIndex >= cards.count - 1 {
                currentIndex = 0
                learningStats.recordReviewSession(cardsReviewed: cards.count)
            } else {
                currentIndex = min(max(currentIndex + delta, 0), cards.count - 1)
            }
            isRevealed = false
        }
    }
}

private enum StudyMode {
    case flashcards
    case quiz
    case words
}

#if DEBUG
struct StudyTabScreen_Previews: PreviewProvider {
    static var previews: some View {
        StudyTabScreen()
            .environmentObject(VocabularyStore())
            .environmentObject(LearningStatsStore())
            .environmentObject(StudyWordSelectionStore())
            .environmentObject(AppSettings())
    }
}
#endif
