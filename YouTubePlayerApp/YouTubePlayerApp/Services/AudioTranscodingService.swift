import Foundation

enum AudioTranscodingError: LocalizedError {
    case mp3EncoderUnavailable
    case exportFailed(String)

    var errorDescription: String? {
        switch self {
        case .mp3EncoderUnavailable:
            return "MP3 экспорт пока недоступен. Подключите MP3 encoder (LAME/FFmpeg) через AudioTranscodingService.mp3Provider."
        case .exportFailed(let details):
            return "Не удалось экспортировать аудио: \(details)"
        }
    }
}

/// Extension point for a future LAME / FFmpeg based MP3 encoder.
protocol MP3TranscodingProvider: AnyObject {
    func transcodeM4AToMP3(sourceURL: URL, destinationURL: URL) async throws
}

/// Converts stored M4A recordings into export formats.
/// iOS does not provide a native MP3 encoder in AVFoundation, so MP3 export
/// is routed through an injectable provider.
final class AudioTranscodingService {
    static let shared = AudioTranscodingService()

    /// TODO: Assign a concrete LAME/FFmpeg-backed provider when added to the project.
    weak var mp3Provider: MP3TranscodingProvider?

    var isMP3ExportAvailable: Bool {
        mp3Provider != nil
    }

    func exportToMP3(from m4aURL: URL, destinationURL: URL) async throws {
        guard let mp3Provider else {
            throw AudioTranscodingError.mp3EncoderUnavailable
        }

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        do {
            try await mp3Provider.transcodeM4AToMP3(sourceURL: m4aURL, destinationURL: destinationURL)
        } catch let error as AudioTranscodingError {
            throw error
        } catch {
            throw AudioTranscodingError.exportFailed(error.localizedDescription)
        }
    }
}
