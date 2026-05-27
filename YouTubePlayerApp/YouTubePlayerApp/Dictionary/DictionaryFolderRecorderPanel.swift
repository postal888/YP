import SwiftUI
import UIKit

@MainActor
struct DictionaryFolderRecorderContent: View {
    @ObservedObject var viewModel: DictionaryFolderRecordingViewModel
    @ObservedObject private var playerService = DictionaryAudioPlayerService.shared
    @ObservedObject private var recorderService = DictionaryAudioRecorderService.shared
    @ObservedObject private var ttsService = WordTTSService.shared
    @EnvironmentObject private var appSettings: AppSettings

    private var strings: AppStrings { appSettings.strings }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            folderHeader
            if viewModel.playbackCount > 0 {
                ttsOptions
            }
            recorderControls
        }
        .onAppear { viewModel.syncPhaseFromStore() }
        .confirmationDialog(strings.exportRecording, isPresented: $viewModel.showExportOptions, titleVisibility: .visible) {
            Button(strings.exportAsM4A) { viewModel.exportAsM4A() }
            Button(strings.exportAsMP3) { viewModel.exportAsMP3() }
            Button(strings.cancel, role: .cancel) {}
        }
        .confirmationDialog(strings.deleteFolderRecordingTitle, isPresented: $viewModel.showDeleteConfirmation, titleVisibility: .visible) {
            Button(strings.delete, role: .destructive) { viewModel.deleteRecording() }
            Button(strings.cancel, role: .cancel) {}
        } message: {
            Text(strings.deleteFolderRecordingMessage)
        }
        .alert(viewModel.alertTitle, isPresented: $viewModel.showAlert) {
            if viewModel.alertTitle == strings.microphonePermissionTitle {
                Button(strings.openSettings) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button(strings.cancel, role: .cancel) {}
            } else {
                Button(strings.ok, role: .cancel) {}
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
            Text(strings.wordsCount(viewModel.playbackCount))
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
                    Text(strings.speakFolderWords)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PortTheme.heading)
                    Text("\(viewModel.playbackCount) \(strings.words) · \(strings.wordAndTranslation)")
                        .font(.caption)
                        .foregroundStyle(PortTheme.textMuted)
                }
            }
            .tint(PortTheme.accent)
            .disabled(viewModel.phase == .recording)

            if viewModel.phase == .recording, ttsService.isPlaying {
                Label(strings.speakingInProgress, systemImage: "speaker.wave.2.fill")
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
            Text(strings.recordFolderHint)
                .font(.subheadline)
                .foregroundStyle(PortTheme.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button { viewModel.startRecording() } label: {
                Label(strings.recordFolderAction, systemImage: "mic.fill")
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
                Text(strings.folderRecordingInProgress)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PortTheme.heading)
                Spacer()
            }

            HStack(spacing: 10) {
                if recorderService.isPaused {
                    Button { viewModel.resumeRecording() } label: {
                        Label(strings.record, systemImage: "mic.fill")
                    }
                    .buttonStyle(DictionaryRecorderSecondaryButtonStyle())
                } else {
                    Button { viewModel.pauseRecording() } label: {
                        Label(strings.pause, systemImage: "pause.fill")
                    }
                    .buttonStyle(DictionaryRecorderSecondaryButtonStyle())
                }

                Button { viewModel.stopRecording() } label: {
                    Label(strings.stop, systemImage: "stop.fill")
                }
                .buttonStyle(PortPrimaryButtonStyle())
            }
        }
        .padding(14)
        .portCard()
    }

    private var recordedControls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                if playerService.isPlaying && playerService.playingFolderKey == viewModel.folderKey {
                    Button { viewModel.stopPlayback() } label: {
                        Label(strings.stop, systemImage: "stop.fill")
                    }
                    .buttonStyle(DictionaryRecorderSecondaryButtonStyle())
                } else {
                    Button { viewModel.playRecording() } label: {
                        Label(strings.play, systemImage: "play.fill")
                    }
                    .buttonStyle(DictionaryRecorderSecondaryButtonStyle())
                }

                Button { viewModel.showExportOptions = true } label: {
                    Label(strings.export, systemImage: "square.and.arrow.up")
                }
                .buttonStyle(DictionaryRecorderSecondaryButtonStyle())
            }

            Button(role: .destructive) { viewModel.showDeleteConfirmation = true } label: {
                Label(strings.delete, systemImage: "trash")
            }
            .buttonStyle(DictionaryRecorderSecondaryButtonStyle())

            Button { viewModel.startRecording() } label: {
                Label(strings.recordAgain, systemImage: "mic.fill")
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
    @ObservedObject var viewModel: DictionaryFolderRecordingViewModel
    let onMinimize: () -> Void
    let onClose: () -> Void

    @EnvironmentObject private var appSettings: AppSettings

    private var strings: AppStrings { appSettings.strings }

    var body: some View {
        NavigationView {
            ScrollView {
                DictionaryFolderRecorderContent(viewModel: viewModel)
                    .padding(16)
            }
            .background(PortTheme.background.ignoresSafeArea())
            .navigationTitle(strings.folderDictaphoneTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(strings.close) { onClose() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        onMinimize()
                    } label: {
                        Image(systemName: "chevron.down")
                    }
                    .accessibilityLabel(strings.minimizeRecorder)
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}
