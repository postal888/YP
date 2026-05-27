import SwiftUI

@MainActor
struct HomeView: View {
    @ObservedObject var errorLog: AppErrorLog
    let onOpenVideo: (String, String?) -> Void

    @State private var searchText = ""
    @State private var activeQuery = ""
    @State private var results: [YouTubeSearchResult] = []
    @State private var suggestionItems: [YouTubeSearchSuggestionItem] = []
    @State private var isSearching = false
    @State private var searchError: String?
    @State private var selectedCategory: String?
    @State private var isSearchActive = false
    @State private var searchFilter: YouTubeSearchFilter = .video
    @State private var searchTask: Task<Void, Never>?

    private let searchDebounceMs: UInt64 = 350

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if !isSearchActive {
                    heroSection
                }
                searchSection

                if isSearchActive {
                    suggestionsPanel
                }

                if !isSearchActive {
                    categoryChips
                    resultsSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(PortTheme.background.ignoresSafeArea())
        .onChange(of: searchText) { _ in
            scheduleLiveSearch()
        }
        .onChange(of: searchFilter) { _ in
            scheduleLiveSearch(force: true)
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "play.rectangle.fill")
                    .font(.title2)
                    .foregroundStyle(PortTheme.accent)
                Text("Video")
                    .font(.title2.bold())
                    .foregroundStyle(PortTheme.heading)
            }

            Text("YouTube · субтитры и перевод")
                .font(.title3.weight(.semibold))
                .foregroundStyle(PortTheme.heading)

            Text("Ищите видео, смотрите с субтитрами и нажимайте на слова.")
                .font(.subheadline)
                .foregroundStyle(PortTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
    }

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                PortSearchBar(
                    text: $searchText,
                    placeholder: "Поиск видео на YouTube…",
                    onSubmit: { submitSearch() },
                    onEditingChanged: { editing in
                        isSearchActive = editing || !searchText.isEmpty
                        if !editing, searchText.isEmpty {
                            suggestionItems = []
                        }
                    }
                )

                if isSearchActive {
                    Button("Отмена") {
                        cancelSearch()
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(PortTheme.accent)
                }
            }

            if isSearchActive {
                HStack(spacing: 8) {
                    ForEach(YouTubeSearchFilter.allCases) { filter in
                        Button(filter.label) {
                            searchFilter = filter
                        }
                        .buttonStyle(PortChipButtonStyle(isSelected: searchFilter == filter))
                    }
                }
            } else {
                Button("Искать") {
                    submitSearch()
                }
                .buttonStyle(PortPrimaryButtonStyle())
                .disabled(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSearching)
            }

            if let directVideoID = directVideoID(from: searchText), !searchText.isEmpty, !isSearchActive {
                Button {
                    onOpenVideo(directVideoID, nil)
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

    private var suggestionsPanel: some View {
        VStack(spacing: 0) {
            if isSearching {
                HStack(spacing: 10) {
                    ProgressView().tint(PortTheme.accent)
                    Text("Ищем…")
                        .font(.subheadline)
                        .foregroundStyle(PortTheme.textMuted)
                    Spacer()
                }
                .padding(14)
            } else if let searchError {
                Text(searchError)
                    .font(.subheadline)
                    .foregroundStyle(PortTheme.danger)
                    .padding(14)
            } else if suggestionItems.isEmpty, !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Начните вводить запрос — появятся варианты")
                    .font(.subheadline)
                    .foregroundStyle(PortTheme.textMuted)
                    .padding(14)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(suggestionItems) { item in
                            YouTubeSearchSuggestionRow(item: item) {
                                selectSuggestion(item)
                            }

                            if item.id != suggestionItems.last?.id {
                                Divider().overlay(PortTheme.border)
                            }
                        }
                    }
                }
                .frame(maxHeight: 420)
            }
        }
        .background(PortTheme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: PortTheme.radiusLG, style: .continuous)
                .stroke(PortTheme.cardBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: PortTheme.radiusLG, style: .continuous))
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
                            isSearchActive = true
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
        if isSearching, !isSearchActive {
            HStack(spacing: 10) {
                ProgressView()
                    .tint(PortTheme.accent)
                Text("Ищем на YouTube…")
                    .font(.subheadline)
                    .foregroundStyle(PortTheme.textMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
        } else if let searchError, !isSearchActive {
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
                            onOpenVideo(result.videoID, result.title)
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
                tipRow("1", "Начните вводить запрос")
                tipRow("2", "Выберите вариант из списка")
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

    private func scheduleLiveSearch(force: Bool = false) {
        searchTask?.cancel()

        let raw = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else {
            suggestionItems = []
            searchError = nil
            isSearching = false
            return
        }

        if directVideoID(from: raw) != nil {
            suggestionItems = []
            return
        }

        isSearchActive = true
        isSearching = true
        searchError = nil

        searchTask = Task {
            if !force {
                try? await Task.sleep(nanoseconds: searchDebounceMs * 1_000_000)
            }
            guard !Task.isCancelled else { return }

            do {
                let items = try await YouTubeSearchService.shared.buildSuggestionItems(
                    query: raw,
                    filter: searchFilter
                )
                guard !Task.isCancelled else { return }
                suggestionItems = items
                if items.isEmpty {
                    searchError = "По запросу «\(raw)» ничего не найдено."
                }
            } catch {
                guard !Task.isCancelled else { return }
                searchError = error.localizedDescription
                suggestionItems = []
                errorLog.add(source: "Search", message: "query=\(raw): \(error.localizedDescription)")
            }

            isSearching = false
        }
    }

    private func selectSuggestion(_ item: YouTubeSearchSuggestionItem) {
        switch item {
        case .query(let text):
            searchText = text
            submitSearch(query: text)

        case .video(let result):
            isSearchActive = false
            suggestionItems = []
            onOpenVideo(result.videoID, result.title)

        case .channel(let channel):
            searchFilter = .video
            searchText = channel.title
            submitSearch(query: channel.title)
        }
    }

    private func cancelSearch() {
        searchTask?.cancel()
        searchText = ""
        suggestionItems = []
        searchError = nil
        isSearching = false
        isSearchActive = false
    }

    private func submitSearch(query: String? = nil) {
        let raw = (query ?? searchText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }

        if let videoID = directVideoID(from: raw) {
            isSearchActive = false
            onOpenVideo(videoID, nil)
            return
        }

        activeQuery = raw
        searchText = raw
        searchError = nil
        isSearching = true
        results = []

        Task {
            do {
                let response = try await YouTubeSearchService.shared.search(query: raw, filter: .video)
                results = response.videos
                if response.videos.isEmpty {
                    searchError = "По запросу «\(raw)» ничего не найдено."
                }
                isSearchActive = false
                suggestionItems = []
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
        HomeView(errorLog: AppErrorLog(), onOpenVideo: { _, _ in })
    }
}
#endif
