import SwiftUI

@MainActor
struct DictionaryRecordingsLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var vocabularyStore: VocabularyStore
    @EnvironmentObject private var appSettings: AppSettings
    @ObservedObject private var playerService = DictionaryAudioPlayerService.shared

    @State private var selectedItemID: String?
    @State private var playbackError: String?

    private var strings: AppStrings { appSettings.strings }

    private var items: [DictionaryRecordingListItem] {
        vocabularyStore.allRecordingItems()
    }

    private var selectedItem: DictionaryRecordingListItem? {
        if let selectedItemID, let item = items.first(where: { $0.id == selectedItemID }) {
            return item
        }
        return items.first
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if items.isEmpty {
                    emptyState
                } else {
                    recordingsList
                    Divider().overlay(PortTheme.border)
                    transportPanel
                }
            }
            .background(PortTheme.background.ignoresSafeArea())
            .navigationTitle(strings.recordingsLibraryTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(strings.close) { dismiss() }
                }
            }
            .onAppear {
                if selectedItemID == nil {
                    selectedItemID = items.first?.id
                }
            }
            .onChange(of: items.map(\.id)) { ids in
                if let selectedItemID, ids.contains(selectedItemID) { return }
                self.selectedItemID = ids.first
            }
            .alert(strings.error, isPresented: Binding(
                get: { playbackError != nil },
                set: { if !$0 { playbackError = nil } }
            )) {
                Button(strings.ok, role: .cancel) {}
            } message: {
                Text(playbackError ?? "")
            }
        }
        .navigationViewStyle(.stack)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform")
                .font(.largeTitle)
                .foregroundStyle(PortTheme.textMuted)
            Text(strings.recordingsLibraryEmpty)
                .font(.subheadline)
                .foregroundStyle(PortTheme.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private var recordingsList: some View {
        List {
            ForEach(items) { item in
                Button {
                    selectItem(item)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: iconName(for: item))
                            .font(.body.weight(.semibold))
                            .foregroundStyle(PortTheme.accent)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(PortTheme.heading)
                                .lineLimit(1)
                            Text(itemSubtitle(item))
                                .font(.caption)
                                .foregroundStyle(PortTheme.textMuted)
                                .lineLimit(1)
                        }

                        Spacer()

                        Text(formatDuration(item.duration))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(PortTheme.textMuted)

                        if playerService.isActive(item) {
                            Image(systemName: playerService.isPlaying ? "speaker.wave.2.fill" : "pause.fill")
                                .font(.caption)
                                .foregroundStyle(PortTheme.accent)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .listRowBackground(
                    (selectedItem?.id == item.id ? PortTheme.accentSoft : PortTheme.surface)
                )
            }
        }
        .listStyle(.plain)
    }

    private var transportPanel: some View {
        VStack(spacing: 14) {
            if let item = selectedItem {
                VStack(spacing: 4) {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PortTheme.heading)
                        .lineLimit(1)
                    Text("\(formatDuration(playerService.currentTime)) / \(formatDuration(playerService.duration > 0 ? playerService.duration : item.duration))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(PortTheme.textMuted)
                }
            }

            HStack(spacing: 12) {
                transportButton(title: strings.seekBack10, icon: "gobackward.10") {
                    playerService.seek(by: -10)
                }

                transportButton(
                    title: playerService.isPlaying ? strings.pause : strings.play,
                    icon: playerService.isPlaying ? "pause.fill" : "play.fill"
                ) {
                    togglePlayback()
                }

                transportButton(title: strings.stop, icon: "stop.fill") {
                    playerService.stop()
                }

                transportButton(title: strings.seekForward10, icon: "goforward.10") {
                    playerService.seek(by: 10)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(PortTheme.surface)
    }

    private func transportButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.body.weight(.semibold))
                Text(title)
                    .font(.caption2)
            }
            .foregroundStyle(PortTheme.textSubtle)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(PortTheme.surfaceInput)
            .clipShape(RoundedRectangle(cornerRadius: PortTheme.radiusMD, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(selectedItem == nil)
    }

    private func selectItem(_ item: DictionaryRecordingListItem) {
        selectedItemID = item.id
        if playerService.isActive(item) {
            playerService.togglePlayPause()
            return
        }
        playItem(item)
    }

    private func togglePlayback() {
        guard let item = selectedItem else { return }
        if playerService.isActive(item) {
            playerService.togglePlayPause()
        } else {
            playItem(item)
        }
    }

    private func playItem(_ item: DictionaryRecordingListItem) {
        do {
            switch item.kind {
            case .word(let id):
                try playerService.play(url: item.url, wordID: id)
            case .folder(let key):
                try playerService.play(url: item.url, folderKey: key)
            }
        } catch {
            playbackError = error.localizedDescription
        }
    }

    private func itemSubtitle(_ item: DictionaryRecordingListItem) -> String {
        switch item.kind {
        case .word:
            return item.subtitle
        case .folder:
            if let count = item.detailCount {
                return strings.wordsCount(count)
            }
            return strings.folderRecordingLabel
        }
    }

    private func iconName(for item: DictionaryRecordingListItem) -> String {
        switch item.kind {
        case .word: return "character.book.closed"
        case .folder: return "folder.fill"
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        let minutes = total / 60
        let remainder = total % 60
        return String(format: "%d:%02d", minutes, remainder)
    }
}

#if DEBUG
struct DictionaryRecordingsLibraryView_Previews: PreviewProvider {
    static var previews: some View {
        DictionaryRecordingsLibraryView()
            .environmentObject(VocabularyStore())
            .environmentObject(AppSettings())
    }
}
#endif
