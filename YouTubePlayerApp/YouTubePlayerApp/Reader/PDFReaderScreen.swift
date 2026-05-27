import SwiftUI
import PDFKit

@MainActor
struct PDFReaderScreen: View {
    let book: ImportedBook
    @EnvironmentObject private var vocabularyStore: VocabularyStore
    @EnvironmentObject private var bookLibrary: BookLibraryStore
    @EnvironmentObject private var appSettings: AppSettings
    @Environment(\.presentationMode) private var presentationMode

    @State private var document: PDFDocument?
    @State private var loadError: String?
    @State private var currentPage = 1
    @State private var pageCount = 0
    @State private var sourceLanguage: YouTubeSubtitleLanguage = .portuguese
    @State private var activeWord: PDFReaderWordTap?
    @State private var translationText: String?
    @State private var isTranslating = false
    @State private var translationError: String?
    @State private var didSaveCurrentWord = false

    var body: some View {
        VStack(spacing: 0) {
            header
            translationBar

            if let document {
                PDFKitReaderView(
                    document: document,
                    savedWordKeys: vocabularyStore.lookupKeys,
                    onWordTap: { word in
                        handleWordTap(word)
                    },
                    onPageChange: { page, total in
                        currentPage = page
                        pageCount = total
                    }
                )
                .background(PortTheme.surfaceMuted)
            } else if let loadError {
                Spacer()
                Text(loadError)
                    .font(.subheadline)
                    .foregroundStyle(PortTheme.danger)
                    .multilineTextAlignment(.center)
                    .padding()
                Spacer()
            } else {
                Spacer()
                ProgressView("Открываем PDF…")
                    .tint(PortTheme.accent)
                Spacer()
            }
        }
        .background(PortTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .onAppear {
            bookLibrary.markOpened(book)
            loadDocumentIfNeeded()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(PortTheme.textSubtle)
                        .frame(width: 36, height: 36)
                        .background(PortTheme.surfaceInput)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    Text(book.title)
                        .font(.headline)
                        .foregroundStyle(PortTheme.heading)
                        .lineLimit(1)
                    if pageCount > 0 {
                        Text("Страница \(currentPage) из \(pageCount)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(PortTheme.textMuted)
                    }
                }

                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(YouTubeSubtitleLanguage.allCases) { language in
                        Button(language.label) {
                            sourceLanguage = language
                            if let activeWord {
                                Task { await translate(word: activeWord) }
                            }
                        }
                        .buttonStyle(PortChipButtonStyle(isSelected: sourceLanguage == language))
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private var translationBar: some View {
        if activeWord != nil || translationText != nil || isTranslating || translationError != nil {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    if isTranslating {
                        ProgressView()
                            .controlSize(.small)
                            .tint(PortTheme.accent)
                    }

                    if let translationError {
                        Text(translationError)
                            .font(.subheadline)
                            .foregroundStyle(PortTheme.danger)
                    } else if let translationText {
                        Text(translationText)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(PortTheme.heading)
                    } else if let activeWord {
                        Text("\(activeWord.display) — …")
                            .font(.subheadline)
                            .foregroundStyle(PortTheme.textMuted)
                    }

                    Spacer()
                }

                if let activeWord, let translationText, !isTranslating, translationError == nil {
                    HStack(spacing: 10) {
                        if didSaveCurrentWord || vocabularyStore.contains(source: activeWord.lookupKey) {
                            Label("В словаре", systemImage: "checkmark.circle.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(PortTheme.successText)
                        } else {
                            Button {
                                saveToVocabulary(word: activeWord, translation: extractedTranslation(from: translationText))
                            } label: {
                                Label("Добавить в словарь", systemImage: "plus.circle.fill")
                                    .font(.caption.weight(.semibold))
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(PortTheme.accent)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(PortTheme.surface)
            .overlay(alignment: .bottom) {
                Divider().overlay(PortTheme.border)
            }
        }
    }

    private func loadDocumentIfNeeded() {
        guard document == nil, loadError == nil else { return }
        guard let loaded = PDFDocument(url: book.localURL) else {
            loadError = "Не удалось открыть PDF."
            return
        }
        document = loaded
        pageCount = loaded.pageCount
        currentPage = 1
    }

    private func handleWordTap(_ word: PDFReaderWordTap) {
        activeWord = word
        translationError = nil
        didSaveCurrentWord = vocabularyStore.contains(source: word.lookupKey)
        Task {
            await translate(word: word)
        }
    }

    private func translate(word: PDFReaderWordTap) async {
        isTranslating = true
        translationError = nil

        do {
            let translated = try await WordTranslationService.shared.translate(
                word.lookupKey,
                sourceLanguage: sourceLanguage.rawValue,
                context: .reader,
                useChatGPT: appSettings.useChatGPTTranslation,
                backendBaseURL: appSettings.normalizedBackendURL
            )
            translationText = "\(word.display) — \(translated)"
        } catch {
            translationText = nil
            translationError = error.localizedDescription
        }

        isTranslating = false
    }

    private func extractedTranslation(from line: String) -> String {
        guard let range = line.range(of: " — ") else { return line }
        return String(line[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func saveToVocabulary(word: PDFReaderWordTap, translation: String) {
        guard !translation.isEmpty else { return }
        vocabularyStore.add(
            source: word.lookupKey,
            translation: translation,
            sourceLanguage: sourceLanguage.rawValue,
            bookTitle: book.title
        )
        didSaveCurrentWord = true
    }
}
