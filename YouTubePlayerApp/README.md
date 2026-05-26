# YouTube Player App

Отдельное iOS-приложение для тестирования YouTube-плеера на iPhone.

## Запуск на iPhone

1. Скопируйте весь репозиторий `YP` на Mac (или откройте через git clone).
2. Откройте **`YouTubePlayerApp/YouTubePlayerApp.xcodeproj`** в Xcode.
3. В Xcode выберите target **YouTubePlayerApp**.
4. Перейдите в **Signing & Capabilities** и укажите ваш **Team** (Apple ID / Developer account).
5. Подключите iPhone по USB (или используйте wireless debugging).
6. Выберите ваш iPhone в списке устройств сверху.
7. Нажмите **Run** (⌘R).

Приложение установится на телефон и откроется автоматически.

## Что внутри

- Поле для вставки YouTube URL или video ID
- Встроенный плеер с кнопками Play / Pause / ±10 сек
- **Субтитры** с синхронизацией по времени видео (как в Port_mob)
- Выбор языка субтитров: PT / EN / RU / ES
- Тап по строке субтитров — перемотка к этому моменту
- **Лог ошибок** внизу экрана с кнопкой «Копировать всё»
- Отображение прогресса просмотра

## Структура

```
YouTubePlayerApp/
├── YouTubePlayerApp.xcodeproj   ← открывать это
└── YouTubePlayerApp/
    ├── YouTubePlayerApp.swift
    ├── ContentView.swift
    └── LessonPlayerView.swift

YouTubePlayer/                   ← локальный Swift Package (подключён автоматически)
```

## Если Xcode не находит пакет

Убедитесь, что папки `YouTubePlayerApp` и `YouTubePlayer` лежат рядом:

```
YP/
├── YouTubePlayer/
└── YouTubePlayerApp/
```

Затем в Xcode: **File → Packages → Reset Package Caches**.

## Бесплатная установка без платного Developer аккаунта

Можно установить на свой iPhone через бесплатный Apple ID:

1. Xcode → Settings → Accounts → добавьте Apple ID.
2. В Signing выберите этот Team.
3. На iPhone: Settings → General → VPN & Device Management → доверьте developer.

Приложение будет работать ~7 дней, потом нужно переустановить через Xcode.

## Bundle ID

По умолчанию: `com.yp.youtubeplayer.app`

Если конфликтует с другим приложением, измените **Product Bundle Identifier** в настройках target.
