import Foundation

enum DictionaryCSVExportError: LocalizedError {
    case emptyVocabulary
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .emptyVocabulary:
            return "В словаре нет слов для экспорта."
        case .writeFailed(let details):
            return "Не удалось создать CSV файл: \(details)"
        }
    }
}

struct DictionaryCSVExportService {
    static let shared = DictionaryCSVExportService()

    private static let exportDirectory: URL = {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("dictionary-csv-export", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }()

    private static let headers = [
        "word",
        "translation",
        "language",
        "folder",
        "example",
        "has_recording",
        "recording_duration_sec",
        "created_at"
    ]

    private let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    func exportCSV(
        cards: [VocabularyCard],
        folderName: (VocabularyCard) -> String,
        hasRecording: (UUID) -> Bool
    ) throws -> URL {
        guard !cards.isEmpty else { throw DictionaryCSVExportError.emptyVocabulary }

        var lines = [Self.headers.joined(separator: ",")]
        lines.reserveCapacity(cards.count + 1)

        for card in cards {
            let recordingDuration = card.recording.map { String(format: "%.1f", $0.duration) } ?? ""
            let row = [
                card.source,
                card.translation,
                card.sourceLanguage,
                folderName(card),
                card.example ?? "",
                hasRecording(card.id) ? "yes" : "no",
                recordingDuration,
                dateFormatter.string(from: card.createdAt)
            ]
            lines.append(row.map(escapeCSVField).joined(separator: ","))
        }

        let csvData = Data((lines.joined(separator: "\n") + "\n").utf8)
        let fileName = exportFileName()
        let destination = Self.exportDirectory.appendingPathComponent(fileName)

        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }

        do {
            try csvData.write(to: destination, options: Data.WritingOptions.atomic)
            return destination
        } catch {
            throw DictionaryCSVExportError.writeFailed(error.localizedDescription)
        }
    }

    private func exportFileName() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        return "dictionary_\(formatter.string(from: Date())).csv"
    }

    private func escapeCSVField(_ value: String) -> String {
        let needsQuotes = value.contains(",")
            || value.contains("\"")
            || value.contains("\n")
            || value.contains("\r")
        guard needsQuotes else { return value }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
