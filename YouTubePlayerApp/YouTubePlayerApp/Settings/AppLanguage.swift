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
    var aboutPortuLearn: String {
        t(en: "PortuLearn uses the PortuPrep API on gentechnet.com for translation (OpenAI) and word speech (ElevenLabs).", ru: "PortuLearn использует API PortuPrep на gentechnet.com для перевода (OpenAI) и озвучки слов (ElevenLabs).")
    }
    var exportFailed: String { t(en: "Export failed", ru: "Не удалось экспортировать") }
    var cardsAndFolders: String { t(en: "cards · folders", ru: "карточек · папок") }
    var cardsOfTotal: String { t(en: "of", ru: "из") }
    var folderRecordingLabel: String { t(en: "Folder recording", ru: "Запись папки") }

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
