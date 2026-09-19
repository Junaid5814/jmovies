/// TMDB is used ONLY for legal metadata: posters, synopsis, cast, ratings,
/// episode lists. It is never used to source video files — TMDB does not
/// provide those.
class ApiConstants {
  ApiConstants._();

  static const String tmdbBaseUrl = 'https://api.themoviedb.org/3';
  static const String tmdbImageBaseUrl = 'https://image.tmdb.org/t/p';

  static const String posterSize = 'w500';
  static const String backdropSize = 'w1280';
  static const String stillSize = 'w300'; // episode thumbnails

  // --- Movies: home feed ---
  static const String nowPlayingInCinema = '/movie/now_playing?region=US';
  static const String trendingMoviesToday = '/trending/movie/day';
  static const String bollywoodHits =
      '/discover/movie?with_original_language=hi&sort_by=popularity.desc';
  static const String hollywoodActionHits =
      '/discover/movie?with_genres=$genreAction&with_original_language=en&sort_by=popularity.desc';

  // --- Movies: shared (details, search, genre filter chips) ---
  static String discoverMoviesByGenre(int genreId) =>
      '/discover/movie?with_genres=$genreId';
  static String searchMovies(String query) =>
      '/search/movie?query=${Uri.encodeComponent(query)}';
  static String movieDetails(int id) =>
      '/movie/$id?append_to_response=credits';

  // --- Series & Dramas: home feed ---
  static const String trendingSeriesToday = '/trending/tv/day';
  static const String pakistaniDramas =
      '/discover/tv?with_original_language=ur&sort_by=popularity.desc';
  static const String turkishDramas =
      '/discover/tv?with_original_language=tr&sort_by=popularity.desc';
  static const String kDramas =
      '/discover/tv?with_original_language=ko&sort_by=popularity.desc';

  // --- OTT network rows (TMDB discover with_networks) ---
  // Network IDs are TMDB's own public catalog IDs, not tied to any
  // license — this is metadata discovery only (same idea as JustWatch).
  static const int networkNetflix = 213;
  static const int networkAmazonPrime = 1024;
  static const int networkHboMax = 49;
  static const int networkDisneyHotstar = 2739;

  static String discoverTvByNetwork(int networkId) =>
      '/discover/tv?with_networks=$networkId&sort_by=popularity.desc';

  // --- Anime (TMDB has no dedicated "anime" type: genre 16 + Japanese) ---
  static const String trendingAnime =
      '/discover/tv?with_genres=$genreAnimation&with_original_language=ja&sort_by=popularity.desc';
  static const String animeMovies =
      '/discover/movie?with_genres=$genreAnimation&with_original_language=ja&sort_by=popularity.desc';

  // --- TV: shared (details, season/episode, search) ---
  static String tvDetails(int id) => '/tv/$id?append_to_response=credits';
  static String tvSeason(int tvId, int seasonNumber) =>
      '/tv/$tvId/season/$seasonNumber';
  static String searchTv(String query) =>
      '/search/tv?query=${Uri.encodeComponent(query)}';

  // TMDB genre IDs (standard, public)
  static const int genreAction = 28;
  static const int genreComedy = 35;
  static const int genreDrama = 18;
  static const int genreSciFi = 878;
  static const int genreHorror = 27;
  static const int genreAnimation = 16;
}

/// Builds the URL for the in-app WebView player. Points at YOUR OWN hosted
/// player page (e.g. a page on your backend that resolves the ID server-side
/// and renders a video element/player) — configured via WEBVIEW_PLAYER_BASE_URL
/// in .env. This is intentionally NOT pointed at any third-party embed site.
class WebviewPlayerUrls {
  WebviewPlayerUrls._();

  /// Falls back to a placeholder domain if the env var isn't set, so the
  /// app is still runnable — replace with your real player host.
  static String _base(String? envBaseUrl) =>
      (envBaseUrl == null || envBaseUrl.isEmpty)
          ? 'https://your-backend.example.com/player'
          : envBaseUrl;

  static String forMovie(String? envBaseUrl, int tmdbId) =>
      '${_base(envBaseUrl)}/movie/$tmdbId';

  static String forEpisode(
    String? envBaseUrl,
    int tmdbId,
    int seasonNumber,
    int episodeNumber,
  ) =>
      '${_base(envBaseUrl)}/tv/$tmdbId/$seasonNumber/$episodeNumber';
}

/// Placeholder / sample video sources used ONLY as defaults until a title
/// is wired to your own backend's stream URL.
class SampleStreams {
  SampleStreams._();

  static const String hlsAppleTest =
      'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8';

  static const String mp4BigBuckBunny =
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';

  static const String mp4Sintel =
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4';
}
