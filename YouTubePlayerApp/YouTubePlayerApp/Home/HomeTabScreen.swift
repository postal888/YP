import SwiftUI

@MainActor
struct HomeTabScreen: View {
    @EnvironmentObject private var vocabularyStore: VocabularyStore
    @EnvironmentObject private var bookLibrary: BookLibraryStore
    @EnvironmentObject private var learningStats: LearningStatsStore
    let onSelectTab: (AppTab) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                todayCard
                continueButton
                quickGrid
                collectionsSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(PortTheme.background.ignoresSafeArea())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("PortuLearn")
                    .font(.title2.bold())
                    .foregroundStyle(PortTheme.heading)
                Text("beta")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PortTheme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(PortTheme.accentSoft)
                    .clipShape(Capsule())
            }
            Text("Сегодняшний план")
                .font(.subheadline)
                .foregroundStyle(PortTheme.textMuted)
        }
    }

    private var todayCard: some View {
        HStack(spacing: 0) {
            statBlock(value: "\(vocabularyStore.cards.count)", label: "в словаре")
            divider
            statBlock(value: "\(bookLibrary.books.count)", label: "книг")
            divider
            statBlock(value: "\(learningStats.streakDays)", label: "streak")
        }
        .padding(16)
        .portCard()
    }

    private var divider: some View {
        Rectangle()
            .fill(PortTheme.border)
            .frame(width: 1, height: 44)
    }

    private func statBlock(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(PortTheme.heading)
            Text(label)
                .font(.caption)
                .foregroundStyle(PortTheme.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private var continueButton: some View {
        Button {
            onSelectTab(.study)
        } label: {
            Text("Продолжить повтор")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(PortTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: PortTheme.radiusMD, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(vocabularyStore.cards.isEmpty)
        .opacity(vocabularyStore.cards.isEmpty ? 0.55 : 1)
    }

    private var quickGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            quickCard(title: "Reader", icon: "book.fill", tab: .reader)
            quickCard(title: "Video", icon: "play.rectangle.fill", tab: .video)
            quickCard(title: "Словарь", icon: "character.book.closed.fill", tab: .dictionary)
            quickCard(title: "Study", icon: "square.stack.fill", tab: .study)
            quickCard(title: "Аккаунт", icon: "person.crop.circle.fill", tab: .account)
        }
    }

    private func quickCard(title: String, icon: String, tab: AppTab) -> some View {
        Button {
            onSelectTab(tab)
        } label: {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(PortTheme.accent)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PortTheme.textSubtle)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .portCard()
        }
        .buttonStyle(.plain)
    }

    private var collectionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Недавние слова")
                .font(.headline)
                .foregroundStyle(PortTheme.heading)

            if vocabularyStore.cards.isEmpty {
                Text("Пока нет слов. Добавляйте их из видео или PDF.")
                    .font(.subheadline)
                    .foregroundStyle(PortTheme.textMuted)
                    .padding(14)
                    .portCard()
            } else {
                VStack(spacing: 8) {
                    ForEach(vocabularyStore.cards.prefix(5)) { card in
                        HStack {
                            Text(card.source)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(PortTheme.heading)
                            Text("—")
                                .foregroundStyle(PortTheme.textMuted)
                            Text(card.translation)
                                .font(.subheadline)
                                .foregroundStyle(PortTheme.textMuted)
                                .lineLimit(1)
                            Spacer()
                        }
                        .padding(12)
                        .portCard()
                    }
                }
            }
        }
    }
}

#if DEBUG
struct HomeTabScreen_Previews: PreviewProvider {
    static var previews: some View {
        HomeTabScreen(onSelectTab: { _ in })
            .environmentObject(VocabularyStore())
            .environmentObject(BookLibraryStore())
            .environmentObject(LearningStatsStore())
    }
}
#endif
