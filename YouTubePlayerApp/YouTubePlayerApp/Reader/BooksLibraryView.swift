import SwiftUI

@MainActor
struct BooksLibraryView: View {
    @EnvironmentObject private var bookLibrary: BookLibraryStore
    @EnvironmentObject private var appSettings: AppSettings

    @State private var showDocumentPicker = false
    @State private var importError: String?
    @State private var selectedBook: ImportedBook?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    hero
                    importSection

                    if let importError {
                        Text(importError)
                            .font(.subheadline)
                            .foregroundStyle(PortTheme.danger)
                    }

                    if bookLibrary.books.isEmpty {
                        emptyState
                    } else {
                        libraryList
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(PortTheme.background.ignoresSafeArea())
            .navigationBarHidden(true)
            .background(
                NavigationLink(
                    destination: Group {
                        if let selectedBook {
                            PDFReaderScreen(book: selectedBook)
                        }
                    },
                    tag: "reader",
                    selection: Binding(
                        get: { selectedBook == nil ? nil : "reader" },
                        set: { if $0 == nil { selectedBook = nil } }
                    )
                ) {
                    EmptyView()
                }
                .hidden()
            )
        }
        .navigationViewStyle(.stack)
        .sheet(isPresented: $showDocumentPicker) {
            PDFDocumentPicker(
                onPick: { url in
                    showDocumentPicker = false
                    importPDF(from: url)
                },
                onCancel: {
                    showDocumentPicker = false
                }
            )
        }
    }

    private var strings: AppStrings { appSettings.strings }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image("ProficonLogo")
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                Text(strings.readerTitle)
                    .font(.title2.bold())
                    .foregroundStyle(PortTheme.heading)
            }

            ProficonBrandView(style: .full, font: .subheadline.weight(.semibold))

            Text(strings.readerHeroTitle)
                .font(.title3.weight(.semibold))
                .foregroundStyle(PortTheme.heading)

            Text(strings.readerHeroSubtitle)
                .font(.subheadline)
                .foregroundStyle(PortTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var importSection: some View {
        Button {
            importError = nil
            showDocumentPicker = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "doc.badge.plus")
                Text(strings.openPDF)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(PortTheme.accent)
            .clipShape(RoundedRectangle(cornerRadius: PortTheme.radiusMD, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var libraryList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(strings.librarySection)
                .font(.headline)
                .foregroundStyle(PortTheme.heading)

            LazyVStack(spacing: 10) {
                ForEach(bookLibrary.books) { book in
                    bookRow(book)
                }
            }
        }
    }

    private func bookRow(_ book: ImportedBook) -> some View {
        HStack(spacing: 12) {
            Button {
                selectedBook = book
            } label: {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: PortTheme.radiusSM, style: .continuous)
                        .fill(PortTheme.surfaceInput)
                        .frame(width: 44, height: 56)
                        .overlay {
                            Image(systemName: "doc.richtext")
                                .foregroundStyle(PortTheme.accent)
                        }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(book.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(PortTheme.heading)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        Text(book.lastOpenedAt ?? book.importedAt, style: .date)
                            .font(.caption)
                            .foregroundStyle(PortTheme.textMuted)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PortTheme.textMuted)
                }
            }
            .buttonStyle(.plain)

            Button(role: .destructive) {
                bookLibrary.remove(book)
                if selectedBook?.id == book.id {
                    selectedBook = nil
                }
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(PortTheme.danger)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .portCard()
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(strings.addFirstBook, systemImage: "text.book.closed")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PortTheme.textSubtle)

            VStack(alignment: .leading, spacing: 8) {
                tipRow("1", strings.readerTipOpenPDF)
                tipRow("2", strings.readerTipTapWords)
                tipRow("3", strings.readerTipSaveTranslation)
            }
        }
        .padding(16)
        .portCard()
    }

    private func tipRow(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.caption.weight(.bold))
                .foregroundStyle(PortTheme.accent)
                .frame(width: 22, height: 22)
                .background(PortTheme.accentSoft)
                .clipShape(Circle())

            Text(text)
                .font(.subheadline)
                .foregroundStyle(PortTheme.textMuted)
        }
    }

    private func importPDF(from url: URL) {
        do {
            let book = try bookLibrary.importPDF(from: url)
            selectedBook = book
        } catch {
            importError = error.localizedDescription
        }
    }
}

#if DEBUG
struct BooksLibraryView_Previews: PreviewProvider {
    static var previews: some View {
        BooksLibraryView()
            .environmentObject(BookLibraryStore())
            .environmentObject(AppSettings())
    }
}
#endif
