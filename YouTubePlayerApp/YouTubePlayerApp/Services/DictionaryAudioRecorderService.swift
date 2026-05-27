import AVFoundation
import Foundation

enum DictionaryAudioRecorderError: LocalizedError {
    case permissionDenied
    case sessionSetupFailed(String)
    case recorderInitFailed
    case alreadyRecording
    case notRecording

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Нет доступа к микрофону. Разрешите запись в Настройках."
        case .sessionSetupFailed(let details):
            return "Не удалось подготовить аудиосессию: \(details)"
        case .recorderInitFailed:
            return "Не удалось начать запись."
        case .alreadyRecording:
            return "Запись уже идёт."
        case .notRecording:
            return "Запись не активна."
        }
    }
}

struct DictionaryRecordingResult {
    let url: URL
    let duration: TimeInterval
    let wordID: UUID?
    let folderKey: String?
}

@MainActor
final class DictionaryAudioRecorderService: NSObject, ObservableObject {
    static let shared = DictionaryAudioRecorderService()

    @Published private(set) var isRecording = false
    @Published private(set) var isPaused = false
    @Published private(set) var recordingWordID: UUID?
    @Published private(set) var recordingFolderKey: String?

    private var recorder: AVAudioRecorder?
    private var activeWordID: UUID?
    private var activeFolderKey: String?

    func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func startRecording(for wordID: UUID) async throws {
        try await startRecording(
            at: DictionaryAudioStorage.recordingURL(for: wordID),
            wordID: wordID,
            folderKey: nil
        )
    }

    func startRecording(forFolderKey folderKey: String) async throws {
        try await startRecording(
            at: DictionaryAudioStorage.folderRecordingURL(for: folderKey),
            wordID: nil,
            folderKey: folderKey
        )
    }

    @discardableResult
    func stopRecording() throws -> DictionaryRecordingResult {
        guard let recorder else {
            throw DictionaryAudioRecorderError.notRecording
        }
        guard isRecording || isPaused else {
            throw DictionaryAudioRecorderError.notRecording
        }

        recorder.stop()
        let duration = max(recorder.currentTime, 0)
        let url = recorder.url
        let wordID = activeWordID
        let folderKey = activeFolderKey

        self.recorder = nil
        activeWordID = nil
        activeFolderKey = nil
        isRecording = false
        isPaused = false
        recordingWordID = nil
        recordingFolderKey = nil

        return DictionaryRecordingResult(
            url: url,
            duration: duration,
            wordID: wordID,
            folderKey: folderKey
        )
    }

    func pauseRecording() {
        guard isRecording, !isPaused, let recorder else { return }
        recorder.pause()
        isRecording = false
        isPaused = true
    }

    func resumeRecording() {
        guard isPaused, let recorder else { return }
        guard recorder.record() else { return }
        isRecording = true
        isPaused = false
    }

    func cancelRecording(for wordID: UUID) {
        guard recordingWordID == wordID else { return }
        cancelActiveRecording(deleteFile: true, wordID: wordID, folderKey: nil)
    }

    func cancelRecording(forFolderKey folderKey: String) {
        guard recordingFolderKey == folderKey else { return }
        cancelActiveRecording(deleteFile: true, wordID: nil, folderKey: folderKey)
    }

    func deleteRecording(for wordID: UUID) {
        if recordingWordID == wordID {
            cancelActiveRecording(deleteFile: false, wordID: wordID, folderKey: nil)
        }
        DictionaryAudioStorage.deleteRecording(for: wordID)
    }

    func deleteFolderRecording(for folderKey: String) {
        if recordingFolderKey == folderKey {
            cancelActiveRecording(deleteFile: false, wordID: nil, folderKey: folderKey)
        }
        DictionaryAudioStorage.deleteFolderRecording(for: folderKey)
    }

    private func startRecording(at destination: URL, wordID: UUID?, folderKey: String?) async throws {
        guard !isRecording else { throw DictionaryAudioRecorderError.alreadyRecording }

        let granted = await requestMicrophonePermission()
        guard granted else { throw DictionaryAudioRecorderError.permissionDenied }

        DictionaryAudioPlayerService.shared.stop()

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try session.setActive(true)
        } catch {
            throw DictionaryAudioRecorderError.sessionSetupFailed(error.localizedDescription)
        }

        let folder = destination.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        if FileManager.default.fileExists(atPath: destination.path) {
            try? FileManager.default.removeItem(at: destination)
        }

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            let audioRecorder = try AVAudioRecorder(url: destination, settings: settings)
            audioRecorder.delegate = self
            audioRecorder.isMeteringEnabled = true
            guard audioRecorder.prepareToRecord(), audioRecorder.record() else {
                throw DictionaryAudioRecorderError.recorderInitFailed
            }
            recorder = audioRecorder
            activeWordID = wordID
            activeFolderKey = folderKey
            isRecording = true
            isPaused = false
            recordingWordID = wordID
            recordingFolderKey = folderKey
        } catch let error as DictionaryAudioRecorderError {
            throw error
        } catch {
            throw DictionaryAudioRecorderError.recorderInitFailed
        }
    }

    private func cancelActiveRecording(deleteFile: Bool, wordID: UUID?, folderKey: String?) {
        recorder?.stop()
        recorder = nil
        activeWordID = nil
        activeFolderKey = nil
        isRecording = false
        isPaused = false
        recordingWordID = nil
        recordingFolderKey = nil

        if deleteFile {
            if let wordID {
                DictionaryAudioStorage.deleteRecording(for: wordID)
            } else if let folderKey {
                DictionaryAudioStorage.deleteFolderRecording(for: folderKey)
            }
        }
    }
}

extension DictionaryAudioRecorderService: AVAudioRecorderDelegate {
    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            self.recorder = nil
            self.activeWordID = nil
            self.activeFolderKey = nil
            self.isRecording = false
            self.isPaused = false
            self.recordingWordID = nil
            self.recordingFolderKey = nil
        }
    }
}
