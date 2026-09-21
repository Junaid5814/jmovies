import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class WatchWebviewScreen extends StatefulWidget {
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

  const WatchWebviewScreen({
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

  const WatchWebviewScreen.forMovie(
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

  const WatchWebviewScreen.forEpisode({
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
  State<WatchWebviewScreen> createState() => _WatchWebviewScreenState();
}

class _WatchWebviewScreenState extends State<WatchWebviewScreen> {
  InAppWebViewController? _controller;
  int _currentServerIndex = 0;
  bool _isLoading = true;
  double _progress = 0;
  bool _showTopBar = true;
  Timer? _hideTimer;

  int get _resolvedId {
    if (widget.tmdbId != null && widget.tmdbId! > 0) return widget.tmdbId!;
    if (widget.id != null && widget.id! > 0) return widget.id!;
    for (var obj in [widget.movie, widget.show, widget.mediaItem, widget.media, widget.item]) {
      if (obj != null) {
        try {
          final v = obj.id;
          if (v != null && v is int && v > 0) return v;
          final parsed = int.tryParse(v.toString());
          if (parsed != null && parsed > 0) return parsed;
        } catch (_) {}
      }
    }
    return 0;
  }

  String get _resolvedTitle {
    if (widget.title != null && widget.title!.isNotEmpty) return widget.title!;
    if (widget.name != null && widget.name!.isNotEmpty) return widget.name!;
    for (var obj in [widget.movie, widget.show, widget.mediaItem, widget.media, widget.item]) {
      if (obj != null) {
        try {
          final t = obj.title ?? obj.name;
          if (t != null && t.toString().isNotEmpty) return t.toString();
        } catch (_) {}
      }
    }
    return 'Streaming Movie';
  }

  bool get _resolvedIsTv {
    if (widget.isTv) return true;
    if (widget.show != null || widget.episode != null) return true;
    if (widget.seasonNumber != null && widget.seasonNumber! > 0) return true;
    if (widget.season != null && widget.season! > 0) return true;
    for (var obj in [widget.mediaItem, widget.movie, widget.media, widget.item]) {
      if (obj != null) {
        try {
          if (obj.mediaType == 'tv') return true;
        } catch (_) {}
      }
    }
    return false;
  }

  int get _resolvedSeason => widget.seasonNumber ?? widget.season ?? 1;
  int get _resolvedEpisode => widget.episodeNumber ?? widget.episode ?? 1;

  List<Map<String, String>> get _servers {
    final id = _resolvedId;
    final s = _resolvedSeason;
    final e = _resolvedEpisode;

    if (_resolvedIsTv) {
      return [
        {
          'name': 'Server 1 (MultiEmbed - Hindi / Urdu Dub)',
          'tag': 'Hindi Dub',
          'url': 'https://multiembed.mov/?video_id=$id&tmdb=1&s=$s&e=$e&autoplay=1',
        },
        {
          'name': 'Server 2 (VidLink - English 1080p HD)',
          'tag': 'English HD',
          'url': 'https://vidlink.pro/tv/$id/$s/$e?autoplay=true',
        },
        {
          'name': 'Server 3 (EmbedSU - Anime & Asian Drama)',
          'tag': 'Anime HD',
          'url': 'https://embed.su/embed/tv/$id/$s/$e',
        },
        {
          'name': 'Server 4 (VidSrc CC - Fast Mirror)',
          'tag': 'Mirror 1',
          'url': 'https://vidsrc.cc/v2/embed/tv/$id/$s/$e',
        },
      ];
    } else {
      return [
        {
          'name': 'Server 1 (MultiEmbed - Hindi / Urdu Dub)',
          'tag': 'Hindi Dub',
          'url': 'https://multiembed.mov/?video_id=$id&tmdb=1&autoplay=1',
        },
        {
          'name': 'Server 2 (VidLink - English 1080p HD)',
          'tag': 'English HD',
          'url': 'https://vidlink.pro/movie/$id?autoplay=true',
        },
        {
          'name': 'Server 3 (EmbedSU - Ultra HD / Anime)',
          'tag': 'Ultra HD',
          'url': 'https://embed.su/embed/movie/$id',
        },
        {
          'name': 'Server 4 (VidSrc CC - Fast Mirror)',
          'tag': 'Mirror 1',
          'url': 'https://vidsrc.cc/v2/embed/movie/$id',
        },
      ];
    }
  }

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WakelockPlus.enable();
    _startTimer();
  }

  void _startTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showTopBar = false);
    });
  }

  void _toggleBar() {
    setState(() => _showTopBar = !_showTopBar);
    if (_showTopBar) _startTimer();
  }

  void _openServerSheet() {
    _hideTimer?.cancel();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select Stream Server / Audio',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...List.generate(_servers.length, (idx) {
                  final s = _servers[idx];
                  final isSel = idx == _currentServerIndex;
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
                        idx == 0 ? Icons.translate_rounded : Icons.dns_rounded,
                        color: isSel ? Colors.redAccent : Colors.white70,
                        size: 20,
                      ),
                      title: Text(
                        s['name']!,
                        style: TextStyle(
                          color: isSel ? Colors.redAccent : Colors.white,
                          fontSize: 13.5,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: isSel
                          ? const Icon(Icons.check_circle, color: Colors.redAccent, size: 18)
                          : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _currentServerIndex = idx;
                          _isLoading = true;
                        });
                        _controller?.loadUrl(
                          urlRequest: URLRequest(url: WebUri(s['url']!)),
                        );
                        _startTimer();
                      },
                    ),
                  );
                }),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    ).then((_) => _startTimer());
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = _servers[_currentServerIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(active['url']!)),
              initialSettings: InAppWebViewSettings(
                mediaPlaybackRequiresUserGesture: false,
                allowsInlineMediaPlayback: true,
                javaScriptEnabled: true,
                javaScriptCanOpenWindowsAutomatically: false,
                supportMultipleWindows: false,
                transparentBackground: true,
                userAgent:
                    'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
              ),
              onWebViewCreated: (controller) => _controller = controller,
              onLoadStart: (controller, url) {
                if (mounted) setState(() => _isLoading = true);
              },
              onProgressChanged: (controller, progress) {
                if (mounted) setState(() => _progress = progress / 100);
              },
              onLoadStop: (controller, url) {
                if (mounted) setState(() => _isLoading = false);
                controller.evaluateJavascript(source: """
                  (function() {
                    window.open = function() { return null; };
                    setInterval(function() {
                      const btn = document.querySelector('.play-btn, .vjs-big-play-button, button[aria-label="Play"], #play, .jw-display-icon-display');
                      if (btn) btn.click();
                      const v = document.querySelector('video');
                      if (v && v.paused) v.play().catch(function(){});
                    }, 500);
                  })();
                """);
              },
              onCreateWindow: (controller, createWindowAction) async {
                // Blocks all popup windows/ads
                return false;
              },
              shouldOverrideUrlLoading: (controller, navigationAction) async {
                final uri = navigationAction.request.url;
                if (uri == null) return NavigationActionPolicy.CANCEL;

                final url = uri.toString().toLowerCase();

                // Whitelist only legitimate media playback & CDN links
                if (url.startsWith('blob:') ||
                    url.startsWith('about:') ||
                    url.contains('multiembed') ||
                    url.contains('vidlink') ||
                    url.contains('embed.su') ||
                    url.contains('vidsrc') ||
                    url.contains('stream') ||
                    url.contains('cdn') ||
                    url.contains('m3u8') ||
                    url.contains('mp4')) {
                  return NavigationActionPolicy.ALLOW;
                }

                // Block external ad/betting redirects
                return NavigationActionPolicy.CANCEL;
              },
            ),

            // Tap detector to toggle top controls
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _toggleBar,
              ),
            ),

            // Loading overlay
            if (_isLoading)
              Container(
                color: Colors.black,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: CircularProgressIndicator(
                          color: Colors.redAccent,
                          value: _progress > 0 && _progress < 1 ? _progress : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Connecting to ${active['name']}...',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),

            // Sleek Auto-Hiding Top Bar
            AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: _showTopBar ? 1.0 : 0.0,
              child: IgnorePointer(
                ignoring: !_showTopBar,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black.withOpacity(0.85), Colors.transparent],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Row(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          _resolvedTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: _openServerSheet,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.65),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.redAccent.withOpacity(0.8), width: 1.0),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.tune_rounded, color: Colors.redAccent, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                active['tag']!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.keyboard_arrow_down, color: Colors.white70, size: 15),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
