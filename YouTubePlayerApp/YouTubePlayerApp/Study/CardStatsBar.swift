import SwiftUI

struct CardStatsBar: View {
    let stats: CardStudyStats
    let strings: AppStrings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(strings.quizShownCount(stats.quizShownCount), systemImage: "eye.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PortTheme.textSubtle)
                Spacer()
                if let percent = stats.accuracyPercent {
                    Text(strings.quizAccuracyPercent(percent))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PortTheme.accent)
                } else {
                    Text(strings.noQuizStatsYet)
                        .font(.caption)
                        .foregroundStyle(PortTheme.textMuted)
                }
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(PortTheme.surfaceMuted)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(PortTheme.accent)
                        .frame(width: geometry.size.width * stats.accuracyFraction)
                }
            }
            .frame(height: 8)
        }
        .padding(12)
        .background(PortTheme.surfaceInput)
        .clipShape(RoundedRectangle(cornerRadius: PortTheme.radiusMD, style: .continuous))
    }
}
