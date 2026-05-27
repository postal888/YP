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
    let wordID: UUID
    let url: URL
    let duration: TimeInterval
}

@MainActor
final class DictionaryAudioRecorderService: NSObject, ObservableObject {
    static let shared = DictionaryAudioRecorderService()

    @Published private(set) var isRecording = false
    @Published private(set) var recordingWordID: UUID?

    private var recorder: AVAudioRecorder?
    private var activeWordID: UUID?

    func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func startRecording(for wordID: UUID) async throws {
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

        let destination = DictionaryAudioStorage.recordingURL(for: wordID)
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
            isRecording = true
            recordingWordID = wordID
        } catch let error as DictionaryAudioRecorderError {
            throw error
        } catch {
            throw DictionaryAudioRecorderError.recorderInitFailed
        }
    }

    @discardableResult
    func stopRecording() throws -> DictionaryRecordingResult {
        guard isRecording, let recorder, let wordID = activeWordID else {
            throw DictionaryAudioRecorderError.notRecording
        }

        recorder.stop()
        let duration = max(recorder.currentTime, 0)
        let url = recorder.url

        self.recorder = nil
        activeWordID = nil
        isRecording = false
        recordingWordID = nil

        return DictionaryRecordingResult(wordID: wordID, url: url, duration: duration)
    }

    func cancelRecording(for wordID: UUID) {
        if recordingWordID == wordID {
            recorder?.stop()
            recorder = nil
            activeWordID = nil
            isRecording = false
            recordingWordID = nil
            DictionaryAudioStorage.deleteRecording(for: wordID)
        }
    }

    func deleteRecording(for wordID: UUID) {
        if recordingWordID == wordID {
            recorder?.stop()
            recorder = nil
            activeWordID = nil
            isRecording = false
            recordingWordID = nil
        }
        DictionaryAudioStorage.deleteRecording(for: wordID)
    }
}

extension DictionaryAudioRecorderService: AVAudioRecorderDelegate {
    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            self.recorder = nil
            self.activeWordID = nil
            self.isRecording = false
            self.recordingWordID = nil
        }
    }
}
