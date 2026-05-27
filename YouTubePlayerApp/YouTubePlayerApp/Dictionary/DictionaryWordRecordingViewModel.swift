import Foundation

struct DictionaryRecordingSession: Identifiable {
    let card: VocabularyCard
    let playbackCards: [VocabularyCard]

    var id: UUID { card.id }
}

extension DictionaryWordRecordingViewModel {
    static func ttsEntries(for cards: [VocabularyCard]) -> [TTSQueueEntry] {
        cards.flatMap { card in
            [
                TTSQueueEntry(text: card.source, languageCode: card.sourceLanguage, cardID: card.id),
                TTSQueueEntry(text: card.translation, languageCode: fallbackTranslationLanguage(for: card.sourceLanguage), cardID: card.id)
            ]
        }
    }

    private static func fallbackTranslationLanguage(for sourceLanguage: String) -> String {
        sourceLanguage.lowercased() == "ru" ? "en" : "ru"
    }
}

@MainActor
final class DictionaryWordRecordingViewModel: ObservableObject {
    @Published private(set) var phase: DictionaryWordRecorderPhase = .idle
    @Published private(set) var recordingDuration: TimeInterval = 0
    @Published var speakDuringRecording: Bool
    @Published var showDeleteConfirmation = false
    @Published var showExportOptions = false
    @Published var showAlert = false
    @Published var alertTitle = ""
    @Published var alertMessage = ""
    @Published var shareItem: ShareableFile?

    private let card: VocabularyCard
    private let playbackCards: [VocabularyCard]
    private let vocabularyStore: VocabularyStore
    private let appSettings: AppSettings
    private let recorderService: DictionaryAudioRecorderService
    private let playerService: DictionaryAudioPlayerService
    private let exportService: DictionaryAudioExportService
    private let ttsService: WordTTSService

    init(
        card: VocabularyCard,
        vocabularyStore: VocabularyStore,
        playbackCards: [VocabularyCard],
        appSettings: AppSettings
    ) {
        self.card = card
        self.playbackCards = playbackCards
        self.vocabularyStore = vocabularyStore
        self.appSettings = appSettings
        self.speakDuringRecording = !playbackCards.isEmpty
        self.recorderService = DictionaryAudioRecorderService.shared
        self.playerService = DictionaryAudioPlayerService.shared
        self.exportService = DictionaryAudioExportService.shared
        self.ttsService = WordTTSService.shared
        syncPhaseFromStore()
    }

    var cardSource: String { card.source }
    var cardTranslation: String { card.translation }
    var cardID: UUID { card.id }
    var playbackCount: Int { playbackCards.count }
    var hasRecording: Bool { vocabularyStore.hasRecording(for: card.id) }
    var isRecordingThisCard: Bool { recorderService.isRecording && recorderService.recordingWordID == card.id }
    var isPlayingThisCard: Bool { playerService.isPlaying && playerService.playingWordID == card.id }
    var isMP3ExportAvailable: Bool { AudioTranscodingService.shared.isMP3ExportAvailable }

    func syncPhaseFromStore() {
        if isRecordingThisCard {
            phase = .recording
        } else if hasRecording {
            phase = .recorded
            recordingDuration = vocabularyStore.recording(for: card.id)?.duration ?? 0
        } else {
            phase = .idle
        }
    }

    func startRecording() {
        Task {
            do {
                try await recorderService.startRecording(for: card.id)
                phase = .recording
                if speakDuringRecording, !playbackCards.isEmpty {
                    let entries = Self.ttsEntries(for: playbackCards)
                    ttsService.speakSequence(entries, settings: appSettings, allowDuringRecording: true)
                }
            } catch DictionaryAudioRecorderError.permissionDenied {
                showAlert = true
                alertTitle = "Нет доступа к микрофону"
                alertMessage = "Разрешите доступ к микрофону в Настройках, чтобы записывать произношение слов."
            } catch {
                presentError(error)
            }
        }
    }

    func stopRecording() {
        ttsService.stop()
        do {
            let result = try recorderService.stopRecording()
            vocabularyStore.setRecording(
                for: card.id,
                recording: DictionaryWordRecording(createdAt: Date(), duration: result.duration)
            )
            recordingDuration = result.duration
            phase = .recorded
        } catch {
            presentError(error)
        }
    }

    func playRecording() {
        let url = DictionaryAudioStorage.recordingURL(for: card.id)
        do {
            try playerService.play(url: url, wordID: card.id)
        } catch {
            presentError(error)
        }
    }

    func stopPlayback() {
        playerService.stop()
    }

    func deleteRecording() {
        recorderService.deleteRecording(for: card.id)
        playerService.stop()
        vocabularyStore.clearRecording(for: card.id)
        recordingDuration = 0
        phase = .idle
    }

    func exportAsM4A() {
        let sourceURL = DictionaryAudioStorage.recordingURL(for: card.id)
        let fileName = DictionaryAudioStorage.sanitizedExportName(from: card.source, fileExtension: "m4a")
        do {
            shareItem = ShareableFile(url: try exportService.exportM4A(from: sourceURL, suggestedName: fileName))
        } catch {
            presentError(error)
        }
    }

    func exportAsMP3() {
        Task {
            let sourceURL = DictionaryAudioStorage.recordingURL(for: card.id)
            let fileName = DictionaryAudioStorage.sanitizedExportName(from: card.source, fileExtension: "mp3")
            do {
                let url = try await exportService.exportMP3(from: sourceURL, suggestedName: fileName)
                shareItem = ShareableFile(url: url)
            } catch {
                presentError(error)
            }
        }
    }

    func cleanupOnDismiss() {
        ttsService.stop()
        if isRecordingThisCard {
            recorderService.cancelRecording(for: card.id)
        }
        if isPlayingThisCard {
            playerService.stop()
        }
    }

    private func presentError(_ error: Error) {
        alertTitle = "Ошибка"
        alertMessage = error.localizedDescription
        showAlert = true
    }
}

enum DictionaryWordRecorderPhase: Equatable {
    case idle
    case recording
    case recorded
}
