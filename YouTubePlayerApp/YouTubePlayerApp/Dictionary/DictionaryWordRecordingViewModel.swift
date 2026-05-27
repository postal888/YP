import Foundation

enum DictionaryWordRecorderPhase: Equatable {
    case idle
    case recording
    case recorded
}

@MainActor
final class DictionaryWordRecordingViewModel: ObservableObject {
    @Published private(set) var phase: DictionaryWordRecorderPhase = .idle
    @Published private(set) var recordingDuration: TimeInterval = 0
    @Published var showDeleteConfirmation = false
    @Published var showExportOptions = false
    @Published var showAlert = false
    @Published var alertTitle = ""
    @Published var alertMessage = ""
    @Published var shareItem: ShareableAudioFile?

    private let card: VocabularyCard
    private let vocabularyStore: VocabularyStore
    private let recorderService: DictionaryAudioRecorderService
    private let playerService: DictionaryAudioPlayerService
    private let exportService: DictionaryAudioExportService

    init(
        card: VocabularyCard,
        vocabularyStore: VocabularyStore,
        recorderService: DictionaryAudioRecorderService = .shared,
        playerService: DictionaryAudioPlayerService = .shared,
        exportService: DictionaryAudioExportService = .shared
    ) {
        self.card = card
        self.vocabularyStore = vocabularyStore
        self.recorderService = recorderService
        self.playerService = playerService
        self.exportService = exportService
        syncPhaseFromStore()
    }

    var cardSource: String { card.source }
    var cardTranslation: String { card.translation }
    var cardID: UUID { card.id }
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
            shareItem = ShareableAudioFile(url: try exportService.exportM4A(from: sourceURL, suggestedName: fileName))
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
                shareItem = ShareableAudioFile(url: url)
            } catch {
                presentError(error)
            }
        }
    }

    func cleanupOnDismiss() {
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

struct ShareableAudioFile: Identifiable {
    let id = UUID()
    let url: URL
}
