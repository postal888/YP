import Foundation

struct DictionaryFolderRecordingSession: Identifiable {
    let folder: VocabularyFolderGroup
    let playbackCards: [VocabularyCard]

    var id: String { folder.key }
}

@MainActor
final class DictionaryFolderRecordingViewModel: ObservableObject {
    @Published private(set) var phase: DictionaryWordRecorderPhase = .idle
    @Published private(set) var recordingDuration: TimeInterval = 0
    @Published var speakDuringRecording: Bool
    @Published var showDeleteConfirmation = false
    @Published var showExportOptions = false
    @Published var showAlert = false
    @Published var alertTitle = ""
    @Published var alertMessage = ""
    @Published var shareItem: ShareableFile?

    private let folder: VocabularyFolderGroup
    private let playbackCards: [VocabularyCard]
    private let vocabularyStore: VocabularyStore
    private let appSettings: AppSettings
    private let recorderService = DictionaryAudioRecorderService.shared
    private let playerService = DictionaryAudioPlayerService.shared
    private let exportService = DictionaryAudioExportService.shared
    private let ttsService = WordTTSService.shared

    private var strings: AppStrings { appSettings.strings }

    init(
        folder: VocabularyFolderGroup,
        playbackCards: [VocabularyCard],
        vocabularyStore: VocabularyStore,
        appSettings: AppSettings
    ) {
        self.folder = folder
        self.playbackCards = playbackCards
        self.vocabularyStore = vocabularyStore
        self.appSettings = appSettings
        self.speakDuringRecording = !playbackCards.isEmpty
        syncPhaseFromStore()
    }

    var folderTitle: String { folder.title }
    var folderKey: String { folder.key }
    var playbackCount: Int { playbackCards.count }
    var hasRecording: Bool { vocabularyStore.hasFolderRecording(for: folder.key) }
    var isRecordingThisFolder: Bool {
        recorderService.recordingFolderKey == folder.key
            && (recorderService.isRecording || recorderService.isPaused)
    }
    var isPlayingThisFolder: Bool {
        playerService.isPlaying && playerService.playingFolderKey == folder.key
    }
    var isMP3ExportAvailable: Bool { AudioTranscodingService.shared.isMP3ExportAvailable }

    func syncPhaseFromStore() {
        if isRecordingThisFolder {
            phase = .recording
        } else if hasRecording {
            phase = .recorded
            recordingDuration = vocabularyStore.folderRecording(for: folder.key)?.duration ?? 0
        } else {
            phase = .idle
        }
    }

    func startRecording() {
        Task {
            do {
                try await recorderService.startRecording(forFolderKey: folder.key)
                phase = .recording
                if speakDuringRecording, !playbackCards.isEmpty {
                    let entries = DictionaryWordRecordingViewModel.ttsEntries(for: playbackCards)
                    ttsService.speakSequence(entries, settings: appSettings, allowDuringRecording: true)
                }
            } catch DictionaryAudioRecorderError.permissionDenied {
                showAlert = true
                alertTitle = strings.microphonePermissionTitle
                alertMessage = strings.microphonePermissionMessage
            } catch {
                presentError(error)
            }
        }
    }

    func stopRecording() {
        ttsService.stop()
        do {
            let result = try recorderService.stopRecording()
            vocabularyStore.setFolderRecording(
                for: folder.key,
                recording: DictionaryWordRecording(createdAt: Date(), duration: result.duration)
            )
            recordingDuration = result.duration
            phase = .recorded
        } catch {
            presentError(error)
        }
    }

    func pauseRecording() {
        guard isRecordingThisFolder else { return }
        ttsService.stop()
        recorderService.pauseRecording()
    }

    func resumeRecording() {
        guard recorderService.isPaused, recorderService.recordingFolderKey == folder.key else { return }
        recorderService.resumeRecording()
    }

    func playRecording() {
        let url = DictionaryAudioStorage.folderRecordingURL(for: folder.key)
        do {
            try playerService.play(url: url, folderKey: folder.key)
        } catch {
            presentError(error)
        }
    }

    func stopPlayback() {
        playerService.stop()
    }

    func deleteRecording() {
        recorderService.deleteFolderRecording(for: folder.key)
        playerService.stop()
        vocabularyStore.clearFolderRecording(for: folder.key)
        recordingDuration = 0
        phase = .idle
    }

    func exportAsM4A() {
        let sourceURL = DictionaryAudioStorage.folderRecordingURL(for: folder.key)
        let fileName = DictionaryAudioStorage.sanitizedFolderExportName(from: folder.title, fileExtension: "m4a")
        do {
            shareItem = ShareableFile(url: try exportService.exportM4A(from: sourceURL, suggestedName: fileName))
        } catch {
            presentError(error)
        }
    }

    func exportAsMP3() {
        Task {
            let sourceURL = DictionaryAudioStorage.folderRecordingURL(for: folder.key)
            let fileName = DictionaryAudioStorage.sanitizedFolderExportName(from: folder.title, fileExtension: "mp3")
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
        if recorderService.recordingFolderKey == folder.key {
            if recorderService.isRecording || recorderService.isPaused {
                recorderService.cancelRecording(forFolderKey: folder.key)
            }
        }
        if isPlayingThisFolder {
            playerService.stop()
        }
    }

    private func presentError(_ error: Error) {
        alertTitle = strings.error
        alertMessage = error.localizedDescription
        showAlert = true
    }
}
