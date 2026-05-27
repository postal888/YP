import SwiftUI

struct PortSearchBar: View {
    @Binding var text: String
    var placeholder: String
    var onSubmit: () -> Void
    var onEditingChanged: ((Bool) -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(PortTheme.textMuted)

            TextField(placeholder, text: $text, onEditingChanged: { isEditing in
                onEditingChanged?(isEditing)
            }, onCommit: onSubmit)
                .foregroundStyle(PortTheme.textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(PortTheme.textMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(PortTheme.surfaceInput)
        .overlay(
            RoundedRectangle(cornerRadius: PortTheme.radiusMD, style: .continuous)
                .stroke(PortTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: PortTheme.radiusMD, style: .continuous))
    }
}
