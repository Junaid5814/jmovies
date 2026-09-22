import 'package:dio/dio.dart';

import '../../core/config/app_config.dart';
import '../../core/constants/api_constants.dart';
import '../models/movie_model.dart';
import '../models/tv_model.dart';
/// Thin wrapper around TMDB's REST API. This is the ONLY class allowed to
/// know about TMDB endpoints — screens/providers should go through
/// MovieRepository instead of calling this directly.
///
/// Auth uses the TMDB v4 Read Access Token via `Authorization: Bearer`,
/// supplied securely at build time through the TMDB_ACCESS_TOKEN
/// dart-define value. The token is never hardcoded in source code.
class TmdbApiService {
  final Dio _dio;

  TmdbApiService()
      : _dio = Dio(
          BaseOptions(
            baseUrl: ApiConstants.tmdbBaseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
            headers: {
              'Authorization': 'Bearer ${AppConfig.tmdbAccessToken}',
              'Content-Type': 'application/json',
            },
          ),
        );

  // =======================================================================
  // Movies tab
  // =======================================================================

  Future<List<Movie>> getNowPlayingInCinema() =>
      _fetchMovieList(ApiConstants.nowPlayingInCinema);

  Future<List<Movie>> getTop10MoviesToday() async {
    final movies = await _fetchMovieList(ApiConstants.trendingMoviesToday);
    return movies.take(10).toList();
  }

  Future<List<Movie>> getBollywoodHits() =>
      _fetchMovieList(ApiConstants.bollywoodHits);

  Future<List<Movie>> getHollywoodActionHits() =>
      _fetchMovieList(ApiConstants.hollywoodActionHits);

  // --- Movies: shared (details, search, genre filter chips) ---

  Future<List<Movie>> fetchMoviesByGenre(int genreId) =>
      _fetchMovieList(ApiConstants.discoverMoviesByGenre(genreId));

  Future<List<Movie>> searchMovies(String query) {
    if (query.trim().isEmpty) return Future.value([]);
    return _fetchMovieList(ApiConstants.searchMovies(query));
  }

  Future<Movie> fetchMovieDetails(int movieId) async {
    final res = await _dio.get(ApiConstants.movieDetails(movieId));
    return Movie.fromJson(res.data as Map<String, dynamic>);
  }

  // =======================================================================
  // Series & Dramas tab
  // =======================================================================

  Future<List<TvShow>> getTop10SeriesToday() async {
    final shows = await _fetchTvList(ApiConstants.trendingSeriesToday);
    return shows.take(10).toList();
  }

  Future<List<TvShow>> getPakistaniDramas() =>
      _fetchTvList(ApiConstants.pakistaniDramas);

  Future<List<TvShow>> getTurkishDramas() =>
      _fetchTvList(ApiConstants.turkishDramas);

  Future<List<TvShow>> getKDramas() => _fetchTvList(ApiConstants.kDramas);

  Future<List<TvShow>> getNetflixOriginals() =>
      _fetchTvList(ApiConstants.discoverTvByNetwork(ApiConstants.networkNetflix));

  Future<List<TvShow>> getAmazonPrimeVideo() => _fetchTvList(
      ApiConstants.discoverTvByNetwork(ApiConstants.networkAmazonPrime));

  Future<List<TvShow>> getHboMaxExclusives() =>
      _fetchTvList(ApiConstants.discoverTvByNetwork(ApiConstants.networkHboMax));

  Future<List<TvShow>> getDisneyHotstar() => _fetchTvList(
      ApiConstants.discoverTvByNetwork(ApiConstants.networkDisneyHotstar));

  // =======================================================================
  // Anime tab
  // =======================================================================

  Future<List<TvShow>> getTrendingAnime() =>
      _fetchTvList(ApiConstants.trendingAnime);

  Future<List<Movie>> getAnimeMovies() =>
      _fetchMovieList(ApiConstants.animeMovies);

  // --- TV: shared (details, season/episode, search) ---

  Future<TvShow> fetchTvDetails(int tvId) async {
    final res = await _dio.get(ApiConstants.tvDetails(tvId));
    return TvShow.fromJson(res.data as Map<String, dynamic>);
  }

  Future<SeasonDetail> fetchSeasonDetail(int tvId, int seasonNumber) async {
    try {
      final res = await _dio.get(ApiConstants.tvSeason(tvId, seasonNumber));
      return SeasonDetail.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw TmdbException(
        'Failed to load season $seasonNumber: ${e.response?.statusCode ?? e.message}',
      );
    }
  }

  Future<List<TvShow>> searchTv(String query) {
    if (query.trim().isEmpty) return Future.value([]);
    return _fetchTvList(ApiConstants.searchTv(query));
  }

  // =======================================================================
  // Shared helpers
  // =======================================================================

  Future<List<Movie>> _fetchMovieList(String endpoint) async {
    try {
      final res = await _dio.get(endpoint);
      return (res.data['results'] as List<dynamic>)
          .map((json) => Movie.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw TmdbException(
        'Failed to load movies: ${e.response?.statusCode ?? e.message}',
      );
    }
  }

  Future<List<TvShow>> _fetchTvList(String endpoint) async {
    try {
      final res = await _dio.get(endpoint);
      return (res.data['results'] as List<dynamic>)
          .map((json) => TvShow.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw TmdbException(
        'Failed to load TV shows: ${e.response?.statusCode ?? e.message}',
      );
    }
  }
}

class TmdbException implements Exception {
  final String message;
  TmdbException(this.message);
  @override
  String toString() => message;
}
