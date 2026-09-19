import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class PlayerScreen extends StatefulWidget {
  final dynamic movie;
  final dynamic mediaItem;
  final int? tmdbId;
  final String? title;
  final bool isTv;
  final int? seasonNumber;
  final int? episodeNumber;

  const PlayerScreen({
    super.key,
    this.movie,
    this.mediaItem,
    this.tmdbId,
    this.title,
    this.isTv = false,
    this.seasonNumber,
    this.episodeNumber,
  });

  const PlayerScreen.forEpisode({
    super.key,
    required int tmdbId,
    required String title,
    required int seasonNumber,
    required int episodeNumber,
    this.movie,
    this.mediaItem,
  })  : tmdbId = tmdbId,
        title = title,
        isTv = true,
        seasonNumber = seasonNumber,
        episodeNumber = episodeNumber;

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
    for (var obj in [widget.mediaItem, widget.movie]) {
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
    for (var obj in [widget.mediaItem, widget.movie]) {
      if (obj != null) {
        try {
          final t = obj.title ?? obj.name;
          if (t != null && t.toString().isNotEmpty) return t.toString();
        } catch (_) {}
      }
    }
    return 'Streaming';
  }

  bool get _resolvedIsTv {
    if (widget.isTv) return true;
    if (widget.seasonNumber != null && widget.seasonNumber! > 0) return true;
    for (var obj in [widget.mediaItem, widget.movie]) {
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
    final s = widget.seasonNumber ?? 1;
    final e = widget.episodeNumber ?? 1;
    final q = Uri.encodeComponent('$_resolvedTitle episode $e');

    if (_resolvedIsTv) {
      return [
        {'name': 'Server 1 (VidLink HD)', 'url': 'https://vidlink.pro/tv/$id/$s/$e?autoplay=true'},
        {'name': 'Server 2 (MultiEmbed - Hindi / Dubbed)', 'url': 'https://multiembed.mov/?video_id=$id&tmdb=1&s=$s&e=$e&autoplay=1'},
        {'name': 'Server 3 (AutoEmbed Global)', 'url': 'https://player.autoembed.cc/embed/tv/$id/$s/$e'},
        {'name': 'Server 4 (Pakistani Drama / YouTube Stream)', 'url': 'https://www.youtube.com/embed?listType=search&list=$q&autoplay=1'},
      ];
    } else {
      return [
        {'name': 'Server 1 (VidLink HD)', 'url': 'https://vidlink.pro/movie/$id?autoplay=true'},
        {'name': 'Server 2 (MultiEmbed - Hindi / Dubbed)', 'url': 'https://multiembed.mov/?video_id=$id&tmdb=1&autoplay=1'},
        {'name': 'Server 3 (AutoEmbed Multi)', 'url': 'https://player.autoembed.cc/embed/movie/$id'},
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
      ..setUserAgent('Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36')
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
            _autoPlay();
          },
          onNavigationRequest: (req) {
            final u = req.url.toLowerCase();
            if (u.startsWith('blob:') ||
                u.startsWith('about:') ||
                u.contains('vidlink') ||
                u.contains('multiembed') ||
                u.contains('autoembed') ||
                u.contains('youtube') ||
                u.contains('vidsrc') ||
                u.contains('m3u8') ||
                u.contains('mp4')) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(Uri.parse(_servers[_currentServer]['url']!));

    _startHideTimer();
  }

  void _autoPlay() {
    const js = '''
      (function() {
        setInterval(function() {
          const btn = document.querySelector('.play-btn, .vjs-big-play-button, button[aria-label="Play"], #play, .jw-display-icon-display');
          if (btn) btn.click();
          const v = document.querySelector('video');
          if (v && v.paused) v.play().catch(function(){});
        }, 500);
      })();
    ''';
    _controller.runJavaScript(js).catchError((_) {});
  }

  void _seek(int sec) {
    _controller.runJavaScript("var v = document.querySelector('video'); if(v) { v.currentTime += $sec; }").catchError((_) {});
    _toast(sec > 0 ? '+$sec Sec ⏩' : '$sec Sec ⏪');
  }

  void _togglePlay() {
    _controller.runJavaScript("var v = document.querySelector('video'); if(v) { if(v.paused){ v.play(); } else { v.pause(); } }").catchError((_) {});
    _toast('Play / Pause ⏯️');
  }

  void _unmute() {
    _controller.runJavaScript("var v = document.querySelector('video'); if(v) { v.muted = false; v.volume = 1.0; }").catchError((_) {});
    _toast('Unmuted 🔊');
  }

  void _toast(String t) {
    setState(() => _feedbackText = t);
    _feedbackTimer?.cancel();
    _feedbackTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _feedbackText = null);
    });
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _showServerSheet() {
    _hideTimer?.cancel();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select Stream Server', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ...List.generate(_servers.length, (i) {
                final isSel = i == _currentServer;
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: isSel ? Colors.redAccent.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListTile(
                    dense: true,
                    title: Text(_servers[i]['name']!, style: TextStyle(color: isSel ? Colors.redAccent : Colors.white, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                    trailing: isSel ? const Icon(Icons.check, color: Colors.redAccent) : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _currentServer = i;
                        _isLoading = true;
                      });
                      _controller.loadRequest(Uri.parse(_servers[i]['url']!));
                      _startHideTimer();
                    },
                  ),
                );
              }),
            ],
          ),
        ),
      ),
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

            // Gestures: Tap center, Double tap right/left
            Positioned.fill(
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onDoubleTap: () => _seek(-10),
                      onTap: () {
                        setState(() => _showControls = !_showControls);
                        if (_showControls) _startHideTimer();
                      },
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onDoubleTap: _togglePlay,
                      onTap: () {
                        setState(() => _showControls = !_showControls);
                        if (_showControls) _startHideTimer();
                      },
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onDoubleTap: () => _seek(10),
                      onTap: () {
                        setState(() => _showControls = !_showControls);
                        if (_showControls) _startHideTimer();
                      },
                    ),
                  ),
                ],
              ),
            ),

            if (_feedbackText != null)
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.redAccent)),
                  child: Text(_feedbackText!, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
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
                      const SizedBox(height: 12),
                      Text('Connecting to ${_servers[_currentServer]['name']}...', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),
              ),

            // Top Bar
            AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: _showControls ? 1.0 : 0.0,
              child: IgnorePointer(
                ignoring: !_showControls,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.black.withOpacity(0.7),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_resolvedTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                      TextButton.icon(
                        onPressed: _showServerSheet,
                        icon: const Icon(Icons.dns_rounded, color: Colors.redAccent, size: 16),
                        label: Text('Server ${_currentServer + 1}', style: const TextStyle(color: Colors.white, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Big Easy Bottom Controls
            AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: _showControls ? 1.0 : 0.0,
              child: IgnorePointer(
                ignoring: !_showControls,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.white24)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.replay_10_rounded, color: Colors.white, size: 30), onPressed: () => _seek(-10)),
                        const SizedBox(width: 8),
                        IconButton(icon: const Icon(Icons.play_circle_fill, color: Colors.redAccent, size: 40), onPressed: _togglePlay),
                        const SizedBox(width: 8),
                        IconButton(icon: const Icon(Icons.forward_10_rounded, color: Colors.white, size: 30), onPressed: () => _seek(10)),
                        const SizedBox(width: 12),
                        Container(height: 24, width: 1, color: Colors.white24),
                        const SizedBox(width: 8),
                        IconButton(icon: const Icon(Icons.volume_up_rounded, color: Colors.white, size: 28), onPressed: _unmute),
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
