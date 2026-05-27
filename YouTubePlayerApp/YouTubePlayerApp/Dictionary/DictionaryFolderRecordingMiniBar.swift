import SwiftUI

@MainActor
struct DictionaryFolderRecordingMiniBar: View {
    @ObservedObject var viewModel: DictionaryFolderRecordingViewModel
    @ObservedObject private var recorderService = DictionaryAudioRecorderService.shared
    @EnvironmentObject private var appSettings: AppSettings
    let onExpand: () -> Void

    private var strings: AppStrings { appSettings.strings }

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onExpand) {
                HStack(spacing: 8) {
                    Image(systemName: statusIcon)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(statusColor)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.folderTitle)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PortTheme.heading)
                            .lineLimit(1)
                        Text(statusLabel)
                            .font(.caption2)
                            .foregroundStyle(PortTheme.textMuted)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            if viewModel.phase == .recording {
                if recorderService.isPaused {
                    miniButton(icon: "mic.fill", label: strings.record) {
                        viewModel.resumeRecording()
                    }
                } else {
                    miniButton(icon: "pause.fill", label: strings.pause) {
                        viewModel.pauseRecording()
                    }
                }

                miniButton(icon: "stop.fill", label: strings.stop, tint: PortTheme.danger) {
                    viewModel.stopRecording()
                }
            } else if viewModel.phase == .idle {
                miniButton(icon: "mic.fill", label: strings.record) {
                    viewModel.startRecording()
                }
            }

            Button(action: onExpand) {
                Image(systemName: "chevron.up")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(PortTheme.textSubtle)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(strings.expandRecorder)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(PortTheme.surface)
        .overlay(alignment: .top) {
            Divider().overlay(PortTheme.border)
        }
    }

    private var statusIcon: String {
        switch viewModel.phase {
        case .recording:
            return recorderService.isPaused ? "pause.circle.fill" : "mic.circle.fill"
        case .recorded:
            return "checkmark.circle.fill"
        case .idle:
            return "mic.circle"
        }
    }

    private var statusColor: Color {
        switch viewModel.phase {
        case .recording:
            return recorderService.isPaused ? PortTheme.textSubtle : PortTheme.danger
        case .recorded:
            return PortTheme.accent
        case .idle:
            return PortTheme.textSubtle
        }
    }

    private var statusLabel: String {
        switch viewModel.phase {
        case .recording:
            return recorderService.isPaused ? strings.recordingPaused : strings.recordingInProgress
        case .recorded:
            return strings.folderRecordingSaved
        case .idle:
            return strings.folderDictaphone
        }
    }

    private func miniButton(
        icon: String,
        label: String,
        tint: Color = PortTheme.accent,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.body.weight(.semibold))
                Text(label)
                    .font(.caption2)
            }
            .foregroundStyle(tint)
            .frame(minWidth: 44)
        }
        .buttonStyle(.plain)
    }
}
