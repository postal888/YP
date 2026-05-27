import SwiftUI

@MainActor
struct AccountTabScreen: View {
    @EnvironmentObject private var appSettings: AppSettings
    @EnvironmentObject private var vocabularyStore: VocabularyStore
    @EnvironmentObject private var learningStats: LearningStatsStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                statsSection
                settingsSection
                aboutSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(PortTheme.background.ignoresSafeArea())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Аккаунт")
                .font(.title2.bold())
                .foregroundStyle(PortTheme.heading)
            Text("Настройки и статистика обучения")
                .font(.subheadline)
                .foregroundStyle(PortTheme.textMuted)
        }
    }

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Статистика")
                .font(.headline)
                .foregroundStyle(PortTheme.heading)

            HStack(spacing: 0) {
                statBlock(value: "\(vocabularyStore.cards.count)", label: "в словаре")
                divider
                statBlock(value: "\(learningStats.snapshot.reviewSessions + learningStats.snapshot.quizSessions)", label: "сессий")
                divider
                statBlock(value: "\(learningStats.streakDays)", label: "streak")
            }
            .padding(16)
            .portCard()

            HStack(spacing: 0) {
                statBlock(
                    value: learningStats.accuracyPercent.map { "\($0)%" } ?? "—",
                    label: "точность (10)"
                )
                divider
                statBlock(
                    value: formattedStudyTime(learningStats.snapshot.totalStudySeconds),
                    label: "время"
                )
                divider
                statBlock(value: "\(learningStats.snapshot.quizSessions)", label: "квизов")
            }
            .padding(16)
            .portCard()
        }
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Настройки")
                .font(.headline)
                .foregroundStyle(PortTheme.heading)

            VStack(alignment: .leading, spacing: 14) {
                Toggle(isOn: $appSettings.useChatGPTTranslation) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Перевод через ChatGPT")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(PortTheme.heading)
                        Text("Субтитры и читалка будут обращаться к серверу PortuPrep вместо MyMemory.")
                            .font(.caption)
                            .foregroundStyle(PortTheme.textMuted)
                    }
                }
                .tint(PortTheme.accent)

                Toggle(isOn: $appSettings.backgroundVideoPlayback) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Фоновое воспроизведение")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(PortTheme.heading)
                        Text("Видео продолжит играть при переключении на другие вкладки и в фоне приложения.")
                            .font(.caption)
                            .foregroundStyle(PortTheme.textMuted)
                    }
                }
                .tint(PortTheme.accent)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Сервер")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PortTheme.textMuted)
                    TextField("https://gentechnet.com", text: $appSettings.backendBaseURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .font(.subheadline)
                        .foregroundStyle(PortTheme.heading)
                        .padding(12)
                        .background(PortTheme.surfaceInput)
                        .clipShape(RoundedRectangle(cornerRadius: PortTheme.radiusMD, style: .continuous))
                }
            }
            .padding(16)
            .portCard()
        }
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PortuLearn использует API PortuPrep на gentechnet.com для перевода (OpenAI) и озвучки слов (ElevenLabs).")
                .font(.caption)
                .foregroundStyle(PortTheme.textMuted)
        }
        .padding(14)
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

    private func formattedStudyTime(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds)с" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)м" }
        return "\(minutes / 60)ч"
    }
}

#if DEBUG
struct AccountTabScreen_Previews: PreviewProvider {
    static var previews: some View {
        AccountTabScreen()
            .environmentObject(AppSettings())
            .environmentObject(VocabularyStore())
            .environmentObject(LearningStatsStore())
    }
}
#endif
