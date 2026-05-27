import Foundation
import Combine

@MainActor
final class VocabularyStore: ObservableObject {
    @Published private(set) var cards: [VocabularyCard] = []

    private let storageKey = "portulearn.vocabulary.cards"

    init() {
        load()
    }

    var lookupKeys: Set<String> {
        Set(cards.map(\.lookupKey))
    }

    func contains(source: String) -> Bool {
        lookupKeys.contains(source.lowercased())
    }

    @discardableResult
    func add(
        source: String,
        translation: String,
        sourceLanguage: String,
        bookTitle: String? = nil,
        example: String? = nil
    ) -> VocabularyCard {
        let trimmedSource = source.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTranslation = translation.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = trimmedSource.lowercased()

        if let index = cards.firstIndex(where: { $0.lookupKey == key }) {
            let updated = VocabularyCard(
                id: cards[index].id,
                source: trimmedSource,
                translation: trimmedTranslation,
                sourceLanguage: sourceLanguage,
                bookTitle: bookTitle ?? cards[index].bookTitle,
                example: example ?? cards[index].example,
                createdAt: cards[index].createdAt
            )
            cards[index] = updated
            persist()
            return updated
        }

        let card = VocabularyCard(
            source: trimmedSource,
            translation: trimmedTranslation,
            sourceLanguage: sourceLanguage,
            bookTitle: bookTitle,
            example: example
        )
        cards.insert(card, at: 0)
        persist()
        return card
    }

    func update(
        _ card: VocabularyCard,
        source: String,
        translation: String,
        example: String?
    ) {
        guard let index = cards.firstIndex(where: { $0.id == card.id }) else { return }
        let updated = VocabularyCard(
            id: card.id,
            source: source.trimmingCharacters(in: .whitespacesAndNewlines),
            translation: translation.trimmingCharacters(in: .whitespacesAndNewlines),
            sourceLanguage: card.sourceLanguage,
            bookTitle: card.bookTitle,
            example: example,
            createdAt: card.createdAt
        )
        cards[index] = updated
        persist()
    }

    func remove(_ card: VocabularyCard) {
        cards.removeAll { $0.id == card.id }
        persist()
    }

    func remove(at offsets: IndexSet) {
        cards.remove(atOffsets: offsets)
        persist()
    }

    private func load() {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([VocabularyCard].self, from: data)
        else {
            cards = []
            return
        }
        cards = decoded.sorted { $0.createdAt > $1.createdAt }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(cards) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
