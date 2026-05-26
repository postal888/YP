import SwiftUI

struct RecentTranslationsView: View {
    let entries: [WordTranslationEntry]
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Последние переводы")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PortTheme.textSubtle)
                Spacer()
                if !entries.isEmpty {
                    Button("Очистить", action: onClear)
                        .font(.caption)
                        .foregroundStyle(PortTheme.accent)
                }
            }

            if entries.isEmpty {
                Text("Нажмите на слово в субтитрах")
                    .font(.caption)
                    .foregroundStyle(PortTheme.textMuted)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(entries.prefix(8)) { entry in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(entry.source)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(PortTheme.heading)
                            Text("—")
                                .foregroundStyle(PortTheme.textMuted)
                            Text(entry.translation)
                                .font(.subheadline)
                                .foregroundStyle(PortTheme.textMuted)
                        }
                    }
                }
            }
        }
        .padding(12)
        .portCard()
    }
}
