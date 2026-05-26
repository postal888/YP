import Foundation

struct AppErrorLogEntry: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let source: String
    let message: String

    var formattedLine: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return "[\(formatter.string(from: date))] [\(source)] \(message)"
    }
}

@MainActor
final class AppErrorLog: ObservableObject {
    @Published private(set) var entries: [AppErrorLogEntry] = []

    var combinedText: String {
        entries.map(\.formattedLine).joined(separator: "\n")
    }

    func add(source: String, message: String) {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        entries.append(AppErrorLogEntry(date: Date(), source: source, message: trimmed))
    }

    func clear() {
        entries.removeAll()
    }
}
