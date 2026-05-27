import SwiftUI
import UIKit

@MainActor
struct DictionaryWordRecorderPanel: View {
    @StateObject private var viewModel: DictionaryWordRecordingViewModel
    @ObservedObject private var playerService = DictionaryAudioPlayerService.shared
    @ObservedObject private var recorderService = DictionaryAudioRecorderService.shared
    @Environment(\.presentationMode) private var presentationMode

    init(card: VocabularyCard, vocabularyStore: VocabularyStore) {
        _viewModel = StateObject(
            wrappedValue: DictionaryWordRecordingViewModel(
                card: card,
                vocabularyStore: vocabularyStore
            )
        )
    }

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                wordHeader
                recorderControls
                Spacer(minLength: 0)
            }
            .padding(16)
            .background(PortTheme.background.ignoresSafeArea())
            .navigationTitle("Диктофон")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .onAppear {
                viewModel.syncPhaseFromStore()
            }
            .onDisappear {
                viewModel.cleanupOnDismiss()
            }
            .confirmationDialog("Экспорт записи", isPresented: $viewModel.showExportOptions, titleVisibility: .visible) {
                Button("Export as M4A") {
                    viewModel.exportAsM4A()
                }
                Button("Export as MP3") {
                    viewModel.exportAsMP3()
                }
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog(
                "Удалить запись?",
                isPresented: $viewModel.showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Удалить", role: .destructive) {
                    viewModel.deleteRecording()
                }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Запись будет удалена с устройства без возможности восстановления.")
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
        .navigationViewStyle(.stack)
    }

    private var wordHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(viewModel.cardSource)
                .font(.title3.bold())
                .foregroundStyle(PortTheme.heading)
            Text(viewModel.cardTranslation)
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
            Text("Запишите произношение слова и перевода.")
                .font(.subheadline)
                .foregroundStyle(PortTheme.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                viewModel.startRecording()
            } label: {
                Label("Record", systemImage: "mic.fill")
            }
            .buttonStyle(PortPrimaryButtonStyle())
        }
        .padding(14)
        .portCard()
    }

    private var recordingControls: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Circle()
                    .fill(PortTheme.danger)
                    .frame(width: 10, height: 10)
                Text("Идёт запись…")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PortTheme.heading)
                Spacer()
            }

            Button {
                viewModel.stopRecording()
            } label: {
                Label("Stop", systemImage: "stop.fill")
            }
            .buttonStyle(PortPrimaryButtonStyle())
        }
        .padding(14)
        .portCard()
    }

    private var recordedControls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                if playerService.isPlaying && playerService.playingWordID == viewModel.cardID {
                    Button {
                        viewModel.stopPlayback()
                    } label: {
                        Label("Stop playback", systemImage: "stop.fill")
                    }
                    .buttonStyle(DictionaryRecorderSecondaryButtonStyle())
                } else {
                    Button {
                        viewModel.playRecording()
                    } label: {
                        Label("Play", systemImage: "play.fill")
                    }
                    .buttonStyle(DictionaryRecorderSecondaryButtonStyle())
                }

                Button {
                    viewModel.showExportOptions = true
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(DictionaryRecorderSecondaryButtonStyle())
            }

            if !viewModel.isMP3ExportAvailable {
                Text("MP3 экспорт появится после подключения encoder provider.")
                    .font(.caption)
                    .foregroundStyle(PortTheme.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button(role: .destructive) {
                viewModel.showDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .buttonStyle(DictionaryRecorderSecondaryButtonStyle())

            Button {
                viewModel.startRecording()
            } label: {
                Label("Record again", systemImage: "mic.fill")
            }
            .buttonStyle(PortPrimaryButtonStyle())
        }
        .padding(14)
        .portCard()
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = max(Int(duration.rounded()), 0)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

private struct DictionaryRecorderSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(PortTheme.heading)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(PortTheme.surfaceInput.opacity(configuration.isPressed ? 0.85 : 1))
            .clipShape(RoundedRectangle(cornerRadius: PortTheme.radiusMD, style: .continuous))
    }
}

#if DEBUG
struct DictionaryWordRecorderPanel_Previews: PreviewProvider {
    static var previews: some View {
        DictionaryWordRecorderPanel(
            card: VocabularyCard(source: "obrigado", translation: "спасибо", sourceLanguage: "pt"),
            vocabularyStore: VocabularyStore()
        )
    }
}
#endif
