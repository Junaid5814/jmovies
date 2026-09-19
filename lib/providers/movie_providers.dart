import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/movie_model.dart';
import '../data/models/tv_model.dart';
import '../data/models/media_item.dart';
import '../data/models/video_source_model.dart';
import '../data/repositories/movie_repository.dart';
import '../core/constants/api_constants.dart';

final movieRepositoryProvider = Provider<MovieRepository>((ref) {
  return MovieRepository();
});

/// Top-level 3-mode switch driving the Home screen feed.
enum HomeMode { movies, series, anime }

final homeModeProvider = StateProvider<HomeMode>((ref) => HomeMode.movies);

// =========================================================================
// Movies tab
// =========================================================================

final nowPlayingInCinemaProvider = FutureProvider<List<Movie>>((ref) {
  return ref.watch(movieRepositoryProvider).getNowPlayingInCinema();
});

final top10MoviesTodayProvider = FutureProvider<List<Movie>>((ref) {
  return ref.watch(movieRepositoryProvider).getTop10MoviesToday();
});

final bollywoodHitsProvider = FutureProvider<List<Movie>>((ref) {
  return ref.watch(movieRepositoryProvider).getBollywoodHits();
});

final hollywoodActionHitsProvider = FutureProvider<List<Movie>>((ref) {
  return ref.watch(movieRepositoryProvider).getHollywoodActionHits();
});

/// Hero banner source for the Movies tab.
final moviesHeroProvider = FutureProvider<List<MediaItem>>((ref) async {
  final movies = await ref.watch(nowPlayingInCinemaProvider.future);
  return MediaItem.fromMovies(movies);
});

// =========================================================================
// Series & Dramas tab
// =========================================================================

final top10SeriesTodayProvider = FutureProvider<List<TvShow>>((ref) {
  return ref.watch(movieRepositoryProvider).getTop10SeriesToday();
});

final pakistaniDramasProvider = FutureProvider<List<TvShow>>((ref) {
  return ref.watch(movieRepositoryProvider).getPakistaniDramas();
});

final turkishDramasProvider = FutureProvider<List<TvShow>>((ref) {
  return ref.watch(movieRepositoryProvider).getTurkishDramas();
});

final kDramaProvider = FutureProvider<List<TvShow>>((ref) {
  return ref.watch(movieRepositoryProvider).getKDramas();
});

final netflixOriginalsProvider = FutureProvider<List<TvShow>>((ref) {
  return ref.watch(movieRepositoryProvider).getNetflixOriginals();
});

final primeVideoProvider = FutureProvider<List<TvShow>>((ref) {
  return ref.watch(movieRepositoryProvider).getAmazonPrimeVideo();
});

final hboMaxProvider = FutureProvider<List<TvShow>>((ref) {
  return ref.watch(movieRepositoryProvider).getHboMaxExclusives();
});

final disneyHotstarProvider = FutureProvider<List<TvShow>>((ref) {
  return ref.watch(movieRepositoryProvider).getDisneyHotstar();
});

/// Hero banner source for the Series & Dramas tab.
final seriesHeroProvider = FutureProvider<List<MediaItem>>((ref) async {
  final shows = await ref.watch(top10SeriesTodayProvider.future);
  return MediaItem.fromTvShows(shows);
});

// =========================================================================
// Anime tab
// =========================================================================

final trendingAnimeProvider = FutureProvider<List<TvShow>>((ref) {
  return ref.watch(movieRepositoryProvider).getTrendingAnime();
});

final animeMoviesProvider = FutureProvider<List<Movie>>((ref) {
  return ref.watch(movieRepositoryProvider).getAnimeMovies();
});

/// Hero banner source for the Anime tab.
final animeHeroProvider = FutureProvider<List<MediaItem>>((ref) async {
  final shows = await ref.watch(trendingAnimeProvider.future);
  return MediaItem.fromTvShows(shows);
});

// =========================================================================
// Details screens
// =========================================================================

final movieDetailsProvider =
    FutureProvider.family<Movie, int>((ref, movieId) {
  return ref.watch(movieRepositoryProvider).getMovieDetails(movieId);
});

final tvDetailsProvider = FutureProvider.family<TvShow, int>((ref, tvId) {
  return ref.watch(movieRepositoryProvider).getTvDetails(tvId);
});

/// Currently selected season number on the Details screen (TV/anime), per TV ID.
final selectedSeasonProvider =
    StateProvider.family<int, int>((ref, tvId) => 1);

final seasonDetailProvider = FutureProvider.family<SeasonDetail, ({int tvId, int season})>(
  (ref, args) {
    return ref
        .watch(movieRepositoryProvider)
        .getSeasonDetail(args.tvId, args.season);
  },
);

// =========================================================================
// Streaming
// =========================================================================

final movieStreamBundleProvider =
    FutureProvider.family<StreamBundle, int>((ref, movieId) {
  return ref.watch(movieRepositoryProvider).getMovieStreamBundle(movieId);
});

final episodeStreamBundleProvider = FutureProvider.family<StreamBundle,
    ({int tvId, int season, int episode})>((ref, args) {
  return ref
      .watch(movieRepositoryProvider)
      .getEpisodeStreamBundle(args.tvId, args.season, args.episode);
});

// =========================================================================
// Search screen
// =========================================================================

/// Type/category filter chips: [All, Movies, TV Series, Anime, Dramas].
enum SearchFilter { all, movies, tvSeries, anime, dramas }

final searchQueryProvider = StateProvider<String>((ref) => '');
final searchFilterProvider = StateProvider<SearchFilter>((ref) => SearchFilter.all);

/// Unified search across movies and TV, merged into [MediaItem]s. The UI
/// applies [searchFilterProvider] on top of this combined list rather than
/// re-querying TMDB per filter, so switching chips is instant.
final searchResultsProvider = FutureProvider<List<MediaItem>>((ref) async {
  final query = ref.watch(searchQueryProvider).trim();
  if (query.isEmpty) return [];

  final repo = ref.watch(movieRepositoryProvider);
  final results = await Future.wait([repo.searchMovies(query), repo.searchTv(query)]);
  final movies = results[0] as List<Movie>;
  final shows = results[1] as List<TvShow>;

  return [...MediaItem.fromMovies(movies), ...MediaItem.fromTvShows(shows)];
});

/// [searchResultsProvider] filtered by the active [SearchFilter].
///
/// TMDB has no dedicated "anime" or "drama" content type, so these two
/// filters are heuristics over the genre IDs TMDB already returns:
/// Anime = has the Animation genre (16); Dramas = has the Drama genre (18).
/// Both apply across movies and TV. "TV Series" excludes Animation so it
/// doesn't overlap with the Anime bucket.
final filteredSearchResultsProvider = Provider<AsyncValue<List<MediaItem>>>((ref) {
  final resultsAsync = ref.watch(searchResultsProvider);
  final filter = ref.watch(searchFilterProvider);

  return resultsAsync.whenData((items) {
    switch (filter) {
      case SearchFilter.all:
        return items;
      case SearchFilter.movies:
        return items.where((i) => !i.isTv).toList();
      case SearchFilter.tvSeries:
        return items.where((i) => i.isTv && !i.genreIds.contains(ApiConstants.genreAnimation)).toList();
      case SearchFilter.anime:
        return items.where((i) => i.genreIds.contains(ApiConstants.genreAnimation)).toList();
      case SearchFilter.dramas:
        return items.where((i) => i.genreIds.contains(ApiConstants.genreDrama)).toList();
    }
  });
});

// =========================================================================
// Player: which source (server) is currently selected
// =========================================================================

final selectedSourceIndexProvider = StateProvider<int>((ref) => 0);
