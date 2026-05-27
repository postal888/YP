import SwiftUI

@MainActor
struct VocabularyCardEditSheet: View {
    let card: VocabularyCard
    let onSave: (String, String, String?) -> Void

    @EnvironmentObject private var vocabularyStore: VocabularyStore
    @Environment(\.presentationMode) private var presentationMode

    @State private var source: String
    @State private var translation: String
    @State private var example: String

    init(card: VocabularyCard, onSave: @escaping (String, String, String?) -> Void) {
        self.card = card
        self.onSave = onSave
        _source = State(initialValue: card.source)
        _translation = State(initialValue: card.translation)
        _example = State(initialValue: card.example ?? "")
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    field(title: "Слово", text: $source)
                    field(title: "Перевод", text: $translation)
                    field(title: "Пример", text: $example)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Диктофон")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PortTheme.textMuted)

                        DictionaryWordRecorderContent(
                            card: card,
                            vocabularyStore: vocabularyStore,
                            showsWordHeader: false
                        )
                    }
                }
                .padding(16)
            }
            .background(PortTheme.background.ignoresSafeArea())
            .navigationTitle("Редактировать")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        let trimmedExample = example.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(source, translation, trimmedExample.isEmpty ? nil : trimmedExample)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || translation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private func field(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(PortTheme.textMuted)
            TextField(title, text: text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(12)
                .background(PortTheme.surfaceInput)
                .clipShape(RoundedRectangle(cornerRadius: PortTheme.radiusMD, style: .continuous))
                .foregroundStyle(PortTheme.heading)
        }
    }
}

#if DEBUG
struct VocabularyCardEditSheet_Previews: PreviewProvider {
    static var previews: some View {
        VocabularyCardEditSheet(
            card: VocabularyCard(source: "obrigado", translation: "спасибо", sourceLanguage: "pt")
        ) { _, _, _ in }
        .environmentObject(VocabularyStore())
    }
}
#endif
