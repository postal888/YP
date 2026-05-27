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
    @State private var isSourceLanguageExpanded = false
    @State private var activeWord: ActiveSubtitleWord?
    @State private var translationPreview: String?
    @State private var isTranslating = false
    @State private var translationError: String?

    private var strings: AppStrings { appSettings.strings }
    private var folderKey: String { VocabularyFolderKey.pdf(book.title) }

    var body: some View {
        VStack(spacing: 0) {
            header
            translationSection

            if let document {
                PDFKitReaderView(
                    document: document,
                    savedWordKeys: vocabularyStore.lookupKeys,
                    fontScale: CGFloat(appSettings.readerFontScale),
                    onWordTap: { word in
                        handleWordTap(word)
                    },
                    onPageChange: { page, total in
                        currentPage = page
                        pageCount = total
                    }
                )
                .padding(.horizontal, 12)
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
                ProgressView(strings.openingPDF)
                    .tint(PortTheme.accent)
                Spacer()
            }
        }
        .background(PortTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .onAppear {
            bookLibrary.markOpened(book)
            vocabularyStore.ensureFolderTitle(key: folderKey, defaultTitle: book.title)
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
                        Text(strings.readerPageProgress(currentPage, total: pageCount))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(PortTheme.textMuted)
                    }
                }

                Spacer()

                fontControls
            }

            languagePicker
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(PortTheme.background)
    }

    private var fontControls: some View {
        HStack(spacing: 6) {
            Button {
                adjustFontScale(by: -0.1)
            } label: {
                Image(systemName: "textformat.size.smaller")
                    .font(.body.weight(.semibold))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .foregroundStyle(PortTheme.textSubtle)
            .disabled(appSettings.readerFontScale <= 0.85)

            Text("\(Int(appSettings.readerFontScale * 100))%")
                .font(.caption.monospacedDigit())
                .foregroundStyle(PortTheme.textMuted)
                .frame(minWidth: 36)

            Button {
                adjustFontScale(by: 0.1)
            } label: {
                Image(systemName: "textformat.size.larger")
                    .font(.body.weight(.semibold))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .foregroundStyle(PortTheme.textSubtle)
            .disabled(appSettings.readerFontScale >= 1.6)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(PortTheme.surfaceInput)
        .clipShape(Capsule())
    }

    private var languagePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isSourceLanguageExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Text(strings.subtitleLanguage)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PortTheme.textSubtle)
                    Spacer()
                    Text(sourceLanguage.label)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(PortTheme.textMuted)
                    Image(systemName: isSourceLanguageExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PortTheme.textMuted)
                }
            }
            .buttonStyle(.plain)

            if isSourceLanguageExpanded {
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
        }
        .padding(14)
        .portCard()
    }

    @ViewBuilder
    private var translationSection: some View {
        VStack(spacing: 8) {
            if let translationError {
                Text(translationError)
                    .font(.subheadline)
                    .foregroundStyle(PortTheme.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
            }

            if translationPreview != nil || isTranslating || activeWord != nil {
                SubtitleTranslationPreviewBar(
                    translationPreview: $translationPreview,
                    isTranslating: $isTranslating,
                    activeWord: $activeWord,
                    sourceLanguage: sourceLanguage.rawValue,
                    folderKey: folderKey,
                    folderTitle: book.title,
                    onWordAdded: { _ in }
                )
                .padding(.horizontal, 16)
            }
        }
        .padding(.bottom, 8)
        .background(PortTheme.background)
    }

    private func adjustFontScale(by delta: Double) {
        let next = min(max(appSettings.readerFontScale + delta, 0.85), 1.6)
        appSettings.readerFontScale = next
    }

    private func loadDocumentIfNeeded() {
        guard document == nil, loadError == nil else { return }
        guard let loaded = PDFDocument(url: book.localURL) else {
            loadError = strings.readerOpenFailed
            return
        }
        document = loaded
        pageCount = loaded.pageCount
        currentPage = 1
    }

    private func handleWordTap(_ word: PDFReaderWordTap) {
        let subtitleWord = ActiveSubtitleWord(lookupKey: word.lookupKey, display: word.display)
        activeWord = subtitleWord
        translationError = nil
        Task {
            await translate(word: subtitleWord)
        }
    }

    private func translate(word: ActiveSubtitleWord) async {
        if let cached = await WordTranslationService.shared.cachedTranslation(
            for: word.lookupKey,
            sourceLanguage: sourceLanguage.rawValue,
            context: .reader,
            useChatGPT: appSettings.useChatGPTTranslation
        ) {
            translationPreview = "\(word.display) — \(cached)"
            return
        }

        isTranslating = true
        translationPreview = "\(word.display) — …"
        translationError = nil

        do {
            let translated = try await WordTranslationService.shared.translate(
                word.lookupKey,
                sourceLanguage: sourceLanguage.rawValue,
                context: .reader,
                useChatGPT: appSettings.useChatGPTTranslation,
                backendBaseURL: appSettings.normalizedBackendURL
            )
            translationPreview = "\(word.display) — \(translated)"
        } catch {
            translationPreview = nil
            translationError = error.localizedDescription
        }

        isTranslating = false
    }
}
