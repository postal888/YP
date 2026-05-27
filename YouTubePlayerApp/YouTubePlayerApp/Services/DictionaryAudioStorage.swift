import Foundation

enum DictionaryAudioStorage {
    static let recordingsDirectory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = base
            .appendingPathComponent("recordings", isDirectory: true)
            .appendingPathComponent("dictionary", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }()

    static let exportDirectory: URL = {
        let base = FileManager.default.temporaryDirectory
        let folder = base.appendingPathComponent("dictionary-audio-export", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }()

    static func recordingURL(for wordID: UUID) -> URL {
        recordingsDirectory.appendingPathComponent("\(wordID.uuidString).m4a")
    }

    static func recordingExists(for wordID: UUID) -> Bool {
        FileManager.default.fileExists(atPath: recordingURL(for: wordID).path)
    }

    static func deleteRecording(for wordID: UUID) {
        let url = recordingURL(for: wordID)
        try? FileManager.default.removeItem(at: url)
    }

    static let folderRecordingsDirectory: URL = {
        let folder = recordingsDirectory.appendingPathComponent("folders", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }()

    static func folderRecordingURL(for folderKey: String) -> URL {
        let safeName = folderKey
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "/", with: "_")
        return folderRecordingsDirectory.appendingPathComponent("\(safeName).m4a")
    }

    static func folderRecordingExists(for folderKey: String) -> Bool {
        FileManager.default.fileExists(atPath: folderRecordingURL(for: folderKey).path)
    }

    static func deleteFolderRecording(for folderKey: String) {
        let url = folderRecordingURL(for: folderKey)
        try? FileManager.default.removeItem(at: url)
    }

    static func sanitizedFolderExportName(from folderTitle: String, fileExtension: String) -> String {
        sanitizedExportName(from: folderTitle, fileExtension: fileExtension)
    }

    static func sanitizedExportName(from sourceWord: String, fileExtension: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let trimmed = sourceWord.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmed
            .lowercased()
            .map { char -> Character in
                String(char).rangeOfCharacter(from: allowed) != nil ? char : "_"
            }
            .reduce(into: "") { $0.append($1) }
        let safeBase = base.isEmpty ? "word" : String(base.prefix(48))
        return "\(safeBase)_recording.\(fileExtension)"
    }
}
