# YouTube Player App

Тестовое iOS-приложение с YouTube-плеером на [YouTubePlayerKit](https://github.com/SvenTiigi/YouTubePlayerKit) и субтитрами с устройства.

## Запуск

1. Клонируйте репозиторий и откройте **`YouTubePlayerApp/YouTubePlayerApp.xcodeproj`** в Xcode.
2. Дождитесь загрузки SPM-зависимости **YouTubePlayerKit** (File → Packages → Resolve Package Versions).
3. Укажите Team в Signing & Capabilities.
4. Run на iPhone или симуляторе.

## TestFlight / Archive

1. Product → Clean Build Folder (⇧⌘K)
2. Выберите **Any iOS Device (arm64)**
3. Product → Archive → Distribute App → TestFlight

## Структура

```
YouTubePlayerApp/
├── YouTubePlayerApp.xcodeproj
└── YouTubePlayerApp/
    ├── ContentView.swift
    ├── LessonPlayerView.swift
    ├── YouTubePlayerHolder.swift   ← обёртка над YouTubePlayerKit
    ├── Subtitles/                  ← загрузка и UI субтитров
    └── ...
```

Bundle ID: `com.yp.youtubeplayer.app`
