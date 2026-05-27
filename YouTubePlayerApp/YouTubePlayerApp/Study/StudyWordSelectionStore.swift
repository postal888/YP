import Foundation
import Combine

@MainActor
final class StudyWordSelectionStore: ObservableObject {
    private let storageKey = "portulearn.study.quizDisabledCards"

    @Published private(set) var disabledCardIDs: Set<UUID> = []

    init() {
        load()
    }

    func isIncludedInQuiz(_ cardID: UUID) -> Bool {
        !disabledCardIDs.contains(cardID)
    }

    func setIncludedInQuiz(_ cardID: UUID, included: Bool) {
        if included {
            disabledCardIDs.remove(cardID)
        } else {
            disabledCardIDs.insert(cardID)
        }
        persist()
    }

    func filterCards(_ cards: [VocabularyCard]) -> [VocabularyCard] {
        cards.filter { !disabledCardIDs.contains($0.id) }
    }

    func includedCount(in cards: [VocabularyCard]) -> Int {
        cards.filter { !disabledCardIDs.contains($0.id) }.count
    }

    private func load() {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([String].self, from: data)
        else {
            disabledCardIDs = []
            return
        }
        disabledCardIDs = Set(decoded.compactMap(UUID.init(uuidString:)))
    }

    private func persist() {
        let ids = disabledCardIDs.map(\.uuidString)
        guard let data = try? JSONEncoder().encode(ids) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
