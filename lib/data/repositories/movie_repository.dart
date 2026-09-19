import '../models/movie_model.dart';
import '../models/tv_model.dart';
import '../models/video_source_model.dart';
import '../services/tmdb_api_service.dart';
import '../services/stream_source_service.dart';

/// Single entry point the UI/providers talk to. Keeps the metadata source
/// (TMDB) and the streaming source (your backend) cleanly separated while
/// presenting one simple API to the rest of the app.
class MovieRepository {
  final TmdbApiService _tmdb;
  final StreamSourceService _streams;

  MovieRepository({TmdbApiService? tmdb, StreamSourceService? streams})
      : _tmdb = tmdb ?? TmdbApiService(),
        _streams = streams ?? StreamSourceService();

  // --- Movies tab ---
  Future<List<Movie>> getNowPlayingInCinema() => _tmdb.getNowPlayingInCinema();
  Future<List<Movie>> getTop10MoviesToday() => _tmdb.getTop10MoviesToday();
  Future<List<Movie>> getBollywoodHits() => _tmdb.getBollywoodHits();
  Future<List<Movie>> getHollywoodActionHits() => _tmdb.getHollywoodActionHits();

  // --- Movies: shared ---
  Future<List<Movie>> getMoviesByGenre(int genreId) =>
      _tmdb.fetchMoviesByGenre(genreId);
  Future<List<Movie>> searchMovies(String query) => _tmdb.searchMovies(query);
  Future<Movie> getMovieDetails(int movieId) =>
      _tmdb.fetchMovieDetails(movieId);
  Future<StreamBundle> getMovieStreamBundle(int movieId) =>
      _streams.fetchMovieStreamBundle(movieId);

  // --- Series & Dramas tab ---
  Future<List<TvShow>> getTop10SeriesToday() => _tmdb.getTop10SeriesToday();
  Future<List<TvShow>> getPakistaniDramas() => _tmdb.getPakistaniDramas();
  Future<List<TvShow>> getTurkishDramas() => _tmdb.getTurkishDramas();
  Future<List<TvShow>> getKDramas() => _tmdb.getKDramas();
  Future<List<TvShow>> getNetflixOriginals() => _tmdb.getNetflixOriginals();
  Future<List<TvShow>> getAmazonPrimeVideo() => _tmdb.getAmazonPrimeVideo();
  Future<List<TvShow>> getHboMaxExclusives() => _tmdb.getHboMaxExclusives();
  Future<List<TvShow>> getDisneyHotstar() => _tmdb.getDisneyHotstar();

  // --- Anime tab ---
  Future<List<TvShow>> getTrendingAnime() => _tmdb.getTrendingAnime();
  Future<List<Movie>> getAnimeMovies() => _tmdb.getAnimeMovies();

  // --- TV: shared ---
  Future<TvShow> getTvDetails(int tvId) => _tmdb.fetchTvDetails(tvId);
  Future<SeasonDetail> getSeasonDetail(int tvId, int seasonNumber) =>
      _tmdb.fetchSeasonDetail(tvId, seasonNumber);
  Future<List<TvShow>> searchTv(String query) => _tmdb.searchTv(query);
  Future<StreamBundle> getEpisodeStreamBundle(
    int tvId,
    int seasonNumber,
    int episodeNumber,
  ) =>
      _streams.fetchEpisodeStreamBundle(tvId, seasonNumber, episodeNumber);
}
