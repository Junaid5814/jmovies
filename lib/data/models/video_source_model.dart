import 'package:equatable/equatable.dart';

enum StreamFormat { hls, dash, mp4 }

/// A single audio/dub track available within a source, as reported by
/// YOUR backend (e.g. distinct HLS audio renditions). For HLS streams
/// with embedded multi-audio, [trackId] should match the underlying
/// player's audio track identifier.
class AudioTrack extends Equatable {
  final String trackId;
  final String language; // e.g. "English", "Hindi", "Urdu"

  /// If the underlying player supports native in-stream track selection
  /// (e.g. a real ExoPlayer/better_player_plus integration), [trackId]
  /// alone is enough. The base Flutter `video_player` plugin does NOT
  /// expose in-stream audio track switching, so when [url] is provided,
  /// selecting this track re-points the player at a separate,
  /// language-specific rendition instead.
  final String? url;

  const AudioTrack({required this.trackId, required this.language, this.url});

  factory AudioTrack.fromJson(Map<String, dynamic> json) => AudioTrack(
        trackId: (json['track_id'] ?? '') as String,
        language: (json['language'] ?? '') as String,
        url: json['url'] as String?,
      );

  @override
  List<Object?> get props => [trackId, language];
}

/// A single quality rendition of a source (Auto/1080p/720p/480p), each
/// with its own URL — as returned by YOUR backend/CDN.
class QualityVariant extends Equatable {
  final String label; // "Auto", "1080p", "720p", "480p"
  final String url;
  final int? bitrateKbps;

  const QualityVariant({
    required this.label,
    required this.url,
    this.bitrateKbps,
  });

  factory QualityVariant.fromJson(Map<String, dynamic> json) =>
      QualityVariant(
        label: (json['label'] ?? 'Auto') as String,
        url: json['url'] as String,
        bitrateKbps: json['bitrate_kbps'] as int?,
      );

  @override
  List<Object?> get props => [label, url];
}

/// A single playable source for a given title, returned by YOUR OWN
/// backend/CDN (not TMDB). Kept separate from [Movie]/[TvShow] so the
/// metadata layer and the streaming layer evolve independently.
class VideoSource extends Equatable {
  final String id;
  final String label; // e.g. "Server Alpha"
  final String url; // default/auto URL
  final StreamFormat format;
  final List<SubtitleTrack> subtitles;
  final List<AudioTrack> audioTracks;
  final List<QualityVariant> qualities;

  const VideoSource({
    required this.id,
    required this.label,
    required this.url,
    required this.format,
    this.subtitles = const [],
    this.audioTracks = const [],
    this.qualities = const [],
  });

  factory VideoSource.fromJson(Map<String, dynamic> json) {
    return VideoSource(
      id: json['id'] as String,
      label: (json['label'] ?? 'Default') as String,
      url: json['url'] as String,
      format: _formatFromString(json['format'] as String? ?? 'hls'),
      subtitles: (json['subtitles'] as List<dynamic>? ?? [])
          .map((s) => SubtitleTrack.fromJson(s as Map<String, dynamic>))
          .toList(),
      audioTracks: (json['audio_tracks'] as List<dynamic>? ?? [])
          .map((a) => AudioTrack.fromJson(a as Map<String, dynamic>))
          .toList(),
      qualities: (json['qualities'] as List<dynamic>? ?? [])
          .map((q) => QualityVariant.fromJson(q as Map<String, dynamic>))
          .toList(),
    );
  }

  static StreamFormat _formatFromString(String s) {
    switch (s.toLowerCase()) {
      case 'dash':
        return StreamFormat.dash;
      case 'mp4':
        return StreamFormat.mp4;
      default:
        return StreamFormat.hls;
    }
  }

  @override
  List<Object?> get props => [id, url];
}

class SubtitleTrack extends Equatable {
  final String language; // e.g. "English"
  final String url; // .vtt or .srt
  final bool isEmbedded; // true if it's an in-stream HLS subtitle rendition

  const SubtitleTrack({
    required this.language,
    required this.url,
    this.isEmbedded = false,
  });

  factory SubtitleTrack.fromJson(Map<String, dynamic> json) => SubtitleTrack(
        language: (json['language'] ?? '') as String,
        url: (json['url'] ?? '') as String,
        isEmbedded: (json['is_embedded'] as bool?) ?? false,
      );

  @override
  List<Object?> get props => [language, url];
}

/// Bundles the sources available for one title, as returned by your
/// backend endpoint, e.g.:
///   GET /api/stream/movie/{movieId}
///   GET /api/stream/tv/{tvId}/{season}/{episode}
class StreamBundle extends Equatable {
  final String contentId; // movieId, or "tvId-sN-eN" for episodes
  final List<VideoSource> sources;

  const StreamBundle({required this.contentId, required this.sources});

  VideoSource? get defaultSource => sources.isNotEmpty ? sources.first : null;

  factory StreamBundle.fromJson(Map<String, dynamic> json) => StreamBundle(
        contentId: (json['content_id'] ?? '').toString(),
        sources: (json['sources'] as List<dynamic>)
            .map((s) => VideoSource.fromJson(s as Map<String, dynamic>))
            .toList(),
      );

  @override
  List<Object?> get props => [contentId];
}
