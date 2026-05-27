import SwiftUI

enum VocabularyCardImageStyle {
    case thumbnail
    case card

    var size: CGFloat {
        switch self {
        case .thumbnail: return 36
        case .card: return 120
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .thumbnail: return 8
        case .card: return PortTheme.radiusMD
        }
    }
}

struct VocabularyCardImageView: View {
    let cardID: UUID
    var style: VocabularyCardImageStyle = .thumbnail
    let image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if style == .card {
                ZStack {
                    PortTheme.surfaceMuted
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(PortTheme.textMuted)
                }
            }
        }
        .frame(width: style.size, height: style.size)
        .clipShape(RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous))
        .overlay {
            if image != nil {
                RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                    .stroke(PortTheme.cardBorder, lineWidth: 1)
            }
        }
    }
}
