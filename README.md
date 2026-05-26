# YP — YouTube Player Test App

iOS-приложение для тестирования YouTube-воспроизведения через [YouTubePlayerKit](https://github.com/SvenTiigi/YouTubePlayerKit) с синхронизированными субтитрами.

## Быстрый старт

```bash
git clone https://github.com/postal888/YP.git
cd YP
open YouTubePlayerApp/YouTubePlayerApp.xcodeproj
```

В Xcode: дождитесь Resolve Package Versions → укажите Team → Run.

## Возможности

- Воспроизведение YouTube через YouTubePlayerKit (без самопального WKWebView)
- Субтитры: загрузка с устройства через InnerTube API, подсветка текущей строки, тап = seek
- Языки субтитров: PT / EN / RU / ES
- Лог ошибок внизу экрана (копировать / очистить)

## Структура репозитория

```
YP/
└── YouTubePlayerApp/       # iOS-приложение
    └── YouTubePlayerApp/
        ├── YouTubePlayerHolder.swift
        └── Subtitles/
```

## TestFlight

Archive → Distribute App → App Store Connect → Upload.

В App Store Review Notes добавьте ссылку на [YouTube API Terms of Service](https://developers.google.com/youtube/terms/api-services-terms-of-service).
