import AVFoundation
import Foundation

enum DictionaryAudioPlayerError: LocalizedError {
    case fileMissing
    case playbackFailed(String)

    var errorDescription: String? {
        switch self {
        case .fileMissing:
            return "Аудиофайл не найден."
        case .playbackFailed(let details):
            return "Не удалось воспроизвести запись: \(details)"
        }
    }
}

@MainActor
final class DictionaryAudioPlayerService: NSObject, ObservableObject {
    static let shared = DictionaryAudioPlayerService()

    @Published private(set) var isPlaying = false
    @Published private(set) var playingWordID: UUID?

    private var player: AVAudioPlayer?

    func play(url: URL, wordID: UUID) throws {
        stop()
        WordTTSService.shared.stop()

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw DictionaryAudioPlayerError.fileMissing
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)

            let audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer.delegate = self
            audioPlayer.prepareToPlay()
            guard audioPlayer.play() else {
                throw DictionaryAudioPlayerError.playbackFailed("AVAudioPlayer.play() returned false")
            }
            player = audioPlayer
            isPlaying = true
            playingWordID = wordID
        } catch let error as DictionaryAudioPlayerError {
            throw error
        } catch {
            throw DictionaryAudioPlayerError.playbackFailed(error.localizedDescription)
        }
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        playingWordID = nil
    }
}

extension DictionaryAudioPlayerService: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.player = nil
            self.isPlaying = false
            self.playingWordID = nil
        }
    }
}
