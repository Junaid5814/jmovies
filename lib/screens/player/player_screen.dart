import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

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
  int _currentServer = 0;
  bool _showControls = true;
  Timer? _hideTimer;
  bool _isLoading = true;
  String? _feedbackText;
  Timer? _feedbackTimer;

  int get _resolvedId {
    if (widget.tmdbId != null && widget.tmdbId! > 0) return widget.tmdbId!;
    if (widget.id != null && widget.id! > 0) return widget.id!;
    for (var obj in [widget.show, widget.movie, widget.mediaItem, widget.media, widget.item]) {
      if (obj != null) {
        try {
          final val = obj.id;
          if (val != null && val is int && val > 0) return val;
          final tmdb = obj.tmdbId;
          if (tmdb != null && tmdb is int && tmdb > 0) return tmdb;
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
    return 'Streaming';
  }

  int get _resolvedSeason {
    if (widget.seasonNumber != null && widget.seasonNumber! > 0) return widget.seasonNumber!;
    if (widget.season != null && widget.season! > 0) return widget.season!;
    if (widget.episode != null) {
      try {
        final s = widget.episode.seasonNumber ?? widget.episode.season;
        if (s != null && s is int && s > 0) return s;
      } catch (_) {}
    }
    return 1;
  }

  int get _resolvedEpisode {
    if (widget.episodeNumber != null && widget.episodeNumber! > 0) return widget.episodeNumber!;
    if (widget.episode != null) {
      if (widget.episode is int && (widget.episode as int) > 0) return widget.episode as int;
      try {
        final e = widget.episode.episodeNumber ?? widget.episode.episode ?? widget.episode.number;
        if (e != null && e is int && e > 0) return e;
      } catch (_) {}
    }
    return 1;
  }

  bool get _resolvedIsTv {
    if (widget.show != null) return true;
    if (widget.isTv) return true;
    if (widget.seasonNumber != null && widget.seasonNumber! > 0) return true;
    if (widget.season != null && widget.season! > 0) return true;
    if (widget.episode != null) return true;
    for (var obj in [widget.mediaItem, widget.movie, widget.media, widget.item]) {
      if (obj != null) {
        try {
          if (obj.mediaType == 'tv') return true;
        } catch (_) {}
      }
    }
    return false;
  }

  List<Map<String, String>> get _servers {
    final id = _resolvedId;
    final s = _resolvedSeason;
    final e = _resolvedEpisode;
    final qTitle = Uri.encodeComponent('$_resolvedTitle episode $e');

    if (_resolvedIsTv) {
      return [
        {'name': 'Server 1 (VidLink AutoPlay HD)', 'url': 'https://vidlink.pro/tv/$id/$s/$e?autoplay=true'},
        {'name': 'Server 2 (MultiEmbed - Hindi Dubbed / Multi)', 'url': 'https://multiembed.mov/?video_id=$id&tmdb=1&s=$s&e=$e&autoplay=1'},
        {'name': 'Server 3 (AutoEmbed Anime & Global)', 'url': 'https://player.autoembed.cc/embed/tv/$id/$s/$e'},
        {'name': 'Server 4 (Pakistani Dramas / YouTube)', 'url': 'https://www.youtube.com/embed?listType=search&list=$qTitle&autoplay=1'},
      ];
    } else {
      return [
        {'name': 'Server 1 (VidLink AutoPlay HD)', 'url': 'https://vidlink.pro/movie/$id?autoplay=true'},
        {'name': 'Server 2 (MultiEmbed - Hindi Dubbed / Multi)', 'url': 'https://multiembed.mov/?video_id=$id&tmdb=1&autoplay=1'},
        {'name': 'Server 3 (AutoEmbed Fast Backup)', 'url': 'https://player.autoembed.cc/embed/movie/$id'},
        {'name': 'Server 4 (VidSrc Ultra)', 'url': 'https://vidsrc.cc/v2/embed/movie/$id'},
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
            _injectAutoPlayAndClean();
          },
          onNavigationRequest: (req) {
            final url = req.url.toLowerCase();
            if (url.startsWith('blob:') ||
                url.startsWith('about:') ||
                url.contains('vidlink') ||
                url.contains('multiembed') ||
                url.contains('autoembed') ||
                url.contains('youtube') ||
                url.contains('vidsrc') ||
                url.contains('m3u8') ||
                url.contains('mp4')) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(Uri.parse(_servers[_currentServer]['url']!));

    _startHideTimer();
  }

  void _injectAutoPlayAndClean() {
    const js = """
      (function() {
        window.open = function() { return null; };
        setInterval(function() {
          const btn = document.querySelector('.play-btn, .vjs-big-play-button, button[aria-label="Play"], #play, .jw-display-icon-display, svg[data-icon="play"]');
          if (btn) btn.click();
          const v = document.querySelector('video');
          if (v && v.paused) {
            v.muted = false;
            v.play().catch(function(){});
          }
        }, 350);
      })();
    """;
    _controller.runJavaScript(js).catchError((_) {});
  }

  void _seekBy(int seconds) {
    final js = "var v = document.querySelector('video'); if(v) { v.currentTime += $seconds; }";
    _controller.runJavaScript(js).catchError((_) {});
    _triggerFeedback(seconds > 0 ? '+$seconds Sec ⏩' : '$seconds Sec ⏪');
  }

  void _togglePlayPause() {
    const js = "var v = document.querySelector('video'); if(v) { if(v.paused) { v.play(); } else { v.pause(); } }";
    _controller.runJavaScript(js).catchError((_) {});
    _triggerFeedback('Play / Pause ⏯️');
  }

  void _unmuteAudio() {
    const js = "var v = document.querySelector('video'); if(v) { v.muted = false; v.volume = 1.0; }";
    _controller.runJavaScript(js).catchError((_) {});
    _triggerFeedback('Audio Unmuted 🔊');
  }

  void _triggerFeedback(String text) {
    setState(() => _feedbackText = text);
    _feedbackTimer?.cancel();
    _feedbackTimer = Timer(const Duration(milliseconds: 1000), () {
      if (mounted) setState(() => _feedbackText = null);
    });
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _startHideTimer();
  }

  void _showServerSheet() {
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
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Select Stream Server & Audio', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close, color: Colors.white54, size: 20), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 8),
                ...List.generate(_servers.length, (idx) {
                  final isSel = idx == _currentServer;
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
                        idx == 1 ? Icons.translate_rounded : (idx == 3 ? Icons.live_tv_rounded : Icons.dns_rounded),
                        color: isSel ? Colors.redAccent : Colors.white70,
                        size: 20,
                      ),
                      title: Text(
                        _servers[idx]['name']!,
                        style: TextStyle(
                          color: isSel ? Colors.redAccent : Colors.white,
                          fontSize: 13.5,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: isSel ? const Icon(Icons.check_circle, color: Colors.redAccent, size: 18) : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _currentServer = idx;
                          _isLoading = true;
                        });
                        _controller.loadRequest(Uri.parse(_servers[idx]['url']!));
                        _startHideTimer();
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
    ).then((_) => _startHideTimer());
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _feedbackTimer?.cancel();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            WebViewWidget(controller: _controller),

            Positioned.fill(
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onDoubleTap: () => _seekBy(-10),
                      onTap: _toggleControls,
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onDoubleTap: _togglePlayPause,
                      onTap: _toggleControls,
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onDoubleTap: () => _seekBy(10),
                      onTap: _toggleControls,
                    ),
                  ),
                ],
              ),
            ),

            if (_feedbackText != null)
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: Colors.redAccent, width: 1),
                  ),
                  child: Text(
                    _feedbackText!,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

            if (_isLoading)
              Container(
                color: Colors.black,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Colors.redAccent),
                      const SizedBox(height: 16),
                      Text(
                        'Connecting to ${_servers[_currentServer]['name']}...',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),

            AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: _showControls ? 1.0 : 0.0,
              child: IgnorePointer(
                ignoring: !_showControls,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black.withOpacity(0.9), Colors.transparent],
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
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                      InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: _showServerSheet,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.redAccent, width: 0.8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.tune_rounded, color: Colors.redAccent, size: 14),
                              const SizedBox(width: 6),
                              Text('Server ${_currentServer + 1}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 4),
                              const Icon(Icons.keyboard_arrow_down, color: Colors.white70, size: 14),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: _showControls ? 1.0 : 0.0,
              child: IgnorePointer(
                ignoring: !_showControls,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white24, width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.replay_10_rounded, color: Colors.white, size: 28),
                          onPressed: () => _seekBy(-10),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.play_circle_filled_rounded, color: Colors.redAccent, size: 38),
                          onPressed: _togglePlayPause,
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.forward_10_rounded, color: Colors.white, size: 28),
                          onPressed: () => _seekBy(10),
                        ),
                        const SizedBox(width: 12),
                        Container(height: 24, width: 1, color: Colors.white24),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.volume_up_rounded, color: Colors.white, size: 26),
                          onPressed: _unmuteAudio,
                          tooltip: 'Unmute',
                        ),
                      ],
                    ),
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
