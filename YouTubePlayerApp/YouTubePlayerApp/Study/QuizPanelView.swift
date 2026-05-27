import SwiftUI

@MainActor
struct QuizPanelView: View {
    @EnvironmentObject private var vocabularyStore: VocabularyStore
    @EnvironmentObject private var learningStats: LearningStatsStore

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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            controls

            if vocabularyStore.cards.isEmpty {
                emptyState
            } else if sessionComplete {
                completeState
            } else if mode == .multipleChoice, vocabularyStore.cards.count < 4 {
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
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Режим", selection: $mode) {
                Text("4 варианта").tag(QuizMode.multipleChoice)
                Text("Ввод").tag(QuizMode.typedInput)
            }
            .pickerStyle(.segmented)
            .onChange(of: mode) { _ in restartSession() }

            Picker("Направление", selection: $direction) {
                Text("PT → RU").tag(QuizDirection.ptToRu)
                Text("RU → PT").tag(QuizDirection.ruToPt)
            }
            .pickerStyle(.segmented)
            .onChange(of: direction) { _ in restartSession() }
        }
    }

    @ViewBuilder
    private var questionBlock: some View {
        if let card = currentCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Вопрос \(currentIndex + 1) из \(order.count) · верно: \(score)")
                    .font(.caption)
                    .foregroundStyle(PortTheme.textMuted)

                Text(prompt(for: card))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(PortTheme.heading)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
                        TextField(direction == .ptToRu ? "Перевод по-русски" : "Ответ по-португальски", text: $typedAnswer)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(12)
                            .background(PortTheme.surfaceInput)
                            .clipShape(RoundedRectangle(cornerRadius: PortTheme.radiusMD, style: .continuous))
                            .disabled(answered)

                        Button("Проверить") {
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
                        .foregroundStyle(feedback.hasPrefix("Верно") ? PortTheme.successText : PortTheme.danger)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Недостаточно слов")
                .font(.headline)
                .foregroundStyle(PortTheme.heading)
            Text("Добавьте слова из видео или читалки, чтобы проходить квиз.")
                .font(.subheadline)
                .foregroundStyle(PortTheme.textMuted)
        }
        .padding(16)
        .portCard()
    }

    private var needMoreWordsState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Нужно минимум 4 слова")
                .font(.headline)
                .foregroundStyle(PortTheme.heading)
            Text("Для режима «4 варианта» добавьте больше слов или выберите «Ввод».")
                .font(.subheadline)
                .foregroundStyle(PortTheme.textMuted)
        }
        .padding(16)
        .portCard()
    }

    private var completeState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Сессия завершена")
                .font(.title3.bold())
                .foregroundStyle(PortTheme.heading)
            Text("Правильных ответов: \(score) из \(order.count)")
                .font(.subheadline)
                .foregroundStyle(PortTheme.textMuted)
            Button("Ещё раз") {
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
        return vocabularyStore.cards.first { $0.id == id }
    }

    private func startSessionIfNeeded() {
        guard order.isEmpty, !vocabularyStore.cards.isEmpty else { return }
        restartSession()
    }

    private func restartSession() {
        order = vocabularyStore.cards.map(\.id).shuffled()
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

        if mode == .multipleChoice {
            let pool = vocabularyStore.cards.filter { $0.id != card.id }.shuffled()
            let distractors = Array(pool.prefix(3))
            options = ([card] + distractors).shuffled()
        }
    }

    private func pickOption(_ option: VocabularyCard, correct: VocabularyCard) {
        guard !answered else { return }
        answered = true
        let isCorrect = option.id == correct.id
        if isCorrect { score += 1 }
        learningStats.recordQuizAnswer(correct: isCorrect)
        feedback = isCorrect ? "Верно!" : "Неверно. Правильно: \(optionLabel(for: correct))"
        scheduleAdvance()
    }

    private func checkTypedAnswer(for card: VocabularyCard) {
        guard !answered else { return }
        answered = true
        let expected = expectedAnswer(for: card)
        let isCorrect = Self.answersMatch(typedAnswer, expected)
        if isCorrect { score += 1 }
        learningStats.recordQuizAnswer(correct: isCorrect)
        feedback = isCorrect ? "Верно!" : "Ожидалось: \(expected)"
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
            .padding()
            .background(PortTheme.background)
    }
}
#endif
