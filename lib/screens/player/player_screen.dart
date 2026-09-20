import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PlayerScreen extends StatefulWidget {
  final dynamic movie;
  final dynamic show;
  final dynamic episode;
  final dynamic mediaItem;
  final dynamic media;
  final dynamic item;
  final int? tmdbId;
  final int? id;
  final String? title;
  final String? name;
  final bool isTv;
  final bool? isMovie;
  final int? seasonNumber;
  final int? season;
  final int? episodeNumber;

  const PlayerScreen({
    super.key,
    this.movie,
    this.show,
    this.episode,
    this.mediaItem,
    this.media,
    this.item,
    this.tmdbId,
    this.id,
    this.title,
    this.name,
    this.isTv = false,
    this.isMovie,
    this.seasonNumber,
    this.season,
    this.episodeNumber,
  });

  const PlayerScreen.forMovie(
    dynamic movieItem, {
    super.key,
  })  : movie = movieItem,
        show = null,
        episode = null,
        mediaItem = null,
        media = null,
        item = null,
        tmdbId = null,
        id = null,
        title = null,
        name = null,
        isTv = false,
        isMovie = true,
        seasonNumber = null,
        season = null,
        episodeNumber = null;

  const PlayerScreen.forEpisode({
    super.key,
    this.show,
    this.episode,
    this.movie,
    this.mediaItem,
    this.media,
    this.item,
    this.tmdbId,
    this.id,
    this.title,
    this.name,
    this.isTv = true,
    this.isMovie = false,
    this.seasonNumber,
    this.season,
    this.episodeNumber,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isFullScreen = false;
  int _currentSourceIndex = 0;

  int get _resolvedId {
    if (widget.tmdbId != null && widget.tmdbId! > 0) return widget.tmdbId!;
    if (widget.id != null && widget.id! > 0) return widget.id!;
    for (var obj in [widget.show, widget.movie, widget.mediaItem, widget.media, widget.item]) {
      if (obj != null) {
        try {
          final val = obj.id;
          if (val != null && val is int && val > 0) return val;
        } catch (_) {}
      }
    }
    return 0;
  }

  String get _resolvedTitle {
    if (widget.title != null && widget.title!.isNotEmpty) return widget.title!;
    if (widget.name != null && widget.name!.isNotEmpty) return widget.name!;
    for (var obj in [widget.show, widget.movie, widget.mediaItem, widget.media, widget.item]) {
      if (obj != null) {
        try {
          final t = obj.title ?? obj.name;
          if (t != null && t.toString().isNotEmpty) return t.toString();
        } catch (_) {}
      }
    }
    return 'Now Playing';
  }

  int get _resolvedSeason => widget.seasonNumber ?? widget.season ?? 1;
  int get _resolvedEpisode => widget.episodeNumber ?? 1;

  bool get _resolvedIsTv {
    if (widget.show != null || widget.episode != null || widget.isTv) return true;
    if (widget.seasonNumber != null && widget.seasonNumber! > 0) return true;
    for (var obj in [widget.mediaItem, widget.movie, widget.media, widget.item]) {
      if (obj != null) {
        try {
          if (obj.mediaType == 'tv') return true;
        } catch (_) {}
      }
    }
    return false;
  }

  List<Map<String, String>> get _streamList {
    final id = _resolvedId;
    final s = _resolvedSeason;
    final e = _resolvedEpisode;

    if (_resolvedIsTv) {
      return [
        {
          'title': 'Original Audio (VidLink Fast HD)',
          'tag': 'English / Original',
          'url': 'https://vidlink.pro/tv/$id/$s/$e?autoplay=true',
        },
        {
          'title': 'Hindi Dubbed Stream (MultiEmbed)',
          'tag': 'Hindi Audio',
          'url': 'https://multiembed.mov/?video_id=$id&tmdb=1&s=$s&e=$e&autoplay=1',
        },
        {
          'title': 'Global HD Server (AutoEmbed)',
          'tag': 'Fast Mirror',
          'url': 'https://player.autoembed.cc/embed/tv/$id/$s/$e',
        },
      ];
    } else {
      return [
        {
          'title': 'Original Audio (VidLink Fast HD)',
          'tag': 'English / Original',
          'url': 'https://vidlink.pro/movie/$id?autoplay=true',
        },
        {
          'title': 'Hindi Dubbed Stream (MultiEmbed)',
          'tag': 'Hindi Audio',
          'url': 'https://multiembed.mov/?video_id=$id&tmdb=1&autoplay=1',
        },
        {
          'title': 'Global HD Server (AutoEmbed)',
          'tag': 'Fast Mirror',
          'url': 'https://player.autoembed.cc/embed/movie/$id',
        },
      ];
    }
  }

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _initWebStream();
  }

  void _initWebStream() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent('Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36')
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
            _injectCleanStyling();
          },
          onNavigationRequest: (req) {
            final u = req.url.toLowerCase();
            if (u.contains('vidlink') ||
                u.contains('multiembed') ||
                u.contains('autoembed') ||
                u.contains('m3u8') ||
                u.contains('mp4') ||
                u.startsWith('blob:')) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent; // Ad popups block karta hai
          },
        ),
      )
      ..loadRequest(Uri.parse(_streamList[_currentSourceIndex]['url']!));
  }

  void _injectCleanStyling() {
    const css = '''
      (function() {
        var s = document.createElement('style');
        s.innerHTML = `
          header, footer, nav, .header, .footer, .servers, .server-list,
          .alert, #disqus_thread, [id*="ad"], [class*="ad-"] {
            display: none !important;
          }
          body, html {
            background: #000000 !important;
            margin: 0 !important;
            padding: 0 !important;
            overflow: hidden !important;
          }
          video, iframe {
            width: 100% !important;
            height: 100% !important;
          }
        `;
        document.head.appendChild(s);
      })();
    ''';
    _controller.runJavaScript(css).catchError((_) {});
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
      if (_isFullScreen) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    });
  }

  void _openSourcePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.75,
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Audio & Stream Source', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close, color: Colors.white54, size: 20), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 8),
                ...List.generate(_streamList.length, (idx) {
                  final isSel = idx == _currentSourceIndex;
                  final item = _streamList[idx];
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: isSel ? Colors.redAccent.withOpacity(0.18) : Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isSel ? Colors.redAccent : Colors.transparent),
                    ),
                    child: ListTile(
                      dense: true,
                      leading: Icon(
                        idx == 1 ? Icons.translate_rounded : Icons.hd_rounded,
                        color: isSel ? Colors.redAccent : Colors.white70,
                      ),
                      title: Text(item['title']!, style: TextStyle(color: isSel ? Colors.redAccent : Colors.white, fontSize: 13.5, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                      subtitle: Text(item['tag']!, style: TextStyle(color: isSel ? Colors.redAccent.withOpacity(0.8) : Colors.white38, fontSize: 11)),
                      trailing: isSel ? const Icon(Icons.check_circle, color: Colors.redAccent, size: 18) : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _currentSourceIndex = idx;
                          _isLoading = true;
                        });
                        _controller.loadRequest(Uri.parse(item['url']!));
                      },
                    ),
                  );
                }),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WakelockPlus.disable();
    super.dispose();
  }

  Widget _buildVideoPlayer() {
    return AspectRatio(
      aspectRatio: _isFullScreen ? (MediaQuery.of(context).size.width / MediaQuery.of(context).size.height) : (16 / 9),
      child: Container(
        color: Colors.black,
        child: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(color: Colors.redAccent),
              ),
            // Floating Fullscreen & Back Action
            Positioned(
              top: 8,
              left: 8,
              child: InkWell(
                onTap: () {
                  if (_isFullScreen) {
                    _toggleFullScreen();
                  } else {
                    Navigator.pop(context);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
                ),
              ),
            ),
            Positioned(
              bottom: 8,
              right: 8,
              child: InkWell(
                onTap: _toggleFullScreen,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    _isFullScreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isFullScreen) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(child: _buildVideoPlayer()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SafeArea(
        child: Column(
          children: [
            // Top 16:9 Video Box
            _buildVideoPlayer(),

            // Scrollable Content Below Video (YouTube Style)
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _resolvedTitle,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                          child: const Text('HD', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _resolvedIsTv ? 'TV Series • Ep $_resolvedEpisode' : 'Movie',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: _openSourcePicker,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white24, width: 0.8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.tune_rounded, color: Colors.redAccent, size: 14),
                                const SizedBox(width: 5),
                                Text(
                                  _streamList[_currentSourceIndex]['tag']!,
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: Colors.white12),
                    const SizedBox(height: 12),
                    const Text('Audio & Stream Details', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.surround_sound_rounded, color: Colors.redAccent, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Current Stream: ${_streamList[_currentSourceIndex]['title']}',
                                  style: const TextStyle(color: Colors.white, fontSize: 12.5),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: const [
                              Icon(Icons.aspect_ratio_rounded, color: Colors.white54, size: 18),
                              SizedBox(width: 10),
                              Text('Auto Fit 16:9 • Tap fullscreen for Cinema View', style: TextStyle(color: Colors.white54, fontSize: 11.5)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
