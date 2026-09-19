import 'package:equatable/equatable.dart';
import '../../core/constants/api_constants.dart';

/// Pure TMDB metadata. This model NEVER contains a video URL —
/// that separation is deliberate (see VideoSourceModel).
class Movie extends Equatable {
  final int id;
  final String title;
  final String overview;
  final String? posterPath;
  final String? backdropPath;
  final double voteAverage;
  final String releaseDate;
  final List<int> genreIds;
  final List<CastMember> cast;
  final int runtimeMinutes;

  const Movie({
    required this.id,
    required this.title,
    required this.overview,
    this.posterPath,
    this.backdropPath,
    this.voteAverage = 0,
    this.releaseDate = '',
    this.genreIds = const [],
    this.cast = const [],
    this.runtimeMinutes = 0,
  });

  String get posterUrl => posterPath == null
      ? ''
      : '${ApiConstants.tmdbImageBaseUrl}/${ApiConstants.posterSize}$posterPath';

  String get backdropUrl => backdropPath == null
      ? ''
      : '${ApiConstants.tmdbImageBaseUrl}/${ApiConstants.backdropSize}$backdropPath';

  String get releaseYear =>
      releaseDate.isNotEmpty ? releaseDate.split('-').first : '—';

  factory Movie.fromJson(Map<String, dynamic> json) {
    final creditsJson = json['credits']?['cast'] as List<dynamic>?;
    return Movie(
      id: json['id'] as int,
      title: (json['title'] ?? json['name'] ?? '') as String,
      overview: (json['overview'] ?? '') as String,
      posterPath: json['poster_path'] as String?,
      backdropPath: json['backdrop_path'] as String?,
      voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0,
      releaseDate: (json['release_date'] ?? '') as String,
      genreIds: (json['genre_ids'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          const [],
      runtimeMinutes: (json['runtime'] as int?) ?? 0,
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

class CastMember extends Equatable {
  final String name;
  final String character;
  final String? profilePath;

  const CastMember({
    required this.name,
    required this.character,
    this.profilePath,
  });

  String get profileUrl => profilePath == null
      ? ''
      : '${ApiConstants.tmdbImageBaseUrl}/w185$profilePath';

  factory CastMember.fromJson(Map<String, dynamic> json) => CastMember(
        name: (json['name'] ?? '') as String,
        character: (json['character'] ?? '') as String,
        profilePath: json['profile_path'] as String?,
      );

  @override
  List<Object?> get props => [name, character];
}
