import SwiftUI

@MainActor
struct ErrorLogPanelView: View {
    @ObservedObject var log: AppErrorLog

    @State private var isExpanded = true
    @State private var didCopy = false

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            header

            if isExpanded {
                logContent
                actionBar
            }
        }
        .background(Color(.systemBackground))
    }

    private var header: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        } label: {
            HStack {
                Label("Лог ошибок", systemImage: "exclamationmark.bubble")
                    .font(.subheadline.weight(.semibold))

                if !log.entries.isEmpty {
                    Text("\(log.entries.count)")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.15))
                        .foregroundStyle(.red)
                        .clipShape(Capsule())
                }

                Spacer()

                Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var logContent: some View {
        if log.entries.isEmpty {
            Text("Ошибок пока нет.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
        } else {
            ScrollView {
                ScrollViewReader { proxy in
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(log.entries) { entry in
                            Text(entry.formattedLine)
                                .font(.caption.monospaced())
                                .foregroundStyle(.primary)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(entry.id)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .onChange(of: log.entries.count) { _ in
                        if let last = log.entries.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
            .frame(maxHeight: 160)
        }
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            Button {
                copyLog()
            } label: {
                Label(didCopy ? "Скопировано" : "Копировать всё", systemImage: didCopy ? "checkmark" : "doc.on.doc")
            }
            .buttonStyle(.bordered)
            .disabled(log.entries.isEmpty)

            Button(role: .destructive) {
                log.clear()
                didCopy = false
            } label: {
                Label("Очистить", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .disabled(log.entries.isEmpty)

            Spacer()
        }
        .font(.caption)
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private func copyLog() {
        guard !log.combinedText.isEmpty else { return }
#if canImport(UIKit)
        UIPasteboard.general.string = log.combinedText
#endif
        didCopy = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            didCopy = false
        }
    }
}

#Preview {
    ErrorLogPanelView(log: {
        let log = AppErrorLog()
        log.add(source: "Player", message: "YouTube error code 150")
        log.add(source: "Subtitles", message: "У видео нет открытых субтитров.")
        return log
    }())
}
