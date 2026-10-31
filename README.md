# AniScroll

Flutter anime discovery and streaming companion for Android.

## Project structure

```text
lib/
  main.dart
  app.dart
  core/
    theme.dart
  data/
    sample_anime.dart
  models/
    anime.dart
  services/
    anime_api.dart
  widgets/
    anime_widgets.dart
  pages/
    main_shell.dart
    home_page.dart
    discover_page.dart
    schedule_page.dart
    watchlist_page.dart
    profile_page.dart
    anime_detail_page.dart
    player_page.dart
```

Each screen has its own file under `lib/pages/`. Shared UI components are in `lib/widgets/`; data models, API logic, theme and sample data are separated into their own folders.

## Run and build

```bash
flutter pub get
dart format lib
flutter analyze
flutter run
flutter build apk --debug
```

APK output: `build/app/outputs/flutter-apk/app-debug.apk`.

## API

Development API base URL is configured in `lib/services/anime_api.dart`: `http://16.176.100.190:3000`. Search uses `GET /api/search?q=`; detail metadata attempts `GET /api/info?anilistId=`.

## Current implementation notes

This is a first-pass app foundation. Schedule rows are sample entries; watchlist, history and profile selection are currently in-memory. The player page is a UI foundation and does not yet play video. Provider resolution, native HLS/MP4 playback, subtitles, audio tracks, downloads, persistent profiles, notifications, picture-in-picture and live airing data need additional backend and Android integration.

Only stream content you are authorized to access and play.
