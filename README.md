# IPdigi

**Website:** [ipdigi.com](https://ipdigi.com)

Open-source IPTV / Xtream Codes / M3U media player built with Flutter. Stream
movies, series and live TV from your own provider with a modern, Netflix-style
browsing experience. TMDB-enriched metadata, EPG, continue-watching, ratings and
watchlists.

> **This is the free, open-source edition.** The account system, paywall,
> licensing and in-app purchases from the commercial build have been removed.
> **Every feature is unlocked** and the app talks to no backend of ours.

## Features

- **Sources:** Xtream Codes accounts and M3U playlists
- **Live TV** with EPG (XMLTV)
- **VOD** movies and series with episode tracking and "up next"
- **TMDB enrichment** (posters, ratings, cast, trailers, certifications). Optional, bring your own API key
- Continue watching, watch history, ratings and watchlists
- Personalized recommendations and related content
- **mpv-based player** (`media_kit`): subtitles, audio tracks, quality cap, screenshots, aspect zoom, black-bar fill
- Adult-content filter
- Light/dark theme and multi-language (i18n)

## Platforms

Android (phone plus **Android TV** / leanback), iOS, macOS, Windows and Linux
from one Flutter codebase.

## Tech stack

| Area | Package | Where it is used |
|------|---------|------------------|
| Video playback | [media_kit](https://pub.dev/packages/media_kit) (libmpv) | The main player. Drives every live TV, movie and series stream in `player_page`. Handles subtitles, audio tracks, quality cap, screenshots and aspect zoom. |
| Trailers | [youtube_player_iframe](https://pub.dev/packages/youtube_player_iframe) plus [flutter_inappwebview](https://pub.dev/packages/flutter_inappwebview) | YouTube trailers only, served through a local loopback wrapper (`trailer_server`). Separate from the media_kit player. |
| State management | [flutter_riverpod](https://pub.dev/packages/flutter_riverpod) | Providers across the whole app |
| Navigation | [go_router](https://pub.dev/packages/go_router) | Shell routing and deep links |
| Local database | [drift](https://pub.dev/packages/drift) over SQLite | Watch history, ratings, watchlists and cached catalog |
| Networking | [dio](https://pub.dev/packages/dio) | Xtream, M3U and TMDB requests |
| Models / codegen | [freezed](https://pub.dev/packages/freezed) plus [json_serializable](https://pub.dev/packages/json_serializable) | Immutable models and JSON |
| Images | [cached_network_image](https://pub.dev/packages/cached_network_image) | Poster and backdrop caching |
| EPG parsing | [xml](https://pub.dev/packages/xml) | XMLTV guide data |
| Search | [fuzzywuzzy](https://pub.dev/packages/fuzzywuzzy) | Fuzzy title matching |
| Desktop window | [window_manager](https://pub.dev/packages/window_manager) | Frameless window on Windows, macOS and Linux |
| Secure storage | [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage) | TMDB key and preferences |

## Getting started

Requires the [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.11+).

```bash
git clone <your-fork-url>
cd ipdigi
flutter pub get
flutter run                 # or: -d macos | windows | linux | <device-id>
```

### Signing (release builds)

No keystores or signing keys are bundled. To ship your own build:

- **Android:** create `android/key.properties` plus a keystore (see the comments
  in `android/app/build.gradle.kts`). Without it, release builds fall back to the
  debug key.
- **iOS / macOS:** set your own `DEVELOPMENT_TEAM` and bundle identifier in Xcode.
  The current value is the placeholder `com.example.ipdigi`.

## Usage

1. Open **Sources** and add an Xtream account (host / username / password) or an
   M3U URL.
2. *(Optional)* Open **Settings > TMDB** and paste a free
   [TMDB API key](https://www.themoviedb.org/settings/api) to enable rich
   metadata (posters, ratings, trailers).
3. Browse **Home / Live / Movies / Series**, play and enjoy.

Everything is stored **locally** (SQLite). No account, no server, no telemetry.

## What was removed from the commercial edition

To keep this edition fully free and self-contained, the following were stripped:

- Account sign-in (Apple / Google)
- Paywall and subscriptions (in-app purchase)
- Remote license and kill-switch checks
- All calls to the `ipdigi.com` backend

There is **no bundled backend**. The app communicates only with your IPTV
provider and optionally with TMDB.

## Contributing

Issues and pull requests are welcome. Please keep all UI text in the i18n/ARB
files. No hardcoded strings.

## License

Licensed under the [GNU GPL-3.0](LICENSE). You may use, study, modify and
redistribute this software. Derivative works must remain open source under the
same license.

The commercial **IPdigi** editions (App Store / Play Store / desktop) are
separate proprietary products of the copyright holder. See
[ipdigi.com](https://ipdigi.com). They are **not** covered by this repository.
