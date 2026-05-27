import Foundation

struct VocabularyCard: Identifiable, Codable, Equatable {
    let id: UUID
    let source: String
    let translation: String
    let sourceLanguage: String
    let bookTitle: String?
    let folderKey: String?
    let example: String?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        source: String,
        translation: String,
        sourceLanguage: String,
        bookTitle: String? = nil,
        folderKey: String? = nil,
        example: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.source = source
        self.translation = translation
        self.sourceLanguage = sourceLanguage
        self.bookTitle = bookTitle
        self.folderKey = folderKey
        self.example = example
        self.createdAt = createdAt
    }

    var lookupKey: String {
        source.lowercased()
    }

    var resolvedFolderKey: String {
        if let folderKey, !folderKey.isEmpty {
            return folderKey
        }
        if bookTitle == "YouTube" {
            return VocabularyFolderKey.legacyYouTube
        }
        if let bookTitle, !bookTitle.isEmpty {
            return VocabularyFolderKey.pdf(bookTitle)
        }
        return VocabularyFolderKey.misc
    }
}
