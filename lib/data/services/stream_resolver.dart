import 'dart:convert';
import 'package:http/http.dart' as http;

/// Stream ka structure jo Native Player ko pass hoga
class AppStream {
  final String name;
  final String url;
  final Map<String, String> headers;
  final bool isDubbed;

  AppStream({
    required this.name,
    required this.url,
    this.headers = const {},
    this.isDubbed = false,
  });
}

class StreamResolver {
  /// Yeh function TMDB ID lega aur working direct M3U8 links return karega
  static Future<List<AppStream>> getStreams({
    required int tmdbId,
    bool isTv = false,
    int season = 1,
    int episode = 1,
  }) async {
    List<AppStream> streams = [];

    // ----------------------------------------------------
    // SERVER 1: AutoEmbed API (Fastest M3U8 Extractor)
    // ----------------------------------------------------
    try {
      final endpoint = isTv
          ? 'https://autoembed.cc/api/getStream?id=$tmdbId&s=$season&e=$episode'
          : 'https://autoembed.cc/api/getStream?id=$tmdbId';

      final response = await http.get(Uri.parse(endpoint)).timeout(const Duration(seconds: 8));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['stream'] != null && data['stream'].toString().isNotEmpty) {
          streams.add(AppStream(
            name: 'Server 1 (Auto HQ)',
            url: data['stream'].toString(),
            headers: {'Referer': 'https://autoembed.cc/'},
          ));
        }
      }
    } catch (e) {
      // Ignore API timeout and move to next
    }

    // ----------------------------------------------------
    // SERVER 2: Direct VidSrc M3U8 Mirror (Fallback)
    // ----------------------------------------------------
    try {
      final mirrorUrl = isTv
          ? 'https://vidsrc.stream/hls/tv/$tmdbId/$season/$episode/master.m3u8'
          : 'https://vidsrc.stream/hls/movie/$tmdbId/master.m3u8';

      streams.add(AppStream(
        name: 'Server 2 (Direct Mirror)',
        url: mirrorUrl,
        headers: {
          'Referer': 'https://vidsrc.stream/',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'
        },
      ));
    } catch (e) {
      // Ignore
    }

    // ----------------------------------------------------
    // SERVER 3: MultiEmbed (Hindi / Dubbed Support)
    // ----------------------------------------------------
    // MultiEmbed ki API Hindi audio links deti hai agar available hon.
    try {
       final dubbedUrl = isTv
          ? 'https://multiembed.mov/direct/hls/tv/$tmdbId/$season/$episode'
          : 'https://multiembed.mov/direct/hls/movie/$tmdbId';
          
       streams.add(AppStream(
        name: 'Server 3 (Multi/Hindi Audio)',
        url: dubbedUrl,
        isDubbed: true,
        headers: {'Referer': 'https://multiembed.mov/'},
      ));
    } catch (e) {
      // Ignore
    }

    return streams;
  }
}
