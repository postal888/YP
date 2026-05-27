import SwiftUI

@MainActor
struct VocabularyFolderRenameSheet: View {
    let folderKey: String
    let currentTitle: String
    let onSave: (String) -> Void

    @Environment(\.presentationMode) private var presentationMode
    @State private var title: String

    init(folderKey: String, currentTitle: String, onSave: @escaping (String) -> Void) {
        self.folderKey = folderKey
        self.currentTitle = currentTitle
        self.onSave = onSave
        _title = State(initialValue: currentTitle)
    }

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Название папки")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PortTheme.textMuted)

                TextField("Название папки", text: $title)
                    .textInputAutocapitalization(.sentences)
                    .padding(12)
                    .background(PortTheme.surfaceInput)
                    .clipShape(RoundedRectangle(cornerRadius: PortTheme.radiusMD, style: .continuous))
                    .foregroundStyle(PortTheme.heading)

                if folderKey.hasPrefix("yt:") {
                    Text("Слова из YouTube-ролика собираются в эту папку.")
                        .font(.caption)
                        .foregroundStyle(PortTheme.textMuted)
                }

                Spacer()
            }
            .padding(16)
            .background(PortTheme.background.ignoresSafeArea())
            .navigationTitle("Переименовать")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        onSave(title)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

#if DEBUG
struct VocabularyFolderRenameSheet_Previews: PreviewProvider {
    static var previews: some View {
        VocabularyFolderRenameSheet(folderKey: "yt:abc", currentTitle: "Урок 1") { _ in }
    }
}
#endif
