import Foundation
import Combine

struct ImportedBook: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let fileName: String
    let importedAt: Date
    var lastOpenedAt: Date?

    var localURL: URL {
        BookLibraryStore.booksDirectory.appendingPathComponent(fileName)
    }
}

@MainActor
final class BookLibraryStore: ObservableObject {
    static let booksDirectory: URL = {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let folder = base.appendingPathComponent("Books", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }()

    @Published private(set) var books: [ImportedBook] = []

    private let storageKey = "portulearn.books.library"

    init() {
        load()
    }

    func importPDF(from sourceURL: URL) throws -> ImportedBook {
        let didAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let bookID = UUID()
        let fileName = "\(bookID.uuidString).pdf"
        let destination = Self.booksDirectory.appendingPathComponent(fileName)

        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: sourceURL, to: destination)

        let title = sourceURL.deletingPathExtension().lastPathComponent
        let book = ImportedBook(
            id: bookID,
            title: title.isEmpty ? "PDF" : title,
            fileName: fileName,
            importedAt: Date(),
            lastOpenedAt: Date()
        )
        books.insert(book, at: 0)
        persist()
        return book
    }

    func markOpened(_ book: ImportedBook) {
        guard let index = books.firstIndex(where: { $0.id == book.id }) else { return }
        books[index].lastOpenedAt = Date()
        persist()
    }

    func remove(_ book: ImportedBook) {
        try? FileManager.default.removeItem(at: book.localURL)
        books.removeAll { $0.id == book.id }
        persist()
    }

    private func load() {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([ImportedBook].self, from: data)
        else {
            books = []
            return
        }

        books = decoded
            .filter { FileManager.default.fileExists(atPath: $0.localURL.path) }
            .sorted { ($0.lastOpenedAt ?? $0.importedAt) > ($1.lastOpenedAt ?? $1.importedAt) }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(books) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
