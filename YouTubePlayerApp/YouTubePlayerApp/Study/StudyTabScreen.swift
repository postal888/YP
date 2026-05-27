import SwiftUI

@MainActor
struct StudyTabScreen: View {
    @EnvironmentObject private var vocabularyStore: VocabularyStore
    @EnvironmentObject private var learningStats: LearningStatsStore

    @State private var studyMode: StudyMode = .flashcards
    @State private var currentIndex = 0
    @State private var isRevealed = false

    private var cards: [VocabularyCard] {
        vocabularyStore.cards
    }

    private var currentCard: VocabularyCard? {
        guard !cards.isEmpty, currentIndex < cards.count else { return nil }
        return cards[currentIndex]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                Picker("Режим", selection: $studyMode) {
                    Text("Карточки").tag(StudyMode.flashcards)
                    Text("Квиз").tag(StudyMode.quiz)
                }
                .pickerStyle(.segmented)

                if studyMode == .quiz {
                    QuizPanelView()
                } else if let card = currentCard {
                    studyCard(card)
                    controls
                } else {
                    emptyState
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
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Study")
                .font(.title2.bold())
                .foregroundStyle(PortTheme.heading)
            Text("Повторение карточек и квиз из словаря")
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
            VStack(alignment: .leading, spacing: 14) {
                Text(isRevealed ? card.translation : card.source)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(PortTheme.heading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)

                Text(isRevealed ? card.source : "Нажмите, чтобы показать перевод")
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
            }
            .padding(20)
            .portCard()
        }
        .buttonStyle(.plain)
    }

    private var controls: some View {
        HStack(spacing: 10) {
            Button("Назад") {
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

            Button(currentIndex >= cards.count - 1 ? "Сначала" : "Далее") {
                step(1)
            }
            .buttonStyle(.borderedProminent)
            .tint(PortTheme.accent)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Нет карточек для повторения", systemImage: "square.stack")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PortTheme.textSubtle)
            Text("Добавьте слова из вкладок Video или Reader.")
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
}

#if DEBUG
struct StudyTabScreen_Previews: PreviewProvider {
    static var previews: some View {
        StudyTabScreen()
            .environmentObject(VocabularyStore())
            .environmentObject(LearningStatsStore())
    }
}
#endif
