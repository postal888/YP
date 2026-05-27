import SwiftUI

@MainActor
struct DictionaryView: View {
    @EnvironmentObject private var vocabularyStore: VocabularyStore
    @EnvironmentObject private var appSettings: AppSettings
    @ObservedObject private var ttsService = WordTTSService.shared
    @ObservedObject private var recorderService = DictionaryAudioRecorderService.shared

    @State private var searchText = ""
    @State private var editingCard: VocabularyCard?
    @State private var recordingSession: DictionaryRecordingSession?
    @StateObject private var folderRecordingController = DictionaryFolderRecordingController()
    @State private var renamingFolder: VocabularyFolderGroup?
    @State private var expandedFolderKeys: Set<String> = []
    @State private var csvShareItem: ShareableFile?
    @State private var showExportError = false
    @State private var exportErrorMessage = ""
    @State private var isSelectionMode = false
    @State private var selectedCardIDs: Set<UUID> = []
    @State private var showBulkDeleteConfirmation = false
    @State private var showRecordingsLibrary = false

    private var strings: AppStrings { appSettings.strings }

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

    private var selectedCards: [VocabularyCard] {
        vocabularyStore.cards(withIDs: selectedCardIDs)
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
                        placeholder: strings.searchDictionary,
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
                        .padding(.bottom, bottomScrollPadding)
                    }
                }
            }
            .background(PortTheme.background.ignoresSafeArea())
            .navigationBarHidden(true)
            .safeAreaInset(edge: .bottom) {
                bottomInsetContent
            }
            .sheet(item: $editingCard) { card in
                VocabularyCardEditSheet(card: card) { source, translation, example in
                    vocabularyStore.update(card, source: source, translation: translation, example: example)
                }
            }
            .sheet(item: $recordingSession) { session in
                DictionaryWordRecorderPanel(
                    session: session,
                    vocabularyStore: vocabularyStore,
                    appSettings: appSettings
                )
            }
            .sheet(isPresented: folderRecorderSheetBinding) {
                if let viewModel = folderRecordingController.viewModel {
                    DictionaryFolderRecorderPanel(
                        viewModel: viewModel,
                        onMinimize: { folderRecordingController.minimize() },
                        onClose: { folderRecordingController.dismiss() }
                    )
                    .environmentObject(appSettings)
                }
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
                selectedCardIDs = selectedCardIDs.intersection(Set(vocabularyStore.cards.map(\.id)))
                for folder in folders where !expandedFolderKeys.contains(folder.key) {
                    expandedFolderKeys.insert(folder.key)
                }
            }
            .sheet(item: $csvShareItem) { item in
                ShareSheet(items: [item.url])
            }
            .sheet(isPresented: $showRecordingsLibrary) {
                DictionaryRecordingsLibraryView()
            }
            .alert(strings.exportFailed, isPresented: $showExportError) {
                Button(strings.ok, role: .cancel) {}
            } message: {
                Text(exportErrorMessage)
            }
            .confirmationDialog(
                strings.deleteSelectedTitle,
                isPresented: $showBulkDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button(strings.deleteSelected(selectedCardIDs.count), role: .destructive) {
                    deleteSelectedCards()
                }
                Button(strings.cancel, role: .cancel) {}
            } message: {
                Text(strings.deleteSelectedMessage)
            }
        }
        .navigationViewStyle(.stack)
    }

    private var bottomScrollPadding: CGFloat {
        var padding: CGFloat = 24
        if folderRecordingController.isMinimized {
            padding = 96
        }
        if isSelectionMode && !selectedCardIDs.isEmpty {
            padding += 72
        }
        return padding
    }

    private var folderRecorderSheetBinding: Binding<Bool> {
        Binding(
            get: { folderRecordingController.isSheetPresented },
            set: { presented in
                if !presented, folderRecordingController.isActive {
                    folderRecordingController.minimize()
                }
            }
        )
    }

    @ViewBuilder
    private var bottomInsetContent: some View {
        VStack(spacing: 0) {
            if folderRecordingController.isMinimized,
               let viewModel = folderRecordingController.viewModel {
                DictionaryFolderRecordingMiniBar(
                    viewModel: viewModel,
                    onExpand: { folderRecordingController.expand() }
                )
                .environmentObject(appSettings)
            }

            if isSelectionMode && !selectedCardIDs.isEmpty {
                selectionToolbar
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Image(systemName: "rectangle.stack.fill")
                            .font(.title2)
                            .foregroundStyle(PortTheme.accent)
                        Text(strings.dictionaryTitle)
                            .font(.title2.bold())
                            .foregroundStyle(PortTheme.heading)
                    }

                    Text(headerSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(PortTheme.textMuted)
                }

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    if !vocabularyStore.cards.isEmpty && !isSelectionMode {
                        Button {
                            showRecordingsLibrary = true
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "waveform")
                                    .font(.body.weight(.semibold))
                                Text(strings.recordings)
                                    .font(.caption2.weight(.medium))
                            }
                            .foregroundStyle(PortTheme.accent)
                            .frame(minWidth: 52, minHeight: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(strings.recordingsLibraryTitle)
                    }

                    Button {
                        toggleSelectionMode()
                    } label: {
                        Text(isSelectionMode ? strings.done : strings.select)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(isSelectionMode ? PortTheme.accent : PortTheme.textSubtle)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(PortTheme.surfaceInput)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(vocabularyStore.cards.isEmpty)

                    if !vocabularyStore.cards.isEmpty && !isSelectionMode {
                        Button(action: { exportCSV(cards: filteredCards) }) {
                            VStack(spacing: 4) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.body.weight(.semibold))
                                Text(strings.exportCSV)
                                    .font(.caption2.weight(.medium))
                            }
                            .foregroundStyle(PortTheme.accent)
                            .frame(minWidth: 52, minHeight: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(strings.exportCSV)
                    }
                }
            }

            if isSelectionMode {
                HStack(spacing: 8) {
                    Button(strings.all) {
                        selectedCardIDs = Set(filteredCards.map(\.id))
                    }
                    .buttonStyle(PortChipButtonStyle(isSelected: false))

                    Button(strings.reset) {
                        selectedCardIDs.removeAll()
                    }
                    .buttonStyle(PortChipButtonStyle(isSelected: false))

                    if !selectedCardIDs.isEmpty {
                        Text(strings.selectedCount(selectedCardIDs.count))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PortTheme.accent)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    private var selectionToolbar: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(strings.selectedCount(selectedCardIDs.count))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PortTheme.heading)
                Text(strings.exportDeleteHint)
                    .font(.caption)
                    .foregroundStyle(PortTheme.textMuted)
            }

            Spacer()

            Button {
                exportCSV(cards: selectedCards)
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(PortTheme.accent)
            .accessibilityLabel(strings.exportCSV)

            Button {
                showBulkDeleteConfirmation = true
            } label: {
                Image(systemName: "trash")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(PortTheme.danger)
            .accessibilityLabel(strings.delete)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(PortTheme.surface)
        .overlay(alignment: .top) {
            Divider().overlay(PortTheme.border)
        }
    }

    private var headerSubtitle: String {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            return strings.cardsCount(vocabularyStore.cards.count, folders: folders.count)
        }
        return strings.filteredCardsCount(filteredCards.count, total: vocabularyStore.cards.count, folders: folders.count)
    }

    private func toggleSelectionMode() {
        if isSelectionMode {
            isSelectionMode = false
            selectedCardIDs.removeAll()
        } else {
            isSelectionMode = true
        }
    }

    private func exportCSV(cards: [VocabularyCard]) {
        do {
            let url = try DictionaryCSVExportService.shared.exportCSV(
                cards: cards,
                folderName: { vocabularyStore.folderDisplayName(for: $0.resolvedFolderKey) },
                hasRecording: { vocabularyStore.hasRecording(for: $0) }
            )
            csvShareItem = ShareableFile(url: url)
        } catch {
            exportErrorMessage = error.localizedDescription
            showExportError = true
        }
    }

    private func deleteSelectedCards() {
        vocabularyStore.remove(ids: selectedCardIDs)
        selectedCardIDs.removeAll()
        isSelectionMode = false
    }

    private func toggleSelection(for card: VocabularyCard) {
        if selectedCardIDs.contains(card.id) {
            selectedCardIDs.remove(card.id)
        } else {
            selectedCardIDs.insert(card.id)
        }
    }

    private func openRecorder(for card: VocabularyCard) {
        let playbackCards = playbackCardsForRecording(anchor: card)
        recordingSession = DictionaryRecordingSession(card: card, playbackCards: playbackCards)
    }

    private func playbackCardsForRecording(anchor: VocabularyCard) -> [VocabularyCard] {
        if isSelectionMode, !selectedCardIDs.isEmpty {
            var ids = selectedCardIDs
            ids.insert(anchor.id)
            return vocabularyStore.cards(withIDs: ids)
                .sorted { lhs, rhs in
                    if lhs.id == anchor.id { return true }
                    if rhs.id == anchor.id { return false }
                    return lhs.source.localizedCaseInsensitiveCompare(rhs.source) == .orderedAscending
                }
        }
        return [anchor]
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
                        HStack(spacing: 8) {
                            Text(strings.wordsCount(folder.cards.count))
                                .font(.caption)
                                .foregroundStyle(PortTheme.textMuted)
                            if vocabularyStore.hasFolderRecording(for: folder.key) {
                                Label(strings.hasRecording, systemImage: "mic.fill")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(PortTheme.accent)
                            }
                        }
                    }

                    Spacer()

                    Image(systemName: expandedFolderKeys.contains(folder.key) ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PortTheme.textMuted)
                }
            }
            .buttonStyle(.plain)

            if isSelectionMode {
                Button {
                    selectAll(in: folder)
                } label: {
                    Text(strings.all)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PortTheme.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(PortTheme.surfaceInput)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            Button {
                speakFolder(folder)
            } label: {
                Image(systemName: "speaker.wave.2")
                    .font(.body)
                    .foregroundStyle(PortTheme.accent)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(strings.speakFolder)

            Button {
                openFolderRecorder(for: folder)
            } label: {
                Image(systemName: vocabularyStore.hasFolderRecording(for: folder.key) ? "mic.fill" : "mic")
                    .font(.body)
                    .foregroundStyle(vocabularyStore.hasFolderRecording(for: folder.key) ? PortTheme.accent : PortTheme.textSubtle)
            }
            .buttonStyle(.plain)
            .disabled(recorderService.isRecording && recorderService.recordingFolderKey != folder.key)
            .accessibilityLabel(strings.folderDictaphone)

            Button {
                renamingFolder = folder
            } label: {
                Image(systemName: "pencil.circle")
                    .font(.body)
                    .foregroundStyle(PortTheme.accent)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(strings.renameFolder)
        }
        .padding(12)
        .portCard()
    }

    private func selectAll(in folder: VocabularyFolderGroup) {
        for card in folder.cards {
            selectedCardIDs.insert(card.id)
        }
    }

    private func cardsForFolderPlayback(_ folder: VocabularyFolderGroup) -> [VocabularyCard] {
        let selectedInFolder = folder.cards.filter { selectedCardIDs.contains($0.id) }
        if isSelectionMode, !selectedInFolder.isEmpty {
            return selectedInFolder
        }
        return folder.cards
    }

    private func speakFolder(_ folder: VocabularyFolderGroup) {
        let cards = cardsForFolderPlayback(folder)
        guard !cards.isEmpty else { return }
        let entries = DictionaryWordRecordingViewModel.ttsEntries(for: cards)
        ttsService.speakSequence(entries, settings: appSettings)
    }

    private func openFolderRecorder(for folder: VocabularyFolderGroup) {
        let playbackCards = cardsForFolderPlayback(folder)
        folderRecordingController.present(
            session: DictionaryFolderRecordingSession(
                folder: folder,
                playbackCards: playbackCards
            ),
            vocabularyStore: vocabularyStore,
            appSettings: appSettings
        )
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
            HStack(alignment: .top, spacing: 10) {
                if isSelectionMode {
                    Button {
                        toggleSelection(for: card)
                    } label: {
                        Image(systemName: selectedCardIDs.contains(card.id) ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(selectedCardIDs.contains(card.id) ? PortTheme.accent : PortTheme.textMuted)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    if isSelectionMode {
                        toggleSelection(for: card)
                    } else {
                        editingCard = card
                    }
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        if vocabularyStore.hasImage(for: card.id) {
                            VocabularyCardImageView(
                                cardID: card.id,
                                style: .thumbnail,
                                image: vocabularyStore.image(for: card.id)
                            )
                        }

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
                                Label(strings.hasRecording, systemImage: "mic.fill")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(PortTheme.accent)
                            }

                            Spacer()

                            Text(card.createdAt, style: .date)
                                .font(.caption2)
                                .foregroundStyle(PortTheme.textMuted)
                        }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }

            if !isSelectionMode {
                Divider().overlay(PortTheme.border)

                HStack(spacing: 8) {
                    cardActionButton(
                        title: strings.dictaphone,
                        systemImage: vocabularyStore.hasRecording(for: card.id) ? "mic.fill" : "mic",
                        tint: vocabularyStore.hasRecording(for: card.id) ? PortTheme.accent : PortTheme.textSubtle
                    ) {
                        openRecorder(for: card)
                    }
                    .disabled(recorderService.isRecording && recorderService.recordingWordID != card.id)

                    cardActionButton(
                        title: strings.speak,
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
                        title: strings.delete,
                        systemImage: "trash",
                        tint: PortTheme.danger
                    ) {
                        vocabularyStore.remove(card)
                    }
                }
            }
        }
        .padding(12)
        .portCard()
        .overlay {
            if isSelectionMode && selectedCardIDs.contains(card.id) {
                RoundedRectangle(cornerRadius: PortTheme.radiusLG, style: .continuous)
                    .stroke(PortTheme.accentGlow, lineWidth: 1.5)
            }
        }
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
            Text(strings.dictionaryEmpty)
                .font(.headline)
                .foregroundStyle(PortTheme.heading)
            Text(strings.dictionaryEmptyHint)
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
