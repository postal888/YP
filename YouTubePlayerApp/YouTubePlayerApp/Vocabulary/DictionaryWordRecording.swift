import Foundation

struct DictionaryWordRecording: Codable, Equatable {
    let createdAt: Date
    let duration: TimeInterval

    init(createdAt: Date = Date(), duration: TimeInterval) {
        self.createdAt = createdAt
        self.duration = max(duration, 0)
    }
}
