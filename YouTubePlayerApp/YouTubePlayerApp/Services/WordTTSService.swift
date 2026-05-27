import Foundation
import AVFoundation

struct TTSQueueEntry: Equatable {
    let text: String
    let languageCode: String
    let cardID: UUID?
}

@MainActor
final class WordTTSService: ObservableObject {
    static let shared = WordTTSService()

    @Published private(set) var isPlaying = false
    @Published private(set) var playingCardID: UUID?

    private var player: AVAudioPlayer?
    private var sequenceTask: Task<Void, Never>?

    func speak(
        text: String,
        languageCode: String,
        cardID: UUID?,
        settings: AppSettings
    ) {
        sequenceTask?.cancel()
        sequenceTask = Task {
            await play(
                text: text,
                languageCode: languageCode,
                cardID: cardID,
                settings: settings,
                allowDuringRecording: false
            )
            sequenceTask = nil
        }
    }

    func speakSequence(
        _ entries: [TTSQueueEntry],
        settings: AppSettings,
        allowDuringRecording: Bool = false
    ) {
        sequenceTask?.cancel()
        sequenceTask = Task {
            await runSequence(entries, settings: settings, allowDuringRecording: allowDuringRecording)
            sequenceTask = nil
        }
    }

    func stop() {
        sequenceTask?.cancel()
        sequenceTask = nil
        player?.stop()
        player = nil
        isPlaying = false
        playingCardID = nil
    }

    private func runSequence(
        _ entries: [TTSQueueEntry],
        settings: AppSettings,
        allowDuringRecording: Bool
    ) async {
        for entry in entries {
            if Task.isCancelled { break }
            await play(
                text: entry.text,
                languageCode: entry.languageCode,
                cardID: entry.cardID,
                settings: settings,
                allowDuringRecording: allowDuringRecording
            )
            if Task.isCancelled { break }
            try? await Task.sleep(nanoseconds: 450_000_000)
        }
    }

    private func play(
        text: String,
        languageCode: String,
        cardID: UUID?,
        settings: AppSettings,
        allowDuringRecording: Bool
    ) async {
        if !allowDuringRecording {
            player?.stop()
            player = nil
        }

        isPlaying = true
        playingCardID = cardID

        do {
            let data = try await PortuPrepBackendService.shared.synthesizeSpeech(
                text: text,
                languageCode: languageCode,
                baseURL: settings.normalizedBackendURL
            )

            let session = AVAudioSession.sharedInstance()
            if allowDuringRecording {
                try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
            } else {
                try session.setCategory(.playback, mode: .default)
            }
            try session.setActive(true)

            let audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer.prepareToPlay()
            player = audioPlayer
            audioPlayer.play()

            let duration = audioPlayer.duration
            try await Task.sleep(nanoseconds: UInt64(max(duration, 0.2) * 1_000_000_000))
        } catch {
            if Task.isCancelled { return }
        }

        if !Task.isCancelled {
            isPlaying = false
            playingCardID = nil
            player = nil
        }
    }
}
