import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';
import '../models/video_source_model.dart';

/// Resolves playable video sources for a movie or a specific TV episode.
/// This intentionally talks to YOUR OWN backend (self-hosted API,
/// Jellyfin/Plex, Cloudflare Stream, S3+CloudFront signed URLs, etc.) —
/// never TMDB, which has no video files.
///
/// Point [baseUrl] at your real backend. Until then, both resolvers fall
/// back to public HLS/MP4 test streams so the player screen is runnable
/// out of the box.
class StreamSourceService {
  final Dio _dio;
  final String? baseUrl;

  StreamSourceService({this.baseUrl})
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl ?? '',
          connectTimeout: const Duration(seconds: 60), // tolerate slow networks
          receiveTimeout: const Duration(seconds: 60),
        ));

  /// Expected backend contract:
  ///   GET {baseUrl}/api/stream/movie/{movieId}
  ///   -> { "content_id": "123", "sources": [ {...} ] }
  Future<StreamBundle> fetchMovieStreamBundle(int movieId) async {
    if (baseUrl == null || baseUrl!.isEmpty) {
      return _placeholderBundle('movie-$movieId');
    }
    try {
      final res = await _dio.get('/api/stream/movie/$movieId');
      return StreamBundle.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (_) {
      // Automatic fallback: backend unreachable/slow -> degrade gracefully
      // rather than leaving the player with nothing.
      return _placeholderBundle('movie-$movieId');
    }
  }

  /// Expected backend contract:
  ///   GET {baseUrl}/api/stream/tv/{tvId}/{season}/{episode}
  ///   -> { "content_id": "tvId-sN-eN", "sources": [ {...} ] }
  Future<StreamBundle> fetchEpisodeStreamBundle(
    int tvId,
    int seasonNumber,
    int episodeNumber,
  ) async {
    final contentId = '$tvId-s$seasonNumber-e$episodeNumber';
    if (baseUrl == null || baseUrl!.isEmpty) {
      return _placeholderBundle(contentId);
    }
    try {
      final res = await _dio
          .get('/api/stream/tv/$tvId/$seasonNumber/$episodeNumber');
      return StreamBundle.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (_) {
      return _placeholderBundle(contentId);
    }
  }

  StreamBundle _placeholderBundle(String contentId) => StreamBundle(
        contentId: contentId,
        sources: const [
          VideoSource(
            id: 'placeholder-hls',
            label: 'Auto (HLS)',
            url: SampleStreams.hlsAppleTest,
            format: StreamFormat.hls,
            audioTracks: [
              AudioTrack(trackId: 'original', language: 'Original Audio (HD)'),
            ],
            qualities: [
              QualityVariant(label: 'Auto', url: SampleStreams.hlsAppleTest),
            ],
          ),
          VideoSource(
            id: 'placeholder-mp4-1',
            label: '1080p (MP4)',
            url: SampleStreams.mp4BigBuckBunny,
            format: StreamFormat.mp4,
            audioTracks: [
              AudioTrack(trackId: 'original', language: 'Original Audio (HD)'),
            ],
          ),
          VideoSource(
            id: 'placeholder-mp4-2',
            label: '720p (MP4)',
            url: SampleStreams.mp4Sintel,
            format: StreamFormat.mp4,
            audioTracks: [
              AudioTrack(trackId: 'original', language: 'Original Audio (HD)'),
            ],
          ),
        ],
      );
}
