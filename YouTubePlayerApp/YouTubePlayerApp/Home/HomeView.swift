import SwiftUI

@MainActor
struct HomeView: View {
    @ObservedObject var errorLog: AppErrorLog
    let onOpenVideo: (String) -> Void

    @State private var searchText = ""
    @State private var activeQuery = ""
    @State private var results: [YouTubeSearchResult] = []
    @State private var isSearching = false
    @State private var searchError: String?
    @State private var selectedCategory: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                heroSection
                searchSection
                categoryChips
                resultsSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(PortTheme.background.ignoresSafeArea())
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "captions.bubble.fill")
                    .font(.title2)
                    .foregroundStyle(PortTheme.accent)

                Text("PortuLearn")
                    .font(.title2.bold())
                    .foregroundStyle(PortTheme.heading)
            }

            Text("Учите язык с YouTube")
                .font(.title3.weight(.semibold))
                .foregroundStyle(PortTheme.heading)

            Text("Субтитры, перевод слов и практика — прямо в приложении, как в Trancy.")
                .font(.subheadline)
                .foregroundStyle(PortTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
    }

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            PortSearchBar(
                text: $searchText,
                placeholder: "Поиск видео на YouTube…",
                onSubmit: { submitSearch() }
            )

            Button("Искать") {
                submitSearch()
            }
            .buttonStyle(PortPrimaryButtonStyle())
            .disabled(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSearching)

            if let directVideoID = directVideoID(from: searchText), !searchText.isEmpty {
                Button {
                    onOpenVideo(directVideoID)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "link")
                        Text("Открыть вставленную ссылку")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(PortTheme.accent)
                    .padding(14)
                    .background(PortTheme.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: PortTheme.radiusMD, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var categoryChips: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Популярные темы")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PortTheme.textSubtle)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(YouTubeSearchSuggestions.categories, id: \.title) { category in
                        Button(category.title) {
                            selectedCategory = category.title
                            searchText = category.query
                            submitSearch(query: category.query)
                        }
                        .buttonStyle(PortChipButtonStyle(isSelected: selectedCategory == category.title))
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    @ViewBuilder
    private var resultsSection: some View {
        if isSearching {
            HStack(spacing: 10) {
                ProgressView()
                    .tint(PortTheme.accent)
                Text("Ищем на YouTube…")
                    .font(.subheadline)
                    .foregroundStyle(PortTheme.textMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
        } else if let searchError {
            Text(searchError)
                .font(.subheadline)
                .foregroundStyle(PortTheme.danger)
        } else if !activeQuery.isEmpty {
            HStack {
                Text("Результаты")
                    .font(.headline)
                    .foregroundStyle(PortTheme.heading)
                Spacer()
                Text("«\(activeQuery)»")
                    .font(.caption)
                    .foregroundStyle(PortTheme.textMuted)
                    .lineLimit(1)
            }

            if results.isEmpty {
                Text("Ничего не найдено. Попробуйте другой запрос.")
                    .font(.subheadline)
                    .foregroundStyle(PortTheme.textMuted)
                    .padding(.top, 8)
            } else {
                LazyVStack(spacing: 18) {
                    ForEach(results) { result in
                        YouTubeVideoCard(result: result) {
                            onOpenVideo(result.videoID)
                        }
                    }
                }
                .padding(.top, 4)
            }
        } else {
            emptyState
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Найдите интересное видео", systemImage: "sparkles")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PortTheme.textSubtle)

            VStack(alignment: .leading, spacing: 8) {
                tipRow("1", "Введите запрос или выберите тему")
                tipRow("2", "Откройте видео с субтитрами")
                tipRow("3", "Нажимайте на слова для перевода")
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

    private func submitSearch(query: String? = nil) {
        let raw = (query ?? searchText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }

        if let videoID = directVideoID(from: raw) {
            onOpenVideo(videoID)
            return
        }

        activeQuery = raw
        searchError = nil
        isSearching = true
        results = []

        Task {
            do {
                let found = try await YouTubeSearchService.shared.search(query: raw)
                results = found
                if found.isEmpty {
                    searchError = "По запросу «\(raw)» ничего не найдено."
                }
            } catch {
                searchError = error.localizedDescription
                errorLog.add(source: "Search", message: "query=\(raw): \(error.localizedDescription)")
            }
            isSearching = false
        }
    }

    private func directVideoID(from input: String) -> String? {
        YouTubeVideoIDExtractor.extract(from: input.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

#if DEBUG
struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView(errorLog: AppErrorLog(), onOpenVideo: { _ in })
    }
}
#endif
