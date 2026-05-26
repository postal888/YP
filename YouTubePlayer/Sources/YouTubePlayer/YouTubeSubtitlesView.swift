import SwiftUI

public struct YouTubeSubtitlesView: View {
    public let lines: [YouTubeSubtitleLine]
    public let playbackSec: Double?
    public let onLineTap: ((YouTubeSubtitleLine) -> Void)?

    @State private var userScrollUntil: Date = .distantPast

    public init(
        lines: [YouTubeSubtitleLine],
        playbackSec: Double?,
        onLineTap: ((YouTubeSubtitleLine) -> Void)? = nil
    ) {
        self.lines = lines
        self.playbackSec = playbackSec
        self.onLineTap = onLineTap
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(lines) { line in
                        subtitleRow(for: line)
                            .id(line.id)
                    }
                }
                .padding(.vertical, 4)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 8).onChanged { _ in
                    userScrollUntil = Date().addingTimeInterval(4)
                }
            )
            .onChange(of: activeLineID) { newID in
                guard let newID,
                      Date() >= userScrollUntil else {
                    return
                }
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(newID, anchor: .center)
                }
            }
        }
    }

    private var activeLineID: String? {
        guard let playbackSec else { return nil }
        if let current = lines.first(where: { playbackSec >= $0.startSec && playbackSec < $0.endSec }) {
            return current.id
        }
        return lines.last(where: { playbackSec >= $0.endSec })?.id
    }

    @ViewBuilder
    private func subtitleRow(for line: YouTubeSubtitleLine) -> some View {
        let tone = youtubeSubtitleTone(for: line, playbackSec: playbackSec)

        Button {
            onLineTap?(line)
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Text(formatSubtitleClock(line.startSec))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(timeColor(for: tone))
                    .frame(width: 42, alignment: .leading)

                Text(line.text)
                    .font(.body)
                    .foregroundStyle(textColor(for: tone))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(backgroundColor(for: tone))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(formatSubtitleClock(line.startSec)). \(line.text)")
    }

    private func timeColor(for tone: YouTubeSubtitleTone) -> Color {
        switch tone {
        case .future: return .secondary
        case .current: return .accentColor
        case .spoken: return .secondary.opacity(0.8)
        }
    }

    private func textColor(for tone: YouTubeSubtitleTone) -> Color {
        switch tone {
        case .future: return .primary.opacity(0.72)
        case .current: return .primary
        case .spoken: return .secondary
        }
    }

    private func backgroundColor(for tone: YouTubeSubtitleTone) -> Color {
        switch tone {
        case .future: return Color(.tertiarySystemBackground)
        case .current: return Color.accentColor.opacity(0.14)
        case .spoken: return Color(.secondarySystemBackground).opacity(0.55)
        }
    }
}

#if DEBUG
struct YouTubeSubtitlesView_Previews: PreviewProvider {
    static var previews: some View {
        YouTubeSubtitlesView(
            lines: [
                YouTubeSubtitleLine(id: "1", text: "Olá, como você está?", startSec: 0, endSec: 3),
                YouTubeSubtitleLine(id: "2", text: "Hoje vamos aprender português.", startSec: 3, endSec: 7)
            ],
            playbackSec: 3.5
        )
        .padding()
    }
}
#endif
