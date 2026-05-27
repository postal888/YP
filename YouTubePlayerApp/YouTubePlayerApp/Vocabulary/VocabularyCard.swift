import Foundation

struct VocabularyCard: Identifiable, Codable, Equatable {
    let id: UUID
    let source: String
    let translation: String
    let sourceLanguage: String
    let bookTitle: String?
    let example: String?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        source: String,
        translation: String,
        sourceLanguage: String,
        bookTitle: String? = nil,
        example: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.source = source
        self.translation = translation
        self.sourceLanguage = sourceLanguage
        self.bookTitle = bookTitle
        self.example = example
        self.createdAt = createdAt
    }

    var lookupKey: String {
        source.lowercased()
    }
}
