import Foundation

struct CardStudyStats: Codable, Equatable {
    var quizShownCount: Int = 0
    var quizCorrectCount: Int = 0

    var accuracyPercent: Int? {
        guard quizShownCount > 0 else { return nil }
        return Int((Double(quizCorrectCount) / Double(quizShownCount) * 100).rounded())
    }

    var accuracyFraction: Double {
        guard quizShownCount > 0 else { return 0 }
        return Double(quizCorrectCount) / Double(quizShownCount)
    }
}
