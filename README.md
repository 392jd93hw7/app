# AniScroll

AniScroll is a Flutter Android anime discovery and streaming companion.

## Included
- Dark anime-inspired interface and featured content
- Home, Discover, Schedule, Watchlist and Profile navigation
- Search UI connected to `GET /api/search?q=`
- Anime detail and episode-list foundations
- Player screen foundation
- In-memory watchlist, history and local profile switching
- Android internet permission and development cleartext HTTP access

## Run
```bash
flutter pub get
flutter analyze
flutter run
```

## Build APK
```bash
flutter build apk --debug
```
APK output: `build/app/outputs/flutter-apk/app-debug.apk`

## API
Configured base URL in `lib/main.dart`: `http://16.176.100.190:3000`.
Search uses `GET /api/search?q=`; detail metadata attempts `GET /api/info?anilistId=`.

## Integration status
This is a first-pass app foundation, not a finished streaming release. Schedule rows are sample entries. Watchlist, history and profile selection are in-memory and reset after restart. The player screen is a UI foundation and does not yet play video. Real episode/provider resolution, native HLS/MP4 playback, subtitles, audio tracks, downloads, persistent profiles, notifications, picture-in-picture and live airing data still require backend and Android integrations.

Only stream content you are authorized to access and play.
