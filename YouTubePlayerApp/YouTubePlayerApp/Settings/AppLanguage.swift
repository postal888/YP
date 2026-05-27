import Foundation

enum AppLanguage: String, CaseIterable, Codable, Identifiable {
    case english = "en"
    case russian = "ru"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: return "English"
        case .russian: return "Русский"
        }
    }
}

struct AppStrings {
    let language: AppLanguage

    var tabHome: String { t(en: "Home", ru: "Home") }
    var tabStudy: String { t(en: "Study", ru: "Study") }
    var tabReader: String { t(en: "Reader", ru: "Reader") }
    var tabVideo: String { t(en: "Video", ru: "Video") }
    var tabDictionary: String { t(en: "Dictionary", ru: "Словарь") }
    var tabAccount: String { t(en: "Account", ru: "Аккаунт") }

    var dictionaryTitle: String { t(en: "Dictionary", ru: "Словарь") }
    var select: String { t(en: "Select", ru: "Выбрать") }
    var done: String { t(en: "Done", ru: "Готово") }
    var all: String { t(en: "All", ru: "Все") }
    var reset: String { t(en: "Reset", ru: "Сброс") }
    var exportCSV: String { t(en: "CSV", ru: "CSV") }
    var recordings: String { t(en: "Recordings", ru: "Записи") }
    var dictaphone: String { t(en: "Record", ru: "Диктофон") }
    var speak: String { t(en: "Speak", ru: "Озвучить") }
    var delete: String { t(en: "Delete", ru: "Удалить") }
    var addToDictionary: String { t(en: "Add to dictionary", ru: "Добавить в словарь") }
    var hasRecording: String { t(en: "has recording", ru: "есть запись") }
    var folderRecording: String { t(en: "folder recording", ru: "запись папки") }
    var words: String { t(en: "words", ru: "слов") }
    var cards: String { t(en: "cards", ru: "карточек") }
    var folders: String { t(en: "folders", ru: "папок") }
    var searchDictionary: String { t(en: "Search dictionary…", ru: "Поиск в словаре…") }
    var dictionaryEmpty: String { t(en: "Dictionary is empty", ru: "Словарь пуст") }
    var dictionaryEmptyHint: String {
        t(en: "Tap words in PDF or subtitles and save translations.", ru: "Нажимайте на слова в PDF или субтитрах и сохраняйте перевод.")
    }
    var exportDeleteHint: String { t(en: "Export, delete, or record", ru: "Экспорт, удаление или диктофон") }
    var deleteSelectedTitle: String { t(en: "Delete selected words?", ru: "Удалить выбранные слова?") }
    var deleteSelectedMessage: String {
        t(en: "Cards and their audio recordings will be permanently deleted.", ru: "Карточки и их аудиозаписи будут удалены без возможности восстановления.")
    }
    var cancel: String { t(en: "Cancel", ru: "Отмена") }
    var close: String { t(en: "Close", ru: "Закрыть") }
    var play: String { t(en: "Play", ru: "Слушать") }
    var pause: String { t(en: "Pause", ru: "Пауза") }
    var stop: String { t(en: "Stop", ru: "Стоп") }
    var export: String { t(en: "Export", ru: "Экспорт") }
    var record: String { t(en: "Record", ru: "Записать") }
    var recordAgain: String { t(en: "Record again", ru: "Записать снова") }
    var recordingInProgress: String { t(en: "Recording…", ru: "Идёт запись…") }
    var speakSelectedDuringRecording: String { t(en: "Speak selected words", ru: "Озвучить выбранные слова") }
    var wordAndTranslation: String { t(en: "word + translation", ru: "слово и перевод") }
    var speakingInProgress: String { t(en: "Speaking…", ru: "Идёт озвучивание…") }
    var exportRecording: String { t(en: "Export recording", ru: "Экспорт записи") }
    var exportAsM4A: String { t(en: "Export as M4A", ru: "Export as M4A") }
    var exportAsMP3: String { t(en: "Export as MP3", ru: "Export as MP3") }
    var deleteRecordingTitle: String { t(en: "Delete recording?", ru: "Удалить запись?") }
    var deleteRecordingMessage: String {
        t(en: "The recording will be permanently deleted.", ru: "Запись будет удалена с устройства без возможности восстановления.")
    }
    var folderDictaphoneTitle: String { t(en: "Folder recorder", ru: "Диктофон папки") }
    var recordFolderHint: String {
        t(en: "Record all words in the folder. Use built-in speech or your own voice.", ru: "Запишите произношение всех слов папки. Можно со встроенной озвучкой или своим голосом.")
    }
    var speakFolderWords: String { t(en: "Speak folder words", ru: "Озвучить слова папки") }
    var accountTitle: String { t(en: "Account", ru: "Аккаунт") }
    var accountSubtitle: String { t(en: "Settings and learning stats", ru: "Настройки и статистика обучения") }
    var settings: String { t(en: "Settings", ru: "Настройки") }
    var appLanguage: String { t(en: "App language", ru: "Язык приложения") }
    var appLanguageHint: String { t(en: "Menus and labels across the app.", ru: "Меню и подписи во всём приложении.") }
    var recentTranslations: String { t(en: "Recent translations", ru: "Последние переводы") }
    var tapWordInSubtitles: String { t(en: "Tap a word in subtitles", ru: "Нажмите на слово в субтитрах") }
    var clear: String { t(en: "Clear", ru: "Очистить") }
    var subtitles: String { t(en: "Subtitles", ru: "Субтитры") }
    var loadingSubtitles: String { t(en: "Loading subtitles…", ru: "Загрузка субтитров…") }
    var subtitlesNotLoaded: String { t(en: "Subtitles not loaded.", ru: "Субтитры не загружены.") }
    var lines: String { t(en: "lines", ru: "строк") }
    var recordingsLibraryTitle: String { t(en: "Audio recordings", ru: "Аудиозаписи") }
    var recordingsLibraryEmpty: String { t(en: "No recordings yet", ru: "Записей пока нет") }
    var wordRecording: String { t(en: "Word recording", ru: "Запись слова") }
    var seekBack10: String { t(en: "-10s", ru: "-10с") }
    var seekForward10: String { t(en: "+10s", ru: "+10с") }
    var error: String { t(en: "Error", ru: "Ошибка") }
    var ok: String { t(en: "OK", ru: "OK") }
    var renameFolder: String { t(en: "Rename folder", ru: "Переименовать папку") }
    var speakFolder: String { t(en: "Speak folder", ru: "Озвучить папку") }
    var folderDictaphone: String { t(en: "Folder recorder", ru: "Диктофон папки") }
    var minimizeRecorder: String { t(en: "Minimize recorder", ru: "Свернуть диктофон") }
    var expandRecorder: String { t(en: "Expand recorder", ru: "Развернуть диктофон") }
    var recordingPaused: String { t(en: "Recording paused", ru: "Запись на паузе") }
    var folderRecordingSaved: String { t(en: "Folder recording saved", ru: "Запись папки сохранена") }
    var folderRecordingInProgress: String { t(en: "Recording folder…", ru: "Идёт запись папки…") }
    var recordFolderAction: String { t(en: "Record folder", ru: "Записать папку") }
    var deleteFolderRecordingTitle: String { t(en: "Delete folder recording?", ru: "Удалить запись папки?") }
    var deleteFolderRecordingMessage: String {
        t(en: "The folder recording will be permanently deleted.", ru: "Запись папки будет удалена без возможности восстановления.")
    }
    var microphonePermissionTitle: String { t(en: "Microphone access required", ru: "Нет доступа к микрофону") }
    var microphonePermissionMessage: String {
        t(en: "Allow microphone access in Settings to record pronunciations.", ru: "Разрешите доступ к микрофону в Настройках, чтобы записывать произношение слов.")
    }
    var openSettings: String { t(en: "Settings", ru: "Настройки") }
    var lessonTitle: String { t(en: "Lesson", ru: "Урок") }
    var playerErrorTitle: String { t(en: "Player error", ru: "Ошибка плеера") }
    var subtitleLanguage: String { t(en: "Subtitle language", ru: "Язык субтитров") }
    var videoCompleted: String { t(en: "Video watched to the end", ru: "Видео просмотрено до конца") }
    var statsTitle: String { t(en: "Statistics", ru: "Статистика") }
    var inDictionary: String { t(en: "in dictionary", ru: "в словаре") }
    var sessions: String { t(en: "sessions", ru: "сессий") }
    var accuracyLast10: String { t(en: "accuracy (10)", ru: "точность (10)") }
    var studyTime: String { t(en: "time", ru: "время") }
    var quizzes: String { t(en: "quizzes", ru: "квизов") }
    var chatGPTTranslation: String { t(en: "ChatGPT translation", ru: "Перевод через ChatGPT") }
    var chatGPTTranslationHint: String {
        t(en: "Subtitles and reader will use the PortuPrep server instead of MyMemory.", ru: "Субтитры и читалка будут обращаться к серверу PortuPrep вместо MyMemory.")
    }
    var backgroundPlayback: String { t(en: "Background playback", ru: "Фоновое воспроизведение") }
    var backgroundPlaybackHint: String {
        t(en: "Video keeps playing when switching tabs or when the app is in the background.", ru: "Видео продолжит играть при переключении на другие вкладки и в фоне приложения.")
    }
    var server: String { t(en: "Server", ru: "Сервер") }
    var aboutProficon: String {
        t(en: "Proficon uses the PortuPrep API on gentechnet.com for translation (OpenAI) and word speech (ElevenLabs).", ru: "Proficon использует API PortuPrep на gentechnet.com для перевода (OpenAI) и озвучки слов (ElevenLabs).")
    }
    var homeTodayPlan: String { t(en: "Today's plan", ru: "Сегодняшний план") }
    var readerTitle: String { t(en: "Reader", ru: "Читалка") }
    var readerHeroTitle: String { t(en: "Read PDFs and tap words", ru: "Читайте PDF и нажимайте на слова") }
    var readerHeroSubtitle: String {
        t(en: "Tap a word to translate and save it to the book folder in your dictionary.", ru: "Нажмите на слово для перевода и сохранения в папку книги в словаре.")
    }
    var openPDF: String { t(en: "Open PDF", ru: "Открыть PDF") }
    var librarySection: String { t(en: "Library", ru: "Библиотека") }
    var addFirstBook: String { t(en: "Add your first book", ru: "Добавьте первую книгу") }
    var openingPDF: String { t(en: "Opening PDF…", ru: "Открываем PDF…") }
    var readerOpenFailed: String { t(en: "Could not open PDF.", ru: "Не удалось открыть PDF.") }
    var fontSize: String { t(en: "Font size", ru: "Размер шрифта") }

    func readerPageProgress(_ current: Int, total: Int) -> String {
        t(en: "Page \(current) of \(total)", ru: "Страница \(current) из \(total)")
    }
    var readerTipOpenPDF: String { t(en: "Tap «Open PDF»", ru: "Нажмите «Открыть PDF»") }
    var readerTipTapWords: String { t(en: "Tap words on the page", ru: "Тапайте по словам на странице") }
    var readerTipSaveTranslation: String { t(en: "Save translations to your dictionary", ru: "Сохраняйте перевод в словарь") }
    var exportFailed: String { t(en: "Export failed", ru: "Не удалось экспортировать") }
    var cardsAndFolders: String { t(en: "cards · folders", ru: "карточек · папок") }
    var cardsOfTotal: String { t(en: "of", ru: "из") }
    var folderRecordingLabel: String { t(en: "Folder recording", ru: "Запись папки") }
    var editCard: String { t(en: "Edit card", ru: "Редактировать") }
    var wordLabel: String { t(en: "Word", ru: "Слово") }
    var translationLabel: String { t(en: "Translation", ru: "Перевод") }
    var exampleLabel: String { t(en: "Example", ru: "Пример") }
    var addImage: String { t(en: "Add image", ru: "Добавить картинку") }
    var removeImage: String { t(en: "Remove image", ru: "Удалить картинку") }
    var noQuizStatsYet: String { t(en: "No quiz stats yet", ru: "Статистики квиза пока нет") }
    var studyMode: String { t(en: "Mode", ru: "Режим") }
    var flashcards: String { t(en: "Cards", ru: "Карточки") }
    var quiz: String { t(en: "Quiz", ru: "Квиз") }
    var wordsTab: String { t(en: "Words", ru: "Слова") }
    var studySubtitle: String { t(en: "Flashcards, quiz, and word progress", ru: "Повторение карточек, квиз и прогресс по словам") }
    var tapToRevealTranslation: String { t(en: "Tap to reveal translation", ru: "Нажмите, чтобы показать перевод") }
    var back: String { t(en: "Back", ru: "Назад") }
    var next: String { t(en: "Next", ru: "Далее") }
    var fromStart: String { t(en: "From start", ru: "Сначала") }
    var noCardsToReview: String { t(en: "No cards to review", ru: "Нет карточек для повторения") }
    var studyEmptyHint: String { t(en: "Add words from Video or Reader, or enable words in the Words tab.", ru: "Добавьте слова из Video или Reader, или включите слова во вкладке Слова.") }
    var studyWordListHint: String { t(en: "Check words to include them in quiz and flashcards.", ru: "Отметьте слова, чтобы включить их в квиз и карточки.") }
    var includedInQuiz: String { t(en: "Included in quiz", ru: "Включено в квиз") }
    var excludedFromQuiz: String { t(en: "Excluded from quiz", ru: "Исключено из квиза") }
    var quizMode: String { t(en: "Quiz mode", ru: "Режим квиза") }
    var multipleChoice: String { t(en: "4 options", ru: "4 варианта") }
    var typedInput: String { t(en: "Typed", ru: "Ввод") }
    var quizDirection: String { t(en: "Direction", ru: "Направление") }
    var notEnoughWords: String { t(en: "Not enough words", ru: "Недостаточно слов") }
    var quizEmptyHint: String { t(en: "Add words or enable them in the Words tab.", ru: "Добавьте слова или включите их во вкладке Слова.") }
    var needFourWords: String { t(en: "Need at least 4 words", ru: "Нужно минимум 4 слова") }
    var needFourWordsHint: String { t(en: "Add more words or switch to typed mode.", ru: "Добавьте больше слов или выберите режим «Ввод».") }
    var sessionComplete: String { t(en: "Session complete", ru: "Сессия завершена") }
    var tryAgain: String { t(en: "Try again", ru: "Ещё раз") }
    var typeRussianAnswer: String { t(en: "Translation in Russian", ru: "Перевод по-русски") }
    var typePortugueseAnswer: String { t(en: "Answer in Portuguese", ru: "Ответ по-португальски") }
    var checkAnswer: String { t(en: "Check", ru: "Проверить") }
    var correctFeedback: String { t(en: "Correct!", ru: "Верно!") }
    var correctPrefix: String { t(en: "Correct", ru: "Верно") }

    func quizShownCount(_ count: Int) -> String {
        t(en: "Shown in quiz: \(count)", ru: "Показано в квизе: \(count)")
    }

    func quizAccuracyPercent(_ percent: Int) -> String {
        t(en: "Accuracy: \(percent)%", ru: "Точность: \(percent)%")
    }

    func studyWordsSelected(_ selected: Int, total: Int) -> String {
        t(en: "\(selected) of \(total) words selected for study", ru: "\(selected) из \(total) слов выбрано для учёбы")
    }

    func quizUsesSelectedWords(_ count: Int) -> String {
        t(en: "Quiz uses \(count) selected words", ru: "В квизе \(count) выбранных слов")
    }

    func quizProgress(_ current: Int, total: Int, score: Int) -> String {
        t(en: "Question \(current) of \(total) · score: \(score)", ru: "Вопрос \(current) из \(total) · верно: \(score)")
    }

    func sessionScore(_ score: Int, total: Int) -> String {
        t(en: "Correct answers: \(score) of \(total)", ru: "Правильных ответов: \(score) из \(total)")
    }

    func incorrectFeedback(_ answer: String) -> String {
        t(en: "Incorrect. Correct: \(answer)", ru: "Неверно. Правильно: \(answer)")
    }

    func expectedAnswer(_ answer: String) -> String {
        t(en: "Expected: \(answer)", ru: "Ожидалось: \(answer)")
    }

    func wordsCount(_ count: Int) -> String {
        t(en: "\(count) words", ru: "\(count) слов")
    }

    func cardsCount(_ cards: Int, folders: Int) -> String {
        t(en: "\(cards) cards · \(folders) folders", ru: "\(cards) карточек · \(folders) папок")
    }

    func filteredCardsCount(_ filtered: Int, total: Int, folders: Int) -> String {
        t(en: "\(filtered) of \(total) cards · \(folders) folders", ru: "\(filtered) из \(total) карточек · \(folders) папок")
    }

    func selectedCount(_ count: Int) -> String {
        t(en: "\(count) selected", ru: "\(count) выбрано")
    }

    func deleteSelected(_ count: Int) -> String {
        t(en: "Delete \(count)", ru: "Удалить \(count)")
    }

    private func t(en: String, ru: String) -> String {
        language == .russian ? ru : en
    }
}
