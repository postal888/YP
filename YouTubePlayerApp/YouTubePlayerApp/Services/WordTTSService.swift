import Foundation
import AVFoundation

@MainActor
final class WordTTSService: ObservableObject {
    static let shared = WordTTSService()

    @Published private(set) var isPlaying = false
    @Published private(set) var playingCardID: UUID?

    private var player: AVAudioPlayer?

    func speak(
        text: String,
        languageCode: String,
        cardID: UUID?,
        settings: AppSettings
    ) {
        Task {
            await play(text: text, languageCode: languageCode, cardID: cardID, settings: settings)
        }
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        playingCardID = nil
    }

    private func play(
        text: String,
        languageCode: String,
        cardID: UUID?,
        settings: AppSettings
    ) async {
        stop()
        isPlaying = true
        playingCardID = cardID

        do {
            let data = try await PortuPrepBackendService.shared.synthesizeSpeech(
                text: text,
                languageCode: languageCode,
                baseURL: settings.normalizedBackendURL
            )
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)

            let audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer.prepareToPlay()
            player = audioPlayer
            audioPlayer.play()

            let duration = audioPlayer.duration
            try await Task.sleep(nanoseconds: UInt64(max(duration, 0.2) * 1_000_000_000))
        } catch {
            // Playback errors are non-fatal; UI can retry.
        }

        isPlaying = false
        playingCardID = nil
        player = nil
    }
}
