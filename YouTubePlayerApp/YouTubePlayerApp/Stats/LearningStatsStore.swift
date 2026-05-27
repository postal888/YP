import Foundation
import Combine

struct LearningStatsSnapshot: Codable, Equatable {
    var reviewSessions: Int = 0
    var quizSessions: Int = 0
    var ratingHistory: [Bool] = []
    var totalStudySeconds: Int = 0
    var launchDays: [String] = []
    var cardStats: [String: CardStudyStats] = [:]
}

@MainActor
final class LearningStatsStore: ObservableObject {
    @Published private(set) var snapshot: LearningStatsSnapshot

    private let storageKey = "portulearn.learning-stats-v1"
    private var sessionStartedAt: Date?

    init() {
        if
            let data = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode(LearningStatsSnapshot.self, from: data)
        {
            snapshot = decoded
        } else {
            snapshot = LearningStatsSnapshot()
        }
        registerLaunchDay()
    }

    var streakDays: Int {
        let sorted = snapshot.launchDays.sorted()
        guard !sorted.isEmpty else { return 0 }

        let formatter = Self.dayFormatter
        let today = formatter.string(from: Date())
        guard sorted.contains(today) else { return 0 }

        var streak = 1
        var cursor = Date()
        while true {
            guard let previous = Calendar.current.date(byAdding: .day, value: -1, to: cursor) else { break }
            let key = formatter.string(from: previous)
            if sorted.contains(key) {
                streak += 1
                cursor = previous
            } else {
                break
            }
        }
        return streak
    }

    var accuracyPercent: Int? {
        let recent = snapshot.ratingHistory.suffix(10)
        guard !recent.isEmpty else { return nil }
        let correct = recent.filter { $0 }.count
        return Int((Double(correct) / Double(recent.count) * 100).rounded())
    }

    var learnedWordsEstimate: Int {
        snapshot.ratingHistory.filter { $0 }.count
    }

    func beginStudySession() {
        sessionStartedAt = Date()
    }

    func endStudySession() {
        guard let started = sessionStartedAt else { return }
        let seconds = max(0, Int(Date().timeIntervalSince(started)))
        snapshot.totalStudySeconds += seconds
        sessionStartedAt = nil
        persist()
    }

    func recordReviewSession(cardsReviewed: Int) {
        guard cardsReviewed > 0 else { return }
        snapshot.reviewSessions += 1
        persist()
    }

    func recordQuizAnswer(correct: Bool) {
        snapshot.ratingHistory.append(correct)
        if snapshot.ratingHistory.count > 100 {
            snapshot.ratingHistory.removeFirst(snapshot.ratingHistory.count - 100)
        }
        persist()
    }

    func stats(for cardID: UUID) -> CardStudyStats {
        snapshot.cardStats[cardID.uuidString] ?? CardStudyStats()
    }

    func recordQuizPresentation(cardID: UUID) {
        var stats = self.stats(for: cardID)
        stats.quizShownCount += 1
        snapshot.cardStats[cardID.uuidString] = stats
        persist()
    }

    func recordQuizAnswer(cardID: UUID, correct: Bool) {
        recordQuizAnswer(correct: correct)
        var stats = self.stats(for: cardID)
        stats.quizCorrectCount += correct ? 1 : 0
        snapshot.cardStats[cardID.uuidString] = stats
        persist()
    }

    func completeQuizSession(correct: Int, total: Int) {
        snapshot.quizSessions += 1
        _ = correct
        _ = total
        persist()
    }

    func registerLaunchDay() {
        let today = Self.dayFormatter.string(from: Date())
        if !snapshot.launchDays.contains(today) {
            snapshot.launchDays.append(today)
            persist()
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
