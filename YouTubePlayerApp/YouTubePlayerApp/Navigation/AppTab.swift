import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case home
    case study
    case reader
    case video
    case dictionary
    case account

    var id: String { rawValue }

    func label(strings: AppStrings) -> String {
        switch self {
        case .home: return strings.tabHome
        case .study: return strings.tabStudy
        case .reader: return strings.tabReader
        case .video: return strings.tabVideo
        case .dictionary: return strings.tabDictionary
        case .account: return strings.tabAccount
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house.fill"
        case .study: return "square.stack.fill"
        case .reader: return "book.fill"
        case .video: return "play.rectangle.fill"
        case .dictionary: return "character.book.closed.fill"
        case .account: return "person.crop.circle.fill"
        }
    }
}
