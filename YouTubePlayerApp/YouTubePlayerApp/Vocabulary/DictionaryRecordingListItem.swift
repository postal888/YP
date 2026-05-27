import Foundation

struct DictionaryRecordingListItem: Identifiable, Hashable {
    enum Kind: Hashable {
        case word(UUID)
        case folder(String)
    }

    let id: String
    let title: String
    let subtitle: String
    let url: URL
    let duration: TimeInterval
    let createdAt: Date
    let kind: Kind
    let detailCount: Int?
}

extension VocabularyStore {
    func allRecordingItems() -> [DictionaryRecordingListItem] {
        var items: [DictionaryRecordingListItem] = []

        for card in cards where hasRecording(for: card.id) {
            guard let recording = recording(for: card.id) else { continue }
            items.append(
                DictionaryRecordingListItem(
                    id: "word-\(card.id.uuidString)",
                    title: card.source,
                    subtitle: card.translation,
                    url: DictionaryAudioStorage.recordingURL(for: card.id),
                    duration: recording.duration,
                    createdAt: recording.createdAt,
                    kind: .word(card.id),
                    detailCount: nil
                )
            )
        }

        for (folderKey, recording) in folderRecordings where DictionaryAudioStorage.folderRecordingExists(for: folderKey) {
            let cardCount = cards.filter { $0.resolvedFolderKey == folderKey }.count
            items.append(
                DictionaryRecordingListItem(
                    id: "folder-\(folderKey)",
                    title: folderDisplayName(for: folderKey),
                    subtitle: folderDisplayName(for: folderKey),
                    url: DictionaryAudioStorage.folderRecordingURL(for: folderKey),
                    duration: recording.duration,
                    createdAt: recording.createdAt,
                    kind: .folder(folderKey),
                    detailCount: cardCount
                )
            )
        }

        return items.sorted { $0.createdAt > $1.createdAt }
    }
}
