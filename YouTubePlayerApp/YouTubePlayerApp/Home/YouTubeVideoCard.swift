import SwiftUI

struct YouTubeVideoCard: View {
    let result: YouTubeSearchResult
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                thumbnail
                meta
            }
        }
        .buttonStyle(.plain)
    }

    private var thumbnail: some View {
        ZStack(alignment: .bottomTrailing) {
            AsyncImage(url: result.thumbnailURL ?? result.thumbnailFallbackURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    thumbnailPlaceholder
                case .empty:
                    thumbnailPlaceholder
                        .overlay(ProgressView().tint(PortTheme.accent))
                @unknown default:
                    thumbnailPlaceholder
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(16 / 9, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: PortTheme.radiusMD, style: .continuous))

            if !result.durationText.isEmpty {
                Text(result.durationText)
                    .font(.caption2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.78))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .padding(8)
            }
        }
    }

    private var thumbnailPlaceholder: some View {
        RoundedRectangle(cornerRadius: PortTheme.radiusMD, style: .continuous)
            .fill(PortTheme.surfaceInput)
            .overlay {
                Image(systemName: "play.rectangle.fill")
                    .font(.title)
                    .foregroundStyle(PortTheme.textMuted)
            }
    }

    private var meta: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(result.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PortTheme.heading)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Text(result.channelTitle)
                .font(.caption)
                .foregroundStyle(PortTheme.textMuted)
                .lineLimit(1)

            if !result.viewCountText.isEmpty {
                Text(result.viewCountText)
                    .font(.caption2)
                    .foregroundStyle(PortTheme.textMuted.opacity(0.85))
                    .lineLimit(1)
            }
        }
    }
}

#if DEBUG
struct YouTubeVideoCard_Previews: PreviewProvider {
    static var previews: some View {
        YouTubeVideoCard(
            result: YouTubeSearchResult(
                id: "abc",
                videoID: "abc",
                title: "Aprenda português com vídeos do YouTube",
                channelTitle: "Canal de Idiomas",
                viewCountText: "1,2 млн просмотров",
                durationText: "12:34",
                thumbnailURL: nil
            ),
            onTap: {}
        )
        .padding()
        .background(PortTheme.background)
    }
}
#endif
