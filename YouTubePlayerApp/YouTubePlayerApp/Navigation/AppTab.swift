import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case home
    case study
    case reader
    case video
    case dictionary

    var id: String { rawValue }

    var label: String {
        switch self {
        case .home: return "Home"
        case .study: return "Study"
        case .reader: return "Reader"
        case .video: return "Video"
        case .dictionary: return "Словарь"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house.fill"
        case .study: return "square.stack.fill"
        case .reader: return "book.fill"
        case .video: return "play.rectangle.fill"
        case .dictionary: return "character.book.closed.fill"
        }
    }
}
