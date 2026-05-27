import SwiftUI

@MainActor
struct VocabularyCardEditSheet: View {
    let card: VocabularyCard
    let onSave: (String, String, String?) -> Void

    @EnvironmentObject private var vocabularyStore: VocabularyStore
    @EnvironmentObject private var learningStats: LearningStatsStore
    @EnvironmentObject private var appSettings: AppSettings
    @Environment(\.presentationMode) private var presentationMode

    @State private var source: String
    @State private var translation: String
    @State private var example: String
    @State private var showImagePicker = false
    @State private var previewImage: UIImage?

    private var strings: AppStrings { appSettings.strings }

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
                    cardEditorSection
                    CardStatsBar(stats: learningStats.stats(for: card.id), strings: strings)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(strings.dictaphone)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PortTheme.textMuted)

                        DictionaryWordRecorderContent(
                            card: card,
                            vocabularyStore: vocabularyStore,
                            playbackCards: [],
                            appSettings: appSettings,
                            showsWordHeader: false
                        )
                    }
                }
                .padding(16)
            }
            .background(PortTheme.background.ignoresSafeArea())
            .navigationTitle(strings.editCard)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(strings.cancel) {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(strings.done) {
                        let trimmedExample = example.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(source, translation, trimmedExample.isEmpty ? nil : trimmedExample)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || translation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePickerView { image in
                    previewImage = image
                    try? vocabularyStore.setImage(image, for: card.id)
                }
            }
            .onAppear {
                previewImage = vocabularyStore.image(for: card.id)
            }
        }
        .navigationViewStyle(.stack)
    }

    private var cardEditorSection: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                field(title: strings.wordLabel, text: $source)
                field(title: strings.translationLabel, text: $translation)
                field(title: strings.exampleLabel, text: $example)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 10) {
                VocabularyCardImageView(
                    cardID: card.id,
                    style: .card,
                    image: previewImage
                )

                Button {
                    showImagePicker = true
                } label: {
                    Label(strings.addImage, systemImage: "photo.on.rectangle")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(DictionaryRecorderSecondaryButtonStyle())

                if previewImage != nil {
                    Button(role: .destructive) {
                        previewImage = nil
                        vocabularyStore.clearImage(for: card.id)
                    } label: {
                        Label(strings.removeImage, systemImage: "trash")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(DictionaryRecorderSecondaryButtonStyle())
                }
            }
            .frame(width: 132)
        }
        .padding(16)
        .frame(minHeight: 168)
        .portCard()
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
            card: VocabularyCard(source: "obrigado", translation: "thank you", sourceLanguage: "pt")
        ) { _, _, _ in }
        .environmentObject(VocabularyStore())
        .environmentObject(LearningStatsStore())
        .environmentObject(AppSettings())
    }
}
#endif
