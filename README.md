# Jmovies

Premium dark-cinema movie discovery & streaming app built with Flutter.

- **Metadata**: The Movie Database (TMDB) — posters, synopsis, cast, ratings, genres.
- **Streaming**: your own backend/CDN, resolved separately from metadata
  (see `lib/data/services/stream_source_service.dart`). Ships with public
  Apple/Google test streams as a default so the player runs out of the box.

## Brand & Icon Spec

| Token | Value |
|---|---|
| Pure black | `#000000` |
| Deep charcoal | `#121212` / `#1C1C1E` |
| Crimson accent | `#E50914` (gradient to `#9B0710`) |
| Text primary | `#F5F5F7` |
| Text secondary | `#A1A1A6` |
| Gold (ratings) | `#FFC94A` |
| Headline font | Poppins (weights 600–700) |
| Body font | Inter |

Icon concept: a crimson film-reel ring with six sprocket holes around a dark
center hub, with a white "J" stroke cut through the hub — reads as both a
film reel and a monogram at small sizes. Source: `assets/icons/jmovies_logo.svg`.

To generate launcher icons from it:
1. Export the SVG to two PNGs (e.g. via any SVG-to-PNG tool or `rsvg-convert`):
   - `assets/icons/app_icon.png` (512×512, full icon on black background)
   - `assets/icons/app_icon_fg.png` (512×512, transparent background, icon only, for Android adaptive icons)
2. Run `dart run flutter_launcher_icons` (see build steps below).

## Project Structure

```
lib/
  core/
    constants/api_constants.dart     # TMDB movie+TV+OTT endpoints
    theme/app_theme.dart             # Dark cinema ThemeData
  data/
    models/movie_model.dart          # TMDB movie metadata (no video URLs)
    models/tv_model.dart             # TMDB TV/season/episode metadata
    models/media_item.dart           # Unified Movie/TvShow wrapper (mediaType field)
    models/video_source_model.dart   # Stream sources: audio/quality/subs (your backend)
    services/tmdb_api_service.dart
    services/stream_source_service.dart
    repositories/movie_repository.dart
  providers/movie_providers.dart     # Riverpod state: 3-mode home, search, streaming
  screens/
    splash/splash_screen.dart        # ~2s cinematic launch screen, prefetches Home feed
    home/home_screen.dart            # 🎬/📺/⚡ 3-mode pill switcher + all feeds
    details/details_screen.dart      # Unified: movies get Watch Now, TV/anime get
                                      # season chips + episode list
    player/player_screen.dart        # Built-in native player: forMovie() / forEpisode()
    player/watch_webview_screen.dart # Alternative WebView player (not currently wired)
    search/search_screen.dart        # Debounced search + type filter chips
  widgets/
    media_carousel.dart              # MediaHeroCarousel + MediaCarousel (Movie or TV)
    top_10_row.dart                  # Netflix-style row with outline rank numbers
    media_section_row.dart           # Row with optional badge + rating + year
    media_nav.dart                   # Shared "open details for this MediaItem" helper
    genre_chip.dart                  # Generic pill chip (reused for search filters)
  main.dart                          # Launches SplashScreen -> HomeScreen
```

### Content coverage

- **3-mode switch**: `HomeMode` provider (`movies` / `series` / `anime`) drives the
  Home screen; an `IndexedStack` keeps all three feeds alive so switching tabs
  never reloads or re-fetches.
- **Movies tab**: Now in Cinemas, Top 10 Movies Today, Bollywood Blockbusters,
  Hollywood Action Hits.
- **Series & Dramas tab**: Top 10 Global Series, Pakistani Dramas, Netflix
  Originals, Turkish Dramas, Amazon Prime Video, K-Dramas, HBO Max, Hotstar.
- **Anime tab**: Trending Anime This Season, Top Anime Movies.
- **OTT rows** use TMDB's `discover/tv?with_networks=`. This is pure metadata
  discovery (same idea as JustWatch) — it does not grant access to that
  platform's video files.
- **Search**: debounced (400ms) live query across movies + TV, with
  All/Movies/TV Series/Anime/Dramas filter chips. TMDB has no dedicated
  "anime" or "drama" content type, so Anime/Dramas are heuristics over the
  genre IDs TMDB already returns (Animation=16, Drama=18) — see
  `filteredSearchResultsProvider` for the exact logic.

### Splash screen

`SplashScreen` runs for a minimum of ~2 seconds (extending only if the
prefetch is slower, never truncating early), fades/scales the logo in, and
pre-fetches the Movies tab's "Now in Cinemas" feed into the Riverpod cache
so Home opens with data already warm. Prefetch failures are swallowed —
Home's own providers handle their own error states, so a slow/offline
network at launch never hangs or crashes the splash screen.

### Built-in player

`PlayerScreen.forMovie(movie)` / `PlayerScreen.forEpisode(show:, episode:)`
is the active player, wired to both `Watch Now` and episode taps in
`details_screen.dart`. An alternative WebView-based player
(`watch_webview_screen.dart`) is still in the project but not currently
wired to any button — see that file's doc comment if you want to switch.

- Red Netflix-style scrubber, ±10s skip (buttons + double-tap zones),
  current/total runtime readouts.
- Controls auto-hide after 5 seconds of inactivity (within the 4–5s
  target); a single tap anywhere toggles them.
- Multi-server picker ("Server 1/2/3…") pulled from `StreamBundle.sources`
  — **your backend decides what's in that list**; the player has no logic
  that resolves sources on its own from a bare TMDB ID. If the active
  server fails to initialize, it automatically advances to the next one
  and shows "Buffering alternative server…" while it does.
- **Audio**: always starts on `audioTracks[0]` — label that entry
  `"Original Audio (HD)"` in your backend's response. A second option
  (e.g. `"Hindi Dub"`) only appears in the picker when your backend's
  `audio_tracks` array actually includes it; the player never invents an
  audio option that isn't backed by a real URL. Since the base
  `video_player` plugin has no public API for in-stream HLS audio track
  switching, language selection re-points playback at a separate URL per
  `AudioTrack.url` — see Notes below for true in-band switching.
- **Quality picker**: switches between `QualityVariant` URLs (Auto/1080p/
  720p/480p), preserving playback position.
- **Subtitle picker**: lists embedded + external `.vtt`/`.srt` tracks from
  `VideoSource.subtitles`; selection is captured in state — wire an overlay
  renderer (see Notes) to actually paint the text.
- Aspect ratio cycles Fit → Zoom → Stretch.
- 60s timeout on stream resolution and each source-init attempt, to
  tolerate slow networks before falling back/erroring.

## Setup

```bash
# 1. Install Flutter (if needed): https://docs.flutter.dev/get-started/install

# 2. Get dependencies
flutter pub get

# 3. Configure API keys
cp .env.example .env
# then edit .env and paste your TMDB_ACCESS_TOKEN
# (free at https://www.themoviedb.org/settings/api)

# 4. Run in debug mode on a connected device/emulator
flutter run
```

## Wiring Your Streaming Backend

`StreamSourceService` expects, at `STREAM_BACKEND_URL`:

```
GET /api/stream/movie/{movieId}
GET /api/stream/tv/{tvId}/{season}/{episode}
```
```json
{
  "content_id": "123",
  "sources": [
    {
      "id": "cdn-a",
      "label": "1080p",
      "url": "https://cdn.example.com/123/master.m3u8",
      "format": "hls",
      "subtitles": [
        { "language": "English", "url": "https://cdn.example.com/123/en.vtt", "is_embedded": false }
      ],
      "audio_tracks": [
        { "track_id": "original", "language": "Original Audio (HD)", "url": "https://cdn.example.com/123/original/master.m3u8" },
        { "track_id": "hi", "language": "Hindi Dub", "url": "https://cdn.example.com/123/hi/master.m3u8" }
      ],
      "qualities": [
        { "label": "Auto", "url": "https://cdn.example.com/123/master.m3u8" },
        { "label": "1080p", "url": "https://cdn.example.com/123/1080p.m3u8", "bitrate_kbps": 5000 },
        { "label": "720p", "url": "https://cdn.example.com/123/720p.m3u8", "bitrate_kbps": 2800 }
      ]
    },
    { "id": "cdn-b", "label": "720p", "url": "https://cdn2.example.com/123.mp4", "format": "mp4" }
  ]
}
```

Each top-level entry becomes a selectable "server" in the player's source
picker, and the player automatically advances to the next one if the
current source fails to initialize. `audio_tracks[].url` and
`qualities[].url` are optional — omit them if you don't have
per-language/per-bitrate renditions yet. The player always starts on the
first entry in `audio_tracks` (label it `"Original Audio (HD)"`, as above)
and only shows a second language option — e.g. "Hindi Dub" — when your
backend actually includes it in the response; the player never fabricates
a dub option that doesn't resolve to a real URL.

## Building via GitHub Actions (bundled workflow)

`.github/workflows/build.yml` is included in this zip. It regenerates the
`android/` project fresh on every run (`flutter create .`) and injects the
three required permissions into `AndroidManifest.xml`:
`INTERNET`, `ACCESS_NETWORK_STATE`, and `WAKE_LOCK` (needed by
`wakelock_plus` for keeping the screen on during playback). It also pins
every plugin's `compileSdkVersion` to 34, which is what avoids the
"Baklava" (Android 16 preview) SDK mismatch errors that show up when
different plugins in the dependency graph declare different compileSdk
versions. Set the `TMDB_READ_TOKEN` repository secret before running it
(Settings → Secrets and variables → Actions) — see "Wiring Your Streaming
Backend" below for the TMDB token itself.

If you're building locally instead (not via this workflow), you'll need
to add those same three permissions to your own
`android/app/src/main/AndroidManifest.xml` once `android/` exists, since
this zip ships Dart/Flutter source only — no native `android/`/`ios/`
project directories are pre-generated.

## Build a Release APK

```bash
# 1. Clean any previous build artifacts
flutter clean
flutter pub get

# 2. (Optional but recommended) generate launcher icons from the SVG-derived PNGs
dart run flutter_launcher_icons

# 3. Create/verify a signing key (first time only)
keytool -genkey -v -keystore ~/jmovies-release-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias jmovies

# 4. Configure signing — create android/key.properties:
#    storePassword=YOUR_STORE_PASSWORD
#    keyPassword=YOUR_KEY_PASSWORD
#    keyAlias=jmovies
#    storeFile=/absolute/path/to/jmovies-release-key.jks
# and reference it from android/app/build.gradle's signingConfigs.

# 5. Build the release APK (split per ABI keeps file size down)
flutter build apk --release --split-per-abi

# Output:
# build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk
# build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
# build/app/outputs/flutter-apk/app-x86_64-release.apk

# Or a single universal APK instead:
flutter build apk --release

# Or an .aab for Play Store submission:
flutter build appbundle --release
# -> build/app/outputs/bundle/release/app-release.aab
```

## Notes

- The player screen uses `video_player` directly with fully custom controls
  (no `chewie` UI layer). `video_player` handles HLS and MP4 well; DASH
  support is device-dependent.
- **In-band audio track switching**: the base `video_player` plugin doesn't
  expose ExoPlayer's track-selection API. If you need true in-stream
  multi-audio (rather than separate per-language URLs), `better_player_plus`
  is the path — it wraps ExoPlayer on Android and surfaces track selection
  directly. Swapping it in only touches `player_screen.dart`; the
  `VideoSource`/`AudioTrack` models already carry what it needs.
- Subtitle rendering: `VideoSource.subtitles` selection is wired into the
  player's state; to actually paint `.vtt`/`.srt` text on screen, add a
  renderer package (e.g. `subtitle_wrapper`) in the subtitle handler in
  `player_screen.dart`.
- Remember to add `.env` and `android/key.properties` to `.gitignore`.
