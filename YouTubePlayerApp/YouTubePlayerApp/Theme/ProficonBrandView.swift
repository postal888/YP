import SwiftUI

struct ProficonBrandView: View {
    enum Style {
        case compact
        case full
    }

    var style: Style = .compact
    var font: Font = .title2.bold()
    var showsLogo: Bool = false
    var logoSize: CGFloat = 36

    var body: some View {
        HStack(spacing: showsLogo ? 10 : 0) {
            if showsLogo {
                Image("ProficonLogo")
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: logoSize, height: logoSize)
                    .clipShape(RoundedRectangle(cornerRadius: logoSize * 0.22, style: .continuous))
            }

            Group {
                switch style {
                case .compact:
                    compactBrand
                case .full:
                    fullBrand
                }
            }
            .font(font)
        }
    }

    private var compactBrand: some View {
        HStack(spacing: 0) {
            highlighted("Pro")
            normal("fi")
            highlighted("con")
        }
    }

    private var fullBrand: some View {
        HStack(spacing: 0) {
            highlighted("Pro")
            normal("ficiência ")
            highlighted("Con")
            normal("quistada")
        }
    }

    private func highlighted(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(PortTheme.accent)
            .fontWeight(.bold)
    }

    private func normal(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(PortTheme.heading)
    }
}

#if DEBUG
struct ProficonBrandView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(alignment: .leading, spacing: 16) {
            ProficonBrandView(style: .compact)
            ProficonBrandView(style: .full, font: .title3.bold())
        }
        .padding()
        .background(PortTheme.background)
    }
}
#endif
