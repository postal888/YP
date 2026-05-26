import SwiftUI

enum PortTheme {
    static let background = Color(red: 0.043, green: 0.071, blue: 0.125)       // #0b1220
    static let backgroundElevated = Color(red: 0.067, green: 0.094, blue: 0.153) // #111827
    static let surface = Color(red: 0.082, green: 0.122, blue: 0.196)           // #151f32
    static let surfaceMuted = Color(red: 0.059, green: 0.090, blue: 0.165)      // #0f172a
    static let surfaceInput = Color(red: 0.102, green: 0.141, blue: 0.220)      // #1a2438
    static let chipBackground = Color(red: 0.102, green: 0.141, blue: 0.220)

    static let textPrimary = Color(red: 0.898, green: 0.906, blue: 0.922)       // #e5e7eb
    static let textMuted = Color(red: 0.612, green: 0.639, blue: 0.686)         // #9ca3af
    static let textSubtle = Color(red: 0.820, green: 0.835, blue: 0.859)          // #d1d5db
    static let heading = Color(red: 0.976, green: 0.980, blue: 0.984)           // #f9fafb

    static let accent = Color(red: 0.133, green: 0.773, blue: 0.369)            // #22c55e
    static let accentHover = Color(red: 0.086, green: 0.639, blue: 0.290)       // #16a34a
    static let accentSoft = Color(red: 0.133, green: 0.773, blue: 0.369, opacity: 0.14)
    static let accentGlow = Color(red: 0.133, green: 0.773, blue: 0.369, opacity: 0.45)

    static let danger = Color(red: 0.937, green: 0.267, blue: 0.267)            // #ef4444
    static let successText = Color(red: 0.733, green: 0.969, blue: 0.816)       // #bbf7d0

    static let border = Color.white.opacity(0.12)
    static let cardBorder = Color(red: 0.580, green: 0.639, blue: 0.722, opacity: 0.16)

    static let radiusSM: CGFloat = 8
    static let radiusMD: CGFloat = 12
    static let radiusLG: CGFloat = 16
    static let radiusXL: CGFloat = 20
}

struct PortCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(PortTheme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: PortTheme.radiusLG, style: .continuous)
                    .stroke(PortTheme.cardBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: PortTheme.radiusLG, style: .continuous))
    }
}

struct PortPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(configuration.isPressed ? PortTheme.accentHover : PortTheme.accent)
            .clipShape(RoundedRectangle(cornerRadius: PortTheme.radiusMD, style: .continuous))
    }
}

struct PortChipButtonStyle: ButtonStyle {
    var isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.medium))
            .foregroundStyle(isSelected ? PortTheme.accent : PortTheme.textSubtle)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? PortTheme.accentSoft : PortTheme.chipBackground)
            .overlay(
                Capsule(style: .continuous)
                    .stroke(isSelected ? PortTheme.accentGlow : PortTheme.border, lineWidth: 1)
            )
            .clipShape(Capsule(style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

extension View {
    func portCard() -> some View {
        modifier(PortCardModifier())
    }
}
