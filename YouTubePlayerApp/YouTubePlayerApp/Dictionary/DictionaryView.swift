import SwiftUI

@MainActor
struct DictionaryView: View {
    @EnvironmentObject private var vocabularyStore: VocabularyStore
    @EnvironmentObject private var appSettings: AppSettings
    @ObservedObject private var ttsService = WordTTSService.shared
    @ObservedObject private var recorderService = DictionaryAudioRecorderService.shared

    @State private var searchText = ""
    @State private var editingCard: VocabularyCard?
    @State private var recordingCard: VocabularyCard?
    @State private var renamingFolder: VocabularyFolderGroup?
    @State private var expandedFolderKeys: Set<String> = []

    private var filteredCards: [VocabularyCard] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return vocabularyStore.cards }
        return vocabularyStore.cards.filter { card in
            card.source.lowercased().contains(query)
                || card.translation.lowercased().contains(query)
                || (card.example?.lowercased().contains(query) ?? false)
                || vocabularyStore.folderDisplayName(for: card.resolvedFolderKey).lowercased().contains(query)
        }
    }

    private var folders: [VocabularyFolderGroup] {
        vocabularyStore.groupedFolders(from: filteredCards)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                header

                if vocabularyStore.cards.isEmpty {
                    emptyState
                } else {
                    PortSearchBar(
                        text: $searchText,
                        placeholder: "Поиск в словаре…",
                        onSubmit: {}
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)

                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(folders) { folder in
                                folderSection(folder)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                }
            }
            .background(PortTheme.background.ignoresSafeArea())
            .navigationBarHidden(true)
            .sheet(item: $editingCard) { card in
                VocabularyCardEditSheet(card: card) { source, translation, example in
                    vocabularyStore.update(card, source: source, translation: translation, example: example)
                }
            }
            .sheet(item: $recordingCard) { card in
                DictionaryWordRecorderPanel(card: card, vocabularyStore: vocabularyStore)
            }
            .sheet(item: $renamingFolder) { folder in
                VocabularyFolderRenameSheet(
                    folderKey: folder.key,
                    currentTitle: folder.title
                ) { newTitle in
                    vocabularyStore.renameFolder(key: folder.key, title: newTitle)
                }
            }
            .onAppear {
                expandedFolderKeys = Set(folders.map(\.key))
            }
            .onChange(of: vocabularyStore.cards.count) { _ in
                for folder in folders where !expandedFolderKeys.contains(folder.key) {
                    expandedFolderKeys.insert(folder.key)
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.stack.fill")
                    .font(.title2)
                    .foregroundStyle(PortTheme.accent)
                Text("Словарь")
                    .font(.title2.bold())
                    .foregroundStyle(PortTheme.heading)
            }

            Text("\(vocabularyStore.cards.count) карточек · \(folders.count) папок")
                .font(.subheadline)
                .foregroundStyle(PortTheme.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    private func folderSection(_ folder: VocabularyFolderGroup) -> some View {
        VStack(spacing: 8) {
            folderHeader(folder)

            if expandedFolderKeys.contains(folder.key) {
                ForEach(folder.cards) { card in
                    cardRow(card)
                }
            }
        }
    }

    private func folderHeader(_ folder: VocabularyFolderGroup) -> some View {
        HStack(spacing: 10) {
            Button {
                toggleFolder(folder.key)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: expandedFolderKeys.contains(folder.key) ? "folder.fill" : "folder")
                        .foregroundStyle(folder.isYouTube ? PortTheme.accent : PortTheme.textSubtle)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(folder.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(PortTheme.heading)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Text("\(folder.cards.count) слов")
                            .font(.caption)
                            .foregroundStyle(PortTheme.textMuted)
                    }

                    Spacer()

                    Image(systemName: expandedFolderKeys.contains(folder.key) ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PortTheme.textMuted)
                }
            }
            .buttonStyle(.plain)

            Button {
                renamingFolder = folder
            } label: {
                Image(systemName: "pencil.circle")
                    .font(.body)
                    .foregroundStyle(PortTheme.accent)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Переименовать папку")
        }
        .padding(12)
        .portCard()
    }

    private func toggleFolder(_ key: String) {
        if expandedFolderKeys.contains(key) {
            expandedFolderKeys.remove(key)
        } else {
            expandedFolderKeys.insert(key)
        }
    }

    private func cardRow(_ card: VocabularyCard) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                editingCard = card
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(card.source)
                            .font(.headline)
                            .foregroundStyle(PortTheme.heading)
                        Text("—")
                            .foregroundStyle(PortTheme.textMuted)
                        Text(card.translation)
                            .font(.body)
                            .foregroundStyle(PortTheme.textSubtle)
                    }

                    if let example = card.example, !example.isEmpty {
                        Text(example)
                            .font(.caption)
                            .foregroundStyle(PortTheme.textMuted)
                            .lineLimit(2)
                    }

                    HStack(spacing: 8) {
                        Text(card.sourceLanguage.uppercased())
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(PortTheme.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(PortTheme.accentSoft)
                            .clipShape(Capsule())

                        if vocabularyStore.hasRecording(for: card.id) {
                            Label("есть запись", systemImage: "mic.fill")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(PortTheme.accent)
                        }

                        Spacer()

                        Text(card.createdAt, style: .date)
                            .font(.caption2)
                            .foregroundStyle(PortTheme.textMuted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Divider().overlay(PortTheme.border)

            HStack(spacing: 8) {
                cardActionButton(
                    title: "Диктофон",
                    systemImage: vocabularyStore.hasRecording(for: card.id) ? "mic.fill" : "mic",
                    tint: vocabularyStore.hasRecording(for: card.id) ? PortTheme.accent : PortTheme.textSubtle
                ) {
                    recordingCard = card
                }
                .disabled(recorderService.isRecording && recorderService.recordingWordID != card.id)

                cardActionButton(
                    title: "Озвучить",
                    systemImage: ttsService.playingCardID == card.id ? "speaker.wave.2.fill" : "speaker.wave.2",
                    tint: PortTheme.accent
                ) {
                    ttsService.speak(
                        text: card.source,
                        languageCode: card.sourceLanguage,
                        cardID: card.id,
                        settings: appSettings
                    )
                }
                .disabled(ttsService.isPlaying && ttsService.playingCardID != card.id)

                Spacer(minLength: 0)

                cardActionButton(
                    title: "Удалить",
                    systemImage: "trash",
                    tint: PortTheme.danger
                ) {
                    vocabularyStore.remove(card)
                }
            }
        }
        .padding(12)
        .portCard()
    }

    private func cardActionButton(
        title: String,
        systemImage: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.body.weight(.semibold))
                Text(title)
                    .font(.caption2.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(tint)
            .frame(minWidth: 64, minHeight: 44)
            .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "character.book.closed")
                .font(.system(size: 42))
                .foregroundStyle(PortTheme.textMuted)
            Text("Словарь пуст")
                .font(.headline)
                .foregroundStyle(PortTheme.heading)
            Text("Нажимайте на слова в PDF или субтитрах и сохраняйте перевод.")
                .font(.subheadline)
                .foregroundStyle(PortTheme.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }
}

#if DEBUG
struct DictionaryView_Previews: PreviewProvider {
    static var previews: some View {
        DictionaryView()
            .environmentObject(VocabularyStore())
            .environmentObject(AppSettings())
    }
}
#endif
