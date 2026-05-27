import SwiftUI
import UIKit

@MainActor
struct DictionaryFolderRecorderContent: View {
    @StateObject private var viewModel: DictionaryFolderRecordingViewModel
    @ObservedObject private var playerService = DictionaryAudioPlayerService.shared
    @ObservedObject private var recorderService = DictionaryAudioRecorderService.shared
    @ObservedObject private var ttsService = WordTTSService.shared

    init(
        folder: VocabularyFolderGroup,
        playbackCards: [VocabularyCard],
        vocabularyStore: VocabularyStore,
        appSettings: AppSettings
    ) {
        _viewModel = StateObject(
            wrappedValue: DictionaryFolderRecordingViewModel(
                folder: folder,
                playbackCards: playbackCards,
                vocabularyStore: vocabularyStore,
                appSettings: appSettings
            )
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            folderHeader
            if viewModel.playbackCount > 0 {
                ttsOptions
            }
            recorderControls
        }
        .onAppear { viewModel.syncPhaseFromStore() }
        .onDisappear { viewModel.cleanupOnDismiss() }
        .confirmationDialog("Экспорт записи", isPresented: $viewModel.showExportOptions, titleVisibility: .visible) {
            Button("Export as M4A") { viewModel.exportAsM4A() }
            Button("Export as MP3") { viewModel.exportAsMP3() }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Удалить запись папки?", isPresented: $viewModel.showDeleteConfirmation, titleVisibility: .visible) {
            Button("Удалить", role: .destructive) { viewModel.deleteRecording() }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Запись папки будет удалена без возможности восстановления.")
        }
        .alert(viewModel.alertTitle, isPresented: $viewModel.showAlert) {
            if viewModel.alertTitle == "Нет доступа к микрофону" {
                Button("Настройки") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Отмена", role: .cancel) {}
            } else {
                Button("OK", role: .cancel) {}
            }
        } message: {
            Text(viewModel.alertMessage)
        }
        .sheet(item: $viewModel.shareItem) { item in
            ShareSheet(items: [item.url])
        }
    }

    private var folderHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(viewModel.folderTitle)
                .font(.title3.bold())
                .foregroundStyle(PortTheme.heading)
            Text("\(viewModel.playbackCount) слов в папке")
                .font(.body)
                .foregroundStyle(PortTheme.textSubtle)
            if viewModel.hasRecording {
                Label(formattedDuration(viewModel.recordingDuration), systemImage: "waveform")
                    .font(.caption)
                    .foregroundStyle(PortTheme.textMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .portCard()
    }

    private var ttsOptions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $viewModel.speakDuringRecording) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Озвучить слова папки")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PortTheme.heading)
                    Text("\(viewModel.playbackCount) слов · слово и перевод")
                        .font(.caption)
                        .foregroundStyle(PortTheme.textMuted)
                }
            }
            .tint(PortTheme.accent)
            .disabled(viewModel.phase == .recording)

            if viewModel.phase == .recording, ttsService.isPlaying {
                Label("Идёт озвучивание…", systemImage: "speaker.wave.2.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PortTheme.accent)
            }
        }
        .padding(14)
        .portCard()
    }

    @ViewBuilder
    private var recorderControls: some View {
        switch viewModel.phase {
        case .idle:
            idleControls
        case .recording:
            recordingControls
        case .recorded:
            recordedControls
        }
    }

    private var idleControls: some View {
        VStack(spacing: 14) {
            Text("Запишите произношение всех слов папки. Можно со встроенной озвучкой или своим голосом.")
                .font(.subheadline)
                .foregroundStyle(PortTheme.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button { viewModel.startRecording() } label: {
                Label("Записать папку", systemImage: "mic.fill")
            }
            .buttonStyle(PortPrimaryButtonStyle())
        }
        .padding(14)
        .portCard()
    }

    private var recordingControls: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Circle().fill(PortTheme.danger).frame(width: 10, height: 10)
                Text("Идёт запись папки…")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PortTheme.heading)
                Spacer()
            }
            Button { viewModel.stopRecording() } label: {
                Label("Стоп", systemImage: "stop.fill")
            }
            .buttonStyle(PortPrimaryButtonStyle())
        }
        .padding(14)
        .portCard()
    }

    private var recordedControls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                if playerService.isPlaying && playerService.playingFolderKey == viewModel.folderKey {
                    Button { viewModel.stopPlayback() } label: {
                        Label("Стоп", systemImage: "stop.fill")
                    }
                    .buttonStyle(DictionaryRecorderSecondaryButtonStyle())
                } else {
                    Button { viewModel.playRecording() } label: {
                        Label("Слушать", systemImage: "play.fill")
                    }
                    .buttonStyle(DictionaryRecorderSecondaryButtonStyle())
                }

                Button { viewModel.showExportOptions = true } label: {
                    Label("Экспорт", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(DictionaryRecorderSecondaryButtonStyle())
            }

            Button(role: .destructive) { viewModel.showDeleteConfirmation = true } label: {
                Label("Удалить", systemImage: "trash")
            }
            .buttonStyle(DictionaryRecorderSecondaryButtonStyle())

            Button { viewModel.startRecording() } label: {
                Label("Записать снова", systemImage: "mic.fill")
            }
            .buttonStyle(PortPrimaryButtonStyle())
        }
        .padding(14)
        .portCard()
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = max(Int(duration.rounded()), 0)
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}

@MainActor
struct DictionaryFolderRecorderPanel: View {
    let session: DictionaryFolderRecordingSession
    let vocabularyStore: VocabularyStore
    let appSettings: AppSettings

    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        NavigationView {
            ScrollView {
                DictionaryFolderRecorderContent(
                    folder: session.folder,
                    playbackCards: session.playbackCards,
                    vocabularyStore: vocabularyStore,
                    appSettings: appSettings
                )
                .padding(16)
            }
            .background(PortTheme.background.ignoresSafeArea())
            .navigationTitle("Диктофон папки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}
