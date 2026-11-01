# AniScroll

Flutter anime discovery and streaming companion for Android (minimum Android 10 / API 29).

## Current app structure

- `lib/models/anime.dart`: normalized AniList/MAL-style anime metadata model.
- `lib/services/anime_api.dart`: HTTP API client for search, seasonal catalogue, info, episodes, server lookup, watch resolution, health, and selected MAL endpoints.
- `lib/pages/home_page.dart`: live seasonal catalogue, featured anime, continue-watching rail.
- `lib/pages/discover_page.dart`: debounced API search with explicit loading/error/empty states.
- `lib/pages/schedule_page.dart`: displays only confirmed `nextAiringEpisode` timestamps returned by the API; it does not invent airing times.
- `lib/pages/anime_detail_page.dart`: metadata and episode-list requests.
- `lib/pages/player_page.dart`: video_player-based player, server selection, sub/dub server-type toggle, seek, speed and fullscreen controls.
- `lib/pages/main_shell.dart`: Home, Discover, Schedule, Watchlist and Profile navigation.

## API

Base URL: `http://16.176.100.190:3000` (configured in `lib/services/anime_api.dart`).

The client uses the documented routes:
- `GET /api/search?q=`
- `GET /api/info`
- `GET /api/episodes`
- `GET /api/servers`
- `GET /api/watch/{source}/{id}/{ep}/{type}`
- `GET /api/health`
- `GET /api/anilist/season`
- `GET /api/anilist/top-banners`
- selected `/api/mal/anime/{id}...` routes

The client accepts HTTP 200 and documented partial-success HTTP 206 responses and surfaces API error/detail messages. Exact response fields vary by provider; unsupported or missing fields are handled with empty/error states rather than fabricated metadata.

## Run and validate in GitHub Codespaces

After pulling the latest `main`:

```bash
git pull --ff-only origin main
flutter pub get
dart format lib
flutter analyze
flutter run
```

Build a debug APK:

```bash
flutter build apk --debug
```

APK output: `build/app/outputs/flutter-apk/app-debug.apk`.

## Release signing

Release builds must use a private signing key. Create `android/key.properties` locally (do not commit it) with:

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=YOUR_KEY_ALIAS
storeFile=../app-upload-key.jks
```

Place the keystore at the path specified by `storeFile`. The release Gradle task intentionally does not fall back to the debug signing key; without this file, the generated release APK is unsigned and is not ready for distribution. Keep a secure backup of the keystore and passwords.

The streaming API currently defaults to the HTTP endpoint configured in `lib/services/anime_api.dart`. Production deployment should provide an HTTPS endpoint using:

```bash
flutter build apk --release --dart-define=ANISCROLL_API_BASE_URL=https://your-api-domain
```

Do not ship the app against an unencrypted HTTP API.

## Current limitations

The API integration is a first end-to-end pass and must be validated against the live API's exact JSON response shapes. The current app keeps watchlist, history and profile selection in memory; it does not yet persist four separate profiles. The player uses Flutter's `video_player`: external subtitle/audio track selection, subtitle styling, picture-in-picture, HLS quality selection, previews, reliable intro/outro skip markers, auto-next countdown, and downloads are not implemented. Download functionality must only be added for streams the provider explicitly authorizes. Notifications and persistent per-profile subtitle/audio preferences also remain to be implemented.

Only use sources and streams you are authorized to access and play.
