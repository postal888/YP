import Foundation

enum DictionaryAudioExportError: LocalizedError {
    case sourceMissing
    case copyFailed(String)

    var errorDescription: String? {
        switch self {
        case .sourceMissing:
            return "Recording file not found."
        case .copyFailed(let details):
            return "Could not prepare export file: \(details)"
        }
    }
}

final class DictionaryAudioExportService {
    static let shared = DictionaryAudioExportService()

    private init() {}

    func exportM4A(from sourceURL: URL, suggestedName: String) throws -> URL {
        try copyToExportDirectory(sourceURL: sourceURL, fileName: suggestedName)
    }

    func exportMP3(from sourceURL: URL, suggestedName: String) async throws -> URL {
        let destination = DictionaryAudioStorage.exportDirectory.appendingPathComponent(suggestedName)
        try await AudioTranscodingService.shared.exportToMP3(from: sourceURL, destinationURL: destination)
        return destination
    }

    private func copyToExportDirectory(sourceURL: URL, fileName: String) throws -> URL {
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw DictionaryAudioExportError.sourceMissing
        }

        let destination = DictionaryAudioStorage.exportDirectory.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }

        do {
            try FileManager.default.copyItem(at: sourceURL, to: destination)
            return destination
        } catch {
            throw DictionaryAudioExportError.copyFailed(error.localizedDescription)
        }
    }
}
