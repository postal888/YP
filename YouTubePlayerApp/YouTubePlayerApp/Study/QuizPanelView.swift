import SwiftUI

@MainActor
struct QuizPanelView: View {
    @EnvironmentObject private var vocabularyStore: VocabularyStore
    @EnvironmentObject private var learningStats: LearningStatsStore
    @EnvironmentObject private var studySelection: StudyWordSelectionStore
    @EnvironmentObject private var appSettings: AppSettings

    @State private var mode: QuizMode = .multipleChoice
    @State private var direction: QuizDirection = .ptToRu
    @State private var order: [UUID] = []
    @State private var currentIndex = 0
    @State private var score = 0
    @State private var answered = false
    @State private var typedAnswer = ""
    @State private var feedback = ""
    @State private var options: [VocabularyCard] = []
    @State private var sessionComplete = false

    private var strings: AppStrings { appSettings.strings }

    private var quizCards: [VocabularyCard] {
        studySelection.filterCards(vocabularyStore.cards)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            controls

            if quizCards.isEmpty {
                emptyState
            } else if sessionComplete {
                completeState
            } else if mode == .multipleChoice, quizCards.count < 4 {
                needMoreWordsState
            } else {
                questionBlock
            }
        }
        .onAppear {
            learningStats.beginStudySession()
            startSessionIfNeeded()
        }
        .onDisappear {
            learningStats.endStudySession()
        }
        .onChange(of: studySelection.disabledCardIDs) { _ in
            restartSession()
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker(strings.quizMode, selection: $mode) {
                Text(strings.multipleChoice).tag(QuizMode.multipleChoice)
                Text(strings.typedInput).tag(QuizMode.typedInput)
            }
            .pickerStyle(.segmented)
            .onChange(of: mode) { _ in restartSession() }

            Picker(strings.quizDirection, selection: $direction) {
                Text("PT → RU").tag(QuizDirection.ptToRu)
                Text("RU → PT").tag(QuizDirection.ruToPt)
            }
            .pickerStyle(.segmented)
            .onChange(of: direction) { _ in restartSession() }

            Text(strings.quizUsesSelectedWords(quizCards.count))
                .font(.caption)
                .foregroundStyle(PortTheme.textMuted)
        }
    }

    @ViewBuilder
    private var questionBlock: some View {
        if let card = currentCard {
            VStack(alignment: .leading, spacing: 14) {
                Text(strings.quizProgress(currentIndex + 1, total: order.count, score: score))
                    .font(.caption)
                    .foregroundStyle(PortTheme.textMuted)

                HStack(alignment: .top, spacing: 12) {
                    Text(prompt(for: card))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(PortTheme.heading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if vocabularyStore.hasImage(for: card.id) {
                        VocabularyCardImageView(
                            cardID: card.id,
                            style: .thumbnail,
                            image: vocabularyStore.image(for: card.id)
                        )
                    }
                }
                .padding(20)
                .portCard()

                if mode == .multipleChoice {
                    VStack(spacing: 8) {
                        ForEach(options) { option in
                            Button {
                                pickOption(option, correct: card)
                            } label: {
                                Text(optionLabel(for: option))
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(PortTheme.heading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(14)
                                    .background(optionBackground(for: option, correct: card))
                                    .clipShape(RoundedRectangle(cornerRadius: PortTheme.radiusMD, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .disabled(answered)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        TextField(direction == .ptToRu ? strings.typeRussianAnswer : strings.typePortugueseAnswer, text: $typedAnswer)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(12)
                            .background(PortTheme.surfaceInput)
                            .clipShape(RoundedRectangle(cornerRadius: PortTheme.radiusMD, style: .continuous))
                            .disabled(answered)

                        Button(strings.checkAnswer) {
                            checkTypedAnswer(for: card)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(PortTheme.accent)
                        .disabled(answered || typedAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                if !feedback.isEmpty {
                    Text(feedback)
                        .font(.subheadline)
                        .foregroundStyle(feedback.hasPrefix(strings.correctPrefix) ? PortTheme.successText : PortTheme.danger)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(strings.notEnoughWords)
                .font(.headline)
                .foregroundStyle(PortTheme.heading)
            Text(strings.quizEmptyHint)
                .font(.subheadline)
                .foregroundStyle(PortTheme.textMuted)
        }
        .padding(16)
        .portCard()
    }

    private var needMoreWordsState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(strings.needFourWords)
                .font(.headline)
                .foregroundStyle(PortTheme.heading)
            Text(strings.needFourWordsHint)
                .font(.subheadline)
                .foregroundStyle(PortTheme.textMuted)
        }
        .padding(16)
        .portCard()
    }

    private var completeState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(strings.sessionComplete)
                .font(.title3.bold())
                .foregroundStyle(PortTheme.heading)
            Text(strings.sessionScore(score, total: order.count))
                .font(.subheadline)
                .foregroundStyle(PortTheme.textMuted)
            Button(strings.tryAgain) {
                restartSession()
            }
            .buttonStyle(.borderedProminent)
            .tint(PortTheme.accent)
        }
        .padding(16)
        .portCard()
    }

    private var currentCard: VocabularyCard? {
        guard currentIndex < order.count else { return nil }
        let id = order[currentIndex]
        return quizCards.first { $0.id == id }
    }

    private func startSessionIfNeeded() {
        guard order.isEmpty, !quizCards.isEmpty else { return }
        restartSession()
    }

    private func restartSession() {
        order = quizCards.map(\.id).shuffled()
        currentIndex = 0
        score = 0
        answered = false
        feedback = ""
        typedAnswer = ""
        sessionComplete = false
        prepareQuestion()
    }

    private func prepareQuestion() {
        guard let card = currentCard else { return }
        answered = false
        feedback = ""
        typedAnswer = ""
        learningStats.recordQuizPresentation(cardID: card.id)

        if mode == .multipleChoice {
            let pool = quizCards.filter { $0.id != card.id }.shuffled()
            let distractors = Array(pool.prefix(3))
            options = ([card] + distractors).shuffled()
        }
    }

    private func pickOption(_ option: VocabularyCard, correct: VocabularyCard) {
        guard !answered else { return }
        answered = true
        let isCorrect = option.id == correct.id
        if isCorrect { score += 1 }
        learningStats.recordQuizAnswer(cardID: correct.id, correct: isCorrect)
        feedback = isCorrect
            ? strings.correctFeedback
            : strings.incorrectFeedback(optionLabel(for: correct))
        scheduleAdvance()
    }

    private func checkTypedAnswer(for card: VocabularyCard) {
        guard !answered else { return }
        answered = true
        let expected = expectedAnswer(for: card)
        let isCorrect = Self.answersMatch(typedAnswer, expected)
        if isCorrect { score += 1 }
        learningStats.recordQuizAnswer(cardID: card.id, correct: isCorrect)
        feedback = isCorrect ? strings.correctFeedback : strings.expectedAnswer(expected)
        scheduleAdvance()
    }

    private func scheduleAdvance() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            advance()
        }
    }

    private func advance() {
        if currentIndex + 1 >= order.count {
            sessionComplete = true
            learningStats.completeQuizSession(correct: score, total: order.count)
            return
        }
        currentIndex += 1
        prepareQuestion()
    }

    private func prompt(for card: VocabularyCard) -> String {
        direction == .ptToRu ? card.source : card.translation
    }

    private func optionLabel(for card: VocabularyCard) -> String {
        direction == .ptToRu ? card.translation : card.source
    }

    private func expectedAnswer(for card: VocabularyCard) -> String {
        direction == .ptToRu ? card.translation : card.source
    }

    private func optionBackground(for option: VocabularyCard, correct: VocabularyCard) -> Color {
        guard answered else { return PortTheme.surface }
        if option.id == correct.id {
            return PortTheme.accentSoft
        }
        return PortTheme.surface
    }

    private static func answersMatch(_ input: String, _ expected: String) -> Bool {
        let a = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let b = expected.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return !a.isEmpty && a == b
    }
}

private enum QuizMode {
    case multipleChoice
    case typedInput
}

private enum QuizDirection {
    case ptToRu
    case ruToPt
}

#if DEBUG
struct QuizPanelView_Previews: PreviewProvider {
    static var previews: some View {
        QuizPanelView()
            .environmentObject(VocabularyStore())
            .environmentObject(LearningStatsStore())
            .environmentObject(StudyWordSelectionStore())
            .environmentObject(AppSettings())
            .padding()
            .background(PortTheme.background)
    }
}
#endif
