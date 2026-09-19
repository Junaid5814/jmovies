import 'package:equatable/equatable.dart';
import '../../core/constants/api_constants.dart';
import 'movie_model.dart';

/// Pure TMDB metadata for a TV/web series. Mirrors [Movie] but with
/// series-specific fields (seasons, episode counts). No video URLs here.
class TvShow extends Equatable {
  final int id;
  final String name;
  final String overview;
  final String? posterPath;
  final String? backdropPath;
  final double voteAverage;
  final String firstAirDate;
  final List<int> genreIds;
  final List<CastMember> cast;
  final int numberOfSeasons;
  final List<SeasonSummary> seasons;

  const TvShow({
    required this.id,
    required this.name,
    required this.overview,
    this.posterPath,
    this.backdropPath,
    this.voteAverage = 0,
    this.firstAirDate = '',
    this.genreIds = const [],
    this.cast = const [],
    this.numberOfSeasons = 0,
    this.seasons = const [],
  });

  String get posterUrl => posterPath == null
      ? ''
      : '${ApiConstants.tmdbImageBaseUrl}/${ApiConstants.posterSize}$posterPath';

  String get backdropUrl => backdropPath == null
      ? ''
      : '${ApiConstants.tmdbImageBaseUrl}/${ApiConstants.backdropSize}$backdropPath';

  String get firstAirYear =>
      firstAirDate.isNotEmpty ? firstAirDate.split('-').first : '—';

  factory TvShow.fromJson(Map<String, dynamic> json) {
    final creditsJson = json['credits']?['cast'] as List<dynamic>?;
    final seasonsJson = json['seasons'] as List<dynamic>?;
    return TvShow(
      id: json['id'] as int,
      name: (json['name'] ?? '') as String,
      overview: (json['overview'] ?? '') as String,
      posterPath: json['poster_path'] as String?,
      backdropPath: json['backdrop_path'] as String?,
      voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0,
      firstAirDate: (json['first_air_date'] ?? '') as String,
      genreIds: (json['genre_ids'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          const [],
      numberOfSeasons: (json['number_of_seasons'] as int?) ?? 0,
      seasons: seasonsJson == null
          ? const []
          : seasonsJson
              .map((s) => SeasonSummary.fromJson(s as Map<String, dynamic>))
              .where((s) => s.seasonNumber > 0) // skip "Specials" (season 0)
              .toList(),
      cast: creditsJson == null
          ? const []
          : creditsJson
              .take(12)
              .map((c) => CastMember.fromJson(c as Map<String, dynamic>))
              .toList(),
    );
  }

  @override
  List<Object?> get props => [id];
}

/// Lightweight season info as returned inline with TV details
/// (used to populate the season dropdown without a extra call).
class SeasonSummary extends Equatable {
  final int seasonNumber;
  final String name;
  final int episodeCount;
  final String? posterPath;

  const SeasonSummary({
    required this.seasonNumber,
    required this.name,
    required this.episodeCount,
    this.posterPath,
  });

  factory SeasonSummary.fromJson(Map<String, dynamic> json) => SeasonSummary(
        seasonNumber: (json['season_number'] as int?) ?? 0,
        name: (json['name'] ?? '') as String,
        episodeCount: (json['episode_count'] as int?) ?? 0,
        posterPath: json['poster_path'] as String?,
      );

  @override
  List<Object?> get props => [seasonNumber];
}

/// Full season detail (fetched on demand when the user picks a season),
/// containing the episode list.
class SeasonDetail extends Equatable {
  final int seasonNumber;
  final String name;
  final List<Episode> episodes;

  const SeasonDetail({
    required this.seasonNumber,
    required this.name,
    required this.episodes,
  });

  factory SeasonDetail.fromJson(Map<String, dynamic> json) {
    final episodesJson = json['episodes'] as List<dynamic>? ?? [];
    return SeasonDetail(
      seasonNumber: (json['season_number'] as int?) ?? 0,
      name: (json['name'] ?? '') as String,
      episodes: episodesJson
          .map((e) => Episode.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  List<Object?> get props => [seasonNumber, episodes];
}

class Episode extends Equatable {
  final int id;
  final int episodeNumber;
  final int seasonNumber;
  final String name;
  final String overview;
  final String? stillPath;
  final double voteAverage;
  final int runtimeMinutes;

  const Episode({
    required this.id,
    required this.episodeNumber,
    required this.seasonNumber,
    required this.name,
    required this.overview,
    this.stillPath,
    this.voteAverage = 0,
    this.runtimeMinutes = 0,
  });

  String get stillUrl => stillPath == null
      ? ''
      : '${ApiConstants.tmdbImageBaseUrl}/${ApiConstants.stillSize}$stillPath';

  factory Episode.fromJson(Map<String, dynamic> json) => Episode(
        id: json['id'] as int,
        episodeNumber: (json['episode_number'] as int?) ?? 0,
        seasonNumber: (json['season_number'] as int?) ?? 0,
        name: (json['name'] ?? '') as String,
        overview: (json['overview'] ?? '') as String,
        stillPath: json['still_path'] as String?,
        voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0,
        runtimeMinutes: (json['runtime'] as int?) ?? 0,
      );

  @override
  List<Object?> get props => [id];
}
