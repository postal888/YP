import AVFoundation
import Foundation

enum DictionaryAudioPlayerError: LocalizedError {
    case fileMissing
    case playbackFailed(String)

    var errorDescription: String? {
        switch self {
        case .fileMissing:
            return "Audio file not found."
        case .playbackFailed(let details):
            return "Could not play recording: \(details)"
        }
    }
}

@MainActor
final class DictionaryAudioPlayerService: NSObject, ObservableObject {
    static let shared = DictionaryAudioPlayerService()

    @Published private(set) var isPlaying = false
    @Published private(set) var isPaused = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var playingWordID: UUID?
    @Published private(set) var playingFolderKey: String?
    @Published private(set) var activeURL: URL?

    private var player: AVAudioPlayer?
    private var progressTimer: Timer?

    func play(url: URL, wordID: UUID? = nil, folderKey: String? = nil) throws {
        if activeURL == url, isPaused, let player {
            player.play()
            isPlaying = true
            isPaused = false
            startProgressTimer()
            return
        }

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
            activeURL = url
            duration = audioPlayer.duration
            currentTime = audioPlayer.currentTime
            isPlaying = true
            isPaused = false
            playingWordID = wordID
            playingFolderKey = folderKey
            startProgressTimer()
        } catch let error as DictionaryAudioPlayerError {
            throw error
        } catch {
            throw DictionaryAudioPlayerError.playbackFailed(error.localizedDescription)
        }
    }

    func pause() {
        guard let player, isPlaying else { return }
        player.pause()
        isPlaying = false
        isPaused = true
        currentTime = player.currentTime
        stopProgressTimer()
    }

    func resume() {
        guard let player, isPaused else { return }
        player.play()
        isPlaying = true
        isPaused = false
        startProgressTimer()
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else if isPaused {
            resume()
        }
    }

    func stop() {
        stopProgressTimer()
        player?.stop()
        player = nil
        isPlaying = false
        isPaused = false
        currentTime = 0
        duration = 0
        activeURL = nil
        playingWordID = nil
        playingFolderKey = nil
    }

    func seek(by delta: TimeInterval) {
        guard let player else { return }
        let newTime = max(0, min(player.duration, player.currentTime + delta))
        player.currentTime = newTime
        currentTime = newTime
    }

    func seek(to time: TimeInterval) {
        guard let player else { return }
        let newTime = max(0, min(player.duration, time))
        player.currentTime = newTime
        currentTime = newTime
    }

    func isActive(_ item: DictionaryRecordingListItem) -> Bool {
        activeURL == item.url && (isPlaying || isPaused)
    }

    private func startProgressTimer() {
        stopProgressTimer()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let player = self.player else { return }
                self.currentTime = player.currentTime
                self.duration = player.duration
            }
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
}

extension DictionaryAudioPlayerService: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.stopProgressTimer()
            self.player = nil
            self.isPlaying = false
            self.isPaused = false
            self.currentTime = 0
            self.activeURL = nil
            self.playingWordID = nil
            self.playingFolderKey = nil
        }
    }
}
