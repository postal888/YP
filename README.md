# YouTube Player для iOS

Переиспользуемый Swift Package с YouTube-плеером для встраивания в образовательное iOS-приложение.

## Возможности

- SwiftUI-компонент `YouTubePlayerView`
- Управление воспроизведением: play / pause / seek / load
- События для аналитики уроков: прогресс, завершение, ошибки
- Парсинг video ID из URL (`watch`, `youtu.be`, `embed`)
- Inline-воспроизведение на iPhone
- Загрузка и отображение субтитров YouTube (InnerTube API, как в Port_mob)
- Синхронизация текста с текущим временем видео
- iOS 15+

## Структура

```
YP/
├── YouTubePlayer/          # Swift Package (основная библиотека)
│   ├── Sources/YouTubePlayer/
│   └── Tests/
└── YouTubePlayerApp/       # Готовое iOS-приложение для теста на iPhone
    └── YouTubePlayerApp.xcodeproj
```

## Тест на iPhone

Откройте **`YouTubePlayerApp/YouTubePlayerApp.xcodeproj`** в Xcode, укажите Team в Signing и нажмите Run на подключённом iPhone.

Подробная инструкция: [YouTubePlayerApp/README.md](YouTubePlayerApp/README.md).

## Быстрый старт

### 1. Подключить пакет в Xcode

1. Откройте ваш iOS-проект в Xcode.
2. **File → Add Package Dependencies…**
3. Укажите локальный путь: `YouTubePlayer` (папка с `Package.swift`).
4. Добавьте продукт `YouTubePlayer` в target приложения.

### 2. Минимальный пример

```swift
import SwiftUI
import YouTubePlayer

struct LessonScreen: View {
    @StateObject private var player = YouTubePlayerController()

    var body: some View {
        YouTubePlayerView(
            videoID: "ysz5S6PUM-U",
            controller: player
        )
        .frame(height: 220)
        .onAppear {
            player.onEvent = { event in
                switch event {
                case .progress(let current, let duration):
                    print("Progress: \(current)/\(duration)")
                case .ended:
                    print("Lesson completed")
                default:
                    break
                }
            }
        }
    }
}
```

### 3. Загрузка по URL

```swift
if let videoID = YouTubeVideoIDExtractor.extract(from: lesson.youtubeURL) {
    YouTubePlayerView(videoID: videoID, controller: player)
}
```

### 4. Программное управление

```swift
player.play()
player.pause()
player.seek(to: 120)
player.load(videoID: "новый_id", startTime: 0)
```

## Demo-приложение

Готовое приложение для теста: **`YouTubePlayerApp/`**.

1. Откройте `YouTubePlayerApp.xcodeproj` в Xcode.
2. Укажите Team в Signing & Capabilities.
3. Запустите на iPhone или симуляторе.

Пакет `YouTubePlayer` подключён как локальная зависимость автоматически.

## API

| Тип | Назначение |
|-----|------------|
| `YouTubePlayerView` | SwiftUI-view для встраивания |
| `YouTubePlayerController` | Управление и состояние |
| `YouTubePlayerConfiguration` | Настройки плеера |
| `YouTubePlayerEvent` | События для аналитики |
| `YouTubeVideoIDExtractor` | Парсинг ссылок YouTube |
| `YouTubeTranscriptFetcher` | Загрузка субтитров с YouTube |
| `YouTubeSubtitlesView` | Панель субтитров с подсветкой текущей строки |

## Интеграция в образовательный проект

Рекомендуемый паттерн:

1. Модель урока хранит `youtubeURL` или `videoID`.
2. Экран урока создаёт один `YouTubePlayerController` на `@StateObject`.
3. В `onEvent` отправляете прогресс на backend / локальное хранилище.
4. При `ended` отмечаете урок как пройденный.

## Ограничения YouTube

- Требуется интернет-соединение.
- Некоторые видео могут быть недоступны для embed (ограничения автора).
- Для production с большим объёмом видео рассмотрите [YouTube API Services Terms](https://developers.google.com/youtube/terms/api-services-terms-of-service).

## Требования

- Xcode 15+
- iOS 15+
- Swift 5.9+

## Тесты

```bash
cd YouTubePlayer
swift test
```
