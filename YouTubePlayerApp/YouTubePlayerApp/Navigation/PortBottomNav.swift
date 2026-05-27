import SwiftUI

struct PortBottomNav: View {
    @Binding var selected: AppTab
    @EnvironmentObject private var appSettings: AppSettings

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 2) {
                ForEach(AppTab.allCases) { tab in
                    Button {
                        selected = tab
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: tab.systemImage)
                                .font(.system(size: 18, weight: .semibold))
                            Text(tab.label(strings: appSettings.strings))
                                .font(.system(size: 10, weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .foregroundStyle(selected == tab ? PortTheme.accent : PortTheme.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(selected == tab ? PortTheme.accentSoft : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
        .background(
            PortTheme.background
                .ignoresSafeArea(edges: .bottom)
                .overlay(alignment: .top) {
                    Divider().overlay(PortTheme.border)
                }
        )
    }
}

#if DEBUG
struct PortBottomNav_Previews: PreviewProvider {
    static var previews: some View {
        PortBottomNav(selected: .constant(.home))
            .environmentObject(AppSettings())
            .background(PortTheme.background)
    }
}
#endif
