import Foundation
import Combine

@MainActor
final class VocabularyStore: ObservableObject {
    @Published private(set) var cards: [VocabularyCard] = []
    @Published private(set) var folderTitles: [String: String] = [:]

    private let storageKey = "portulearn.vocabulary.cards"
    private let folderTitlesKey = "portulearn.vocabulary.folderTitles"

    init() {
        load()
    }

    var lookupKeys: Set<String> {
        Set(cards.map(\.lookupKey))
    }

    func contains(source: String) -> Bool {
        lookupKeys.contains(source.lowercased())
    }

    func folderDisplayName(for key: String) -> String {
        if let custom = folderTitles[key]?.trimmingCharacters(in: .whitespacesAndNewlines), !custom.isEmpty {
            return custom
        }
        return VocabularyFolderKey.defaultTitle(for: key)
    }

    func groupedFolders(from cards: [VocabularyCard]) -> [VocabularyFolderGroup] {
        let grouped = Dictionary(grouping: cards, by: \.resolvedFolderKey)
        return grouped
            .map { key, items in
                VocabularyFolderGroup(
                    key: key,
                    title: folderDisplayName(for: key),
                    cards: items.sorted { $0.createdAt > $1.createdAt }
                )
            }
            .sorted { lhs, rhs in
                if lhs.isYouTube != rhs.isYouTube {
                    return lhs.isYouTube && !rhs.isYouTube
                }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
    }

    @discardableResult
    func add(
        source: String,
        translation: String,
        sourceLanguage: String,
        bookTitle: String? = nil,
        folderKey: String? = nil,
        folderTitle: String? = nil,
        example: String? = nil
    ) -> VocabularyCard {
        let trimmedSource = source.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTranslation = translation.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = trimmedSource.lowercased()
        let resolvedFolderKey = folderKey
            ?? (bookTitle.map { bookTitle == "YouTube" ? VocabularyFolderKey.legacyYouTube : VocabularyFolderKey.pdf($0) })
            ?? VocabularyFolderKey.misc

        if let folderTitle {
            ensureFolderTitle(key: resolvedFolderKey, defaultTitle: folderTitle)
        } else if let bookTitle, bookTitle != "YouTube" {
            ensureFolderTitle(key: resolvedFolderKey, defaultTitle: bookTitle)
        }

        if let index = cards.firstIndex(where: { $0.lookupKey == key }) {
            let updated = VocabularyCard(
                id: cards[index].id,
                source: trimmedSource,
                translation: trimmedTranslation,
                sourceLanguage: sourceLanguage,
                bookTitle: bookTitle ?? cards[index].bookTitle,
                folderKey: resolvedFolderKey,
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
            folderKey: resolvedFolderKey,
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
            folderKey: card.resolvedFolderKey,
            example: example,
            createdAt: card.createdAt
        )
        cards[index] = updated
        persist()
    }

    func renameFolder(key: String, title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        folderTitles[key] = trimmed
        persistFolderTitles()
    }

    func ensureFolderTitle(key: String, defaultTitle: String) {
        let trimmed = defaultTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if folderTitles[key]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
            folderTitles[key] = trimmed
            persistFolderTitles()
        }
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
        if
            let data = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([VocabularyCard].self, from: data)
        {
            cards = decoded.sorted { $0.createdAt > $1.createdAt }
        } else {
            cards = []
        }

        if
            let data = UserDefaults.standard.data(forKey: folderTitlesKey),
            let decoded = try? JSONDecoder().decode([String: String].self, from: data)
        {
            folderTitles = decoded
        } else {
            folderTitles = [:]
        }

        migrateLegacyFolderTitlesIfNeeded()
    }

    private func migrateLegacyFolderTitlesIfNeeded() {
        for card in cards where card.folderKey == nil {
            let key = card.resolvedFolderKey
            if key == VocabularyFolderKey.legacyYouTube {
                ensureFolderTitle(key: key, defaultTitle: "YouTube")
            } else if key.hasPrefix("pdf:"), let bookTitle = card.bookTitle {
                ensureFolderTitle(key: key, defaultTitle: bookTitle)
            }
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(cards) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func persistFolderTitles() {
        guard let data = try? JSONEncoder().encode(folderTitles) else { return }
        UserDefaults.standard.set(data, forKey: folderTitlesKey)
    }
}
