import Foundation
import Combine
import UIKit

@MainActor
final class VocabularyStore: ObservableObject {
    @Published private(set) var cards: [VocabularyCard] = []
    @Published private(set) var folderTitles: [String: String] = [:]
    @Published private(set) var folderRecordings: [String: DictionaryWordRecording] = [:]

    private let storageKey = "portulearn.vocabulary.cards"
    private let folderTitlesKey = "portulearn.vocabulary.folderTitles"
    private let folderRecordingsKey = "portulearn.vocabulary.folderRecordings"

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
                createdAt: cards[index].createdAt,
                recording: cards[index].recording
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
            createdAt: card.createdAt,
            recording: card.recording
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
        DictionaryAudioStorage.deleteRecording(for: card.id)
        DictionaryImageStorage.deleteImage(for: card.id)
        cards.removeAll { $0.id == card.id }
        persist()
    }

    func remove(ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        for id in ids {
            DictionaryAudioStorage.deleteRecording(for: id)
            DictionaryImageStorage.deleteImage(for: id)
        }
        cards.removeAll { ids.contains($0.id) }
        persist()
    }

    func cards(withIDs ids: Set<UUID>) -> [VocabularyCard] {
        cards.filter { ids.contains($0.id) }
    }

    func hasFolderRecording(for folderKey: String) -> Bool {
        folderRecordings[folderKey] != nil && DictionaryAudioStorage.folderRecordingExists(for: folderKey)
    }

    func folderRecording(for folderKey: String) -> DictionaryWordRecording? {
        folderRecordings[folderKey]
    }

    func setFolderRecording(for folderKey: String, recording: DictionaryWordRecording) {
        folderRecordings[folderKey] = recording
        persistFolderRecordings()
    }

    func clearFolderRecording(for folderKey: String) {
        DictionaryAudioStorage.deleteFolderRecording(for: folderKey)
        folderRecordings.removeValue(forKey: folderKey)
        persistFolderRecordings()
    }

    func remove(at offsets: IndexSet) {
        for index in offsets {
            DictionaryAudioStorage.deleteRecording(for: cards[index].id)
            DictionaryImageStorage.deleteImage(for: cards[index].id)
        }
        cards.remove(atOffsets: offsets)
        persist()
    }

    func hasImage(for cardID: UUID) -> Bool {
        DictionaryImageStorage.imageExists(for: cardID)
    }

    func image(for cardID: UUID) -> UIImage? {
        DictionaryImageStorage.loadImage(for: cardID)
    }

    func setImage(_ image: UIImage, for cardID: UUID) throws {
        try DictionaryImageStorage.saveImage(image, for: cardID)
        objectWillChange.send()
    }

    func clearImage(for cardID: UUID) {
        DictionaryImageStorage.deleteImage(for: cardID)
        objectWillChange.send()
    }

    func hasRecording(for cardID: UUID) -> Bool {
        guard let card = cards.first(where: { $0.id == cardID }) else { return false }
        return card.hasRecording && DictionaryAudioStorage.recordingExists(for: cardID)
    }

    func recording(for cardID: UUID) -> DictionaryWordRecording? {
        cards.first(where: { $0.id == cardID })?.recording
    }

    func setRecording(for cardID: UUID, recording: DictionaryWordRecording) {
        guard let index = cards.firstIndex(where: { $0.id == cardID }) else { return }
        let card = cards[index]
        cards[index] = VocabularyCard(
            id: card.id,
            source: card.source,
            translation: card.translation,
            sourceLanguage: card.sourceLanguage,
            bookTitle: card.bookTitle,
            folderKey: card.resolvedFolderKey,
            example: card.example,
            createdAt: card.createdAt,
            recording: recording
        )
        persist()
    }

    func clearRecording(for cardID: UUID) {
        guard let index = cards.firstIndex(where: { $0.id == cardID }) else { return }
        DictionaryAudioStorage.deleteRecording(for: cardID)
        let card = cards[index]
        cards[index] = VocabularyCard(
            id: card.id,
            source: card.source,
            translation: card.translation,
            sourceLanguage: card.sourceLanguage,
            bookTitle: card.bookTitle,
            folderKey: card.resolvedFolderKey,
            example: card.example,
            createdAt: card.createdAt,
            recording: nil
        )
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

        loadFolderRecordings()

        migrateLegacyFolderTitlesIfNeeded()
    }

    private func persistFolderRecordings() {
        guard let data = try? JSONEncoder().encode(folderRecordings) else { return }
        UserDefaults.standard.set(data, forKey: folderRecordingsKey)
    }

    private func loadFolderRecordings() {
        if
            let data = UserDefaults.standard.data(forKey: folderRecordingsKey),
            let decoded = try? JSONDecoder().decode([String: DictionaryWordRecording].self, from: data)
        {
            let filtered = decoded.filter { DictionaryAudioStorage.folderRecordingExists(for: $0.key) }
            folderRecordings = filtered
            if filtered.count != decoded.count {
                persistFolderRecordings()
            }
        } else {
            folderRecordings = [:]
        }
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
