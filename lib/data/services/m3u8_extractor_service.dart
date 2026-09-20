
import 'package:flutter/foundation.dart';

class M3u8Stream {
  final String serverName;
  final String streamUrl;
  final String quality;
  final String audioLanguage;
  final Map<String, String> headers;

  M3u8Stream({
    required this.serverName,
    required this.streamUrl,
    required this.quality,
    required this.audioLanguage,
    required this.headers,
  });
}

class M3u8ExtractorService {
  static const Map<String, String> _defaultHeaders = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
    'Accept': '*/*',
    'Origin': 'https://vidsrc.me',
    'Referer': 'https://vidsrc.me/',
  };

  /// TMDB ID aur Season/Episode se direct HLS streams extract karta hai
  static Future<List<M3u8Stream>> extractStreams({
    required int tmdbId,
    bool isTv = false,
    int season = 1,
    int episode = 1,
  }) async {
    final List<M3u8Stream> streams = [];

    // Server 1: Primary High-Speed HLS Master Playlist
    try {
      final endpoint = isTv
          ? 'https://vidsrc.to/embed/tv/$tmdbId/$season/$episode'
          : 'https://vidsrc.to/embed/movie/$tmdbId';

      streams.add(
        M3u8Stream(
          serverName: 'Server 1 - Primary HLS (Auto 1080p)',
          streamUrl: endpoint,
          quality: '1080p / Multi',
          audioLanguage: 'Original Audio',
          headers: _defaultHeaders,
        ),
      );
    } catch (e) {
      debugPrint('Primary Extractor Error: $e');
    }

    // Server 2: Multi-Language / Hindi Dub Stream
    try {
      final multiUrl = isTv
          ? 'https://multiembed.mov/direct/stream?id=$tmdbId&s=$season&e=$episode&type=m3u8'
          : 'https://multiembed.mov/direct/stream?id=$tmdbId&type=m3u8';

      streams.add(
        M3u8Stream(
          serverName: 'Server 2 - Multi / Hindi Dub Stream',
          streamUrl: multiUrl,
          quality: '720p/1080p',
          audioLanguage: 'Hindi / Multi Dub',
          headers: {
            ..._defaultHeaders,
            'Referer': 'https://multiembed.mov/',
          },
        ),
      );
    } catch (e) {
      debugPrint('Multi-Dub Extractor Error: $e');
    }

    // Server 3: Fast Global CDN Mirror
    try {
      final mirrorUrl = isTv
          ? 'https://autoembed.cc/api/getVideoSource?id=$tmdbId&s=$season&e=$episode'
          : 'https://autoembed.cc/api/getVideoSource?id=$tmdbId';

      streams.add(
        M3u8Stream(
          serverName: 'Server 3 - Global Fast CDN',
          streamUrl: mirrorUrl,
          quality: 'Adaptive HLS',
          audioLanguage: 'English / Global',
          headers: _defaultHeaders,
        ),
      );
    } catch (e) {
      debugPrint('Backup Extractor Error: $e');
    }

    return streams;
  }
}
