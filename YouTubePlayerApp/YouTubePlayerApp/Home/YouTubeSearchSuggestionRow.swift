import SwiftUI

struct YouTubeSearchSuggestionRow: View {
    let item: YouTubeSearchSuggestionItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                leadingIcon

                VStack(alignment: .leading, spacing: 3) {
                    Text(primaryText)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(PortTheme.heading)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if let subtitle = secondaryText, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(PortTheme.textMuted)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                trailingIcon
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var leadingIcon: some View {
        switch item {
        case .query:
            Image(systemName: "magnifyingglass")
                .font(.body)
                .foregroundStyle(PortTheme.textMuted)
                .frame(width: 40, height: 40)
                .background(PortTheme.surfaceInput)
                .clipShape(Circle())

        case .video(let result):
            thumbnail(url: result.thumbnailURL ?? result.thumbnailFallbackURL, fallback: "play.rectangle.fill")

        case .channel(let result):
            thumbnail(url: result.thumbnailURL, fallback: "person.crop.circle.fill")
        }
    }

    @ViewBuilder
    private func thumbnail(url: URL?, fallback: String) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            default:
                Image(systemName: fallback)
                    .foregroundStyle(PortTheme.accent)
            }
        }
        .frame(width: 40, height: 40)
        .background(PortTheme.surfaceInput)
        .clipShape(Circle())
        .clipped()
    }

    @ViewBuilder
    private var trailingIcon: some View {
        switch item {
        case .query:
            Image(systemName: "arrow.up.left")
                .font(.caption.weight(.semibold))
                .foregroundStyle(PortTheme.textMuted)
        case .video:
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(PortTheme.textMuted)
        case .channel:
            Image(systemName: "plus")
                .font(.caption.weight(.bold))
                .foregroundStyle(PortTheme.accent)
                .frame(width: 28, height: 28)
                .background(PortTheme.accentSoft)
                .clipShape(Circle())
        }
    }

    private var primaryText: String {
        switch item {
        case .query(let text):
            return text
        case .video(let result):
            return result.title
        case .channel(let result):
            return result.title
        }
    }

    private var secondaryText: String? {
        switch item {
        case .query:
            return "Подсказка запроса"
        case .video(let result):
            var parts = [result.channelTitle]
            if !result.viewCountText.isEmpty { parts.append(result.viewCountText) }
            if !result.durationText.isEmpty { parts.append(result.durationText) }
            return parts.joined(separator: " · ")
        case .channel(let result):
            var parts: [String] = []
            if !result.subscriberCountText.isEmpty { parts.append(result.subscriberCountText) }
            if !result.videoCountText.isEmpty { parts.append(result.videoCountText) }
            return parts.isEmpty ? "YouTube канал" : parts.joined(separator: " · ")
        }
    }
}
