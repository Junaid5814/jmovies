import 'package:equatable/equatable.dart';
import '../../core/constants/api_constants.dart';
import 'movie_model.dart';
import 'tv_model.dart';

/// Unified view over a [Movie] or a [TvShow] so the home feed, hero
/// banners, Top 10 rows, and section rows can render mixed content
/// without branching on type everywhere.
///
/// [mediaType] is the canonical discriminator ('movie' or 'tv') and
/// drives navigation to the correct details screen / TMDB endpoint.
class MediaItem extends Equatable {
  final int id;
  final String title;
  final String? posterPath;
  final String? backdropPath;
  final String overview;
  final double voteAverage;
  final String releaseDate; // release_date (movie) or first_air_date (tv)
  final String mediaType; // 'movie' or 'tv'
  final List<int> genreIds;

  const MediaItem({
    required this.id,
    required this.title,
    this.posterPath,
    this.backdropPath,
    this.overview = '',
    this.voteAverage = 0,
    this.releaseDate = '',
    required this.mediaType,
    this.genreIds = const [],
  });

  /// Convenience flag derived from [mediaType]; TV and anime series both
  /// use `'tv'` since anime series are TMDB TV objects.
  bool get isTv => mediaType == 'tv';

  String get fullPosterUrl => posterPath == null || posterPath!.isEmpty
      ? ''
      : '${ApiConstants.tmdbImageBaseUrl}/${ApiConstants.posterSize}$posterPath';

  String get fullBackdropUrl => backdropPath == null || backdropPath!.isEmpty
      ? ''
      : '${ApiConstants.tmdbImageBaseUrl}/${ApiConstants.backdropSize}$backdropPath';

  String get year => releaseDate.isNotEmpty ? releaseDate.split('-').first : '—';

  String get formattedRating => voteAverage > 0 ? voteAverage.toStringAsFixed(1) : 'N/A';

  factory MediaItem.fromMovie(Movie movie) => MediaItem(
        id: movie.id,
        title: movie.title,
        posterPath: movie.posterPath,
        backdropPath: movie.backdropPath,
        overview: movie.overview,
        voteAverage: movie.voteAverage,
        releaseDate: movie.releaseDate,
        mediaType: 'movie',
        genreIds: movie.genreIds,
      );

  factory MediaItem.fromTv(TvShow show) => MediaItem(
        id: show.id,
        title: show.name,
        posterPath: show.posterPath,
        backdropPath: show.backdropPath,
        overview: show.overview,
        voteAverage: show.voteAverage,
        releaseDate: show.firstAirDate,
        mediaType: 'tv',
        genreIds: show.genreIds,
      );

  static List<MediaItem> fromMovies(List<Movie> movies) =>
      movies.map(MediaItem.fromMovie).toList();

  static List<MediaItem> fromTvShows(List<TvShow> shows) =>
      shows.map(MediaItem.fromTv).toList();

  @override
  List<Object?> get props => [id, mediaType];
}
