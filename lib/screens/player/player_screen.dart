import 'dart:async';
import 'dart:convert';
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
  final int? episodeNumber;
  final int? season;
  final int? number;

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
    this.episodeNumber,
    this.season,
    this.number,
  });

  const PlayerScreen.forMovie(
    this.movie, {
    super.key,
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
    this.isMovie = true,
    this.seasonNumber,
    this.episodeNumber,
    this.season,
    this.number,
  });

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
    this.episodeNumber,
    this.season,
    this.number,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _showControls = true;
  bool _isPlaying = true;
  int _currentServer = 0;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isDragging = false;

  Timer? _controlsTimer;
  Timer? _syncTimer;
  String? _feedbackBadge;
  Timer? _badgeTimer;

  int get _resolvedId {
    if (widget.tmdbId != null && widget.tmdbId! > 0) return widget.tmdbId!;
    if (widget.id != null && widget.id! > 0) return widget.id!;
    for (var obj in [widget.mediaItem, widget.movie, widget.media, widget.item]) {
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
    for (var obj in [widget.mediaItem, widget.movie, widget.media, widget.item]) {
      if (obj != null) {
        try {
          final t = obj.title ?? obj.name;
          if (t != null && t.toString().isNotEmpty) return t.toString();
        } catch (_) {}
      }
    }
    return 'Now Playing';
  }

  bool get _resolvedIsTv {
    if (widget.isTv) return true;
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

  List<Map<String, String>> get _servers {
    final id = _resolvedId;
    final s = widget.seasonNumber ?? widget.season ?? 1;
    final e = widget.episodeNumber ?? widget.episode ?? 1;
    final cleanTitle = Uri.encodeComponent('$_resolvedTitle episode $e');

    if (_resolvedIsTv) {
      return [
        {
          'name': 'Server 1 (VidLink AutoPlay HD)',
          'badge': 'Primary HD',
          'url': 'https://vidlink.pro/tv/$id/$s/$e?autoplay=true',
        },
        {
          'name': 'Server 2 (MultiEmbed - Hindi / Multi-Audio)',
          'badge': 'Hindi / Dubbed',
          'url': 'https://multiembed.mov/?video_id=$id&tmdb=1&s=$s&e=$e&autoplay=1',
        },
        {
          'name': 'Server 3 (AutoEmbed Ultra & Anime)',
          'badge': 'Global Mirror',
          'url': 'https://player.autoembed.cc/embed/tv/$id/$s/$e',
        },
        {
          'name': 'Server 4 (Pakistani Drama & Free HD)',
          'badge': 'YouTube Direct',
          'url': 'https://www.youtube.com/embed?listType=search&list=$cleanTitle&autoplay=1',
        },
      ];
    } else {
      return [
        {
          'name': 'Server 1 (VidLink AutoPlay HD)',
          'badge': 'Primary HD',
          'url': 'https://vidlink.pro/movie/$id?autoplay=true',
        },
        {
          'name': 'Server 2 (MultiEmbed - Hindi / Multi-Audio)',
          'badge': 'Hindi / Dubbed',
          'url': 'https://multiembed.mov/?video_id=$id&tmdb=1&autoplay=1',
        },
        {
          'name': 'Server 3 (AutoEmbed Ultra 1080p)',
          'badge': 'Global Mirror',
          'url': 'https://player.autoembed.cc/embed/movie/$id',
        },
        {
          'name': 'Server 4 (VidSrc Mirror)',
          'badge': 'Fallback',
          'url': 'https://vidsrc.cc/v2/embed/movie/$id',
        },
      ];
    }
  }

  @override
  void initState() {
    super.initState();
    _lockLandscape();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent('Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36')
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
            _injectCleanPlayerEngine();
          },
          onNavigationRequest: (request) {
            final url = request.url.toLowerCase();
            if (url.startsWith('blob:') ||
                url.startsWith('about:') ||
                url.contains('vidlink') ||
                url.contains('multiembed') ||
                url.contains('autoembed') ||
                url.contains('vidsrc') ||
                url.contains('youtube') ||
                url.contains('m3u8') ||
                url.contains('mp4')) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent; // Blocks all popup ads
          },
        ),
      )
      ..loadRequest(Uri.parse(_servers[_currentServer]['url']!));

    _startSyncLoop();
    _resetControlsTimer();
  }

  Future<void> _lockLandscape() async {
    await WakelockPlus.enable();
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _injectCleanPlayerEngine() {
    const cssAndScript = '''
      (function() {
        window.open = function() { return null; };
        
        // Hide all website UI, headers, banners and native controls
        const style = document.createElement('style');
        style.innerHTML = `
          header, footer, nav, .header, .footer, .servers, .server-list,
          .jw-controls, .vjs-control-bar, .plyr__controls, [class*="control-bar"],
          button[aria-label="Settings"], .jw-display-icon-display, .alert {
            display: none !important;
            opacity: 0 !important;
            pointer-events: none !important;
          }
          body, html {
            background: #000000 !important;
            overflow: hidden !important;
            margin: 0 !important;
            padding: 0 !important;
          }
          video, iframe {
            width: 100vw !important;
            height: 100vh !important;
            object-fit: contain !important;
            position: fixed !important;
            top: 0 !important;
            left: 0 !important;
            z-index: 1 !important;
          }
        `;
        document.head.appendChild(style);

        // Auto trigger unmuted playback
        setInterval(function() {
          const btn = document.querySelector('.play-btn, .vjs-big-play-button, button[aria-label="Play"], #play, svg[data-icon="play"]');
          if (btn) btn.click();
          const v = document.querySelector('video');
          if (v && v.paused) v.play().catch(function(){});
        }, 500);
      })();
    ''';
    _controller.runJavaScript(cssAndScript).catchError((_) {});
  }

  void _startSyncLoop() {
    _syncTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted || _isDragging) return;
      try {
        const js = '''
          (function() {
            var v = document.querySelector('video');
            if(v && !isNaN(v.duration)) {
              return JSON.stringify({
                pos: Math.floor(v.currentTime),
                dur: Math.floor(v.duration),
                paused: v.paused
              });
            }
            return "";
          })()
        ''';
        final res = await _controller.runJavaScriptReturningResult(js);
        final str = res.toString().replaceAll(r'\"', '"').replaceAll(RegExp(r'^"|"$'), '');
        if (str.isNotEmpty && str.startsWith('{')) {
          final data = jsonDecode(str);
          if (mounted) {
            setState(() {
              _position = Duration(seconds: (data['pos'] as num).toInt());
              _duration = Duration(seconds: (data['dur'] as num).toInt());
              _isPlaying = !(data['paused'] as bool);
            });
          }
        }
      } catch (_) {}
    });
  }

  void _togglePlayPause() {
    const js = '''
      (function() {
        var v = document.querySelector('video');
        if(v) {
          if(v.paused) { v.play(); return true; }
          else { v.pause(); return false; }
        }
        return false;
      })()
    ''';
    _controller.runJavaScript(js).catchError((_) {});
    setState(() => _isPlaying = !_isPlaying);
    _showBadge(_isPlaying ? 'Playing ▶' : 'Paused ⏸');
    _resetControlsTimer();
  }

  void _seekRelative(int seconds) {
    final js = '''
      (function() {
        var v = document.querySelector('video');
        if(v) {
          v.currentTime = Math.max(0, v.currentTime + ($seconds));
        }
      })()
    ''';
    _controller.runJavaScript(js).catchError((_) {});
    setState(() {
      final target = _position + Duration(seconds: seconds);
      _position = target < Duration.zero ? Duration.zero : target;
    });
    _showBadge(seconds > 0 ? '+$seconds Sec ⏩' : '$seconds Sec ⏪');
    _resetControlsTimer();
  }

  void _seekTo(Duration position) {
    final sec = position.inSeconds;
    final js = "var v = document.querySelector('video'); if(v) { v.currentTime = $sec; }";
    _controller.runJavaScript(js).catchError((_) {});
    setState(() => _position = position);
  }

  void _unmute() {
    const js = "var v = document.querySelector('video'); if(v) { v.muted = false; v.volume = 1.0; }";
    _controller.runJavaScript(js).catchError((_) {});
    _showBadge('Volume 100% 🔊');
    _resetControlsTimer();
  }

  void _showBadge(String text) {
    setState(() => _feedbackBadge = text);
    _badgeTimer?.cancel();
    _badgeTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _feedbackBadge = null);
    });
  }

  void _resetControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _resetControlsTimer();
  }

  void _showServerPicker() {
    _controlsTimer?.cancel();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select Streaming Server',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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
                  final isSel = idx == _currentServer;
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: isSel ? Colors.redAccent.withOpacity(0.15) : Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isSel ? Colors.redAccent : Colors.transparent),
                    ),
                    child: ListTile(
                      leading: Icon(
                        idx == 1 ? Icons.translate_rounded : (idx == 3 ? Icons.live_tv_rounded : Icons.dns_rounded),
                        color: isSel ? Colors.redAccent : Colors.white70,
                      ),
                      title: Text(
                        s['name']!,
                        style: TextStyle(
                          color: isSel ? Colors.redAccent : Colors.white,
                          fontSize: 13.5,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: isSel ? const Icon(Icons.check_circle, color: Colors.redAccent, size: 20) : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _currentServer = idx;
                          _isLoading = true;
                        });
                        _controller.loadRequest(Uri.parse(s['url']!));
                        _resetControlsTimer();
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
    ).then((_) => _resetControlsTimer());
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _controlsTimer?.cancel();
    _badgeTimer?.cancel();
    WakelockPlus.disable();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seasonNum = widget.seasonNumber ?? widget.season;
    final epNum = widget.episodeNumber ?? widget.episode ?? widget.number;
    final subtitleInfo = _resolvedIsTv && seasonNum != null && epNum != null
        ? '$_resolvedTitle • S${seasonNum}E$epNum'
        : _resolvedTitle;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Raw Stream Engine (Cleaned by injected CSS)
            WebViewWidget(controller: _controller),

            // 2. Gesture Detector Layer for Tap & Double-Tap Seeks
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _toggleControls,
                    onDoubleTap: () => _seekRelative(-10),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _toggleControls,
                    onDoubleTap: _togglePlayPause,
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _toggleControls,
                    onDoubleTap: () => _seekRelative(10),
                  ),
                ),
              ],
            ),

            // 3. Center Animated Feedback Badge (+10s, -10s, Volume)
            if (_feedbackBadge != null)
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.redAccent, width: 1.2),
                  ),
                  child: Text(
                    _feedbackBadge!,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

            // 4. Loading Indicator Overlay
            if (_isLoading)
              Container(
                color: Colors.black,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Colors.redAccent, strokeWidth: 3),
                      const SizedBox(height: 16),
                      Text(
                        'Connecting to ${_servers[_currentServer]['badge']}...',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),

            // 5. Netflix-Style Sleek Top Bar
            AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: _showControls ? 1.0 : 0.0,
              child: IgnorePointer(
                ignoring: !_showControls,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black87, Colors.transparent],
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
                          subtitleInfo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                      InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: _unmute,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.volume_up_rounded, color: Colors.white, size: 18),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: _showServerPicker,
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
                              const Icon(Icons.dns_rounded, color: Colors.redAccent, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                'Server ${_currentServer + 1}',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
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

            // 6. Center Netflix HUD (Replay 10s, Big Play/Pause, Forward 10s)
            AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: _showControls ? 1.0 : 0.0,
              child: IgnorePointer(
                ignoring: !_showControls,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        iconSize: 42,
                        icon: const Icon(Icons.replay_10_rounded, color: Colors.white),
                        onPressed: () => _seekRelative(-10),
                      ),
                      const SizedBox(width: 38),
                      IconButton(
                        iconSize: 68,
                        icon: Icon(
                          _isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                          color: Colors.redAccent,
                        ),
                        onPressed: _togglePlayPause,
                      ),
                      const SizedBox(width: 38),
                      IconButton(
                        iconSize: 42,
                        icon: const Icon(Icons.forward_10_rounded, color: Colors.white),
                        onPressed: () => _seekRelative(10),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 7. Bottom Red Scrubber & Live Progress
            AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: _showControls ? 1.0 : 0.0,
              child: IgnorePointer(
                ignoring: !_showControls,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(18, 28, 18, 14),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Colors.black87],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3.5,
                            activeTrackColor: Colors.redAccent,
                            inactiveTrackColor: Colors.white24,
                            thumbColor: Colors.redAccent,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                          ),
                          child: Slider(
                            value: _duration.inSeconds > 0
                                ? (_position.inSeconds / _duration.inSeconds).clamp(0.0, 1.0)
                                : 0.0,
                            onChangeStart: (_) => _isDragging = true,
                            onChangeEnd: (val) {
                              _isDragging = false;
                              final sec = (_duration.inSeconds * val).round();
                              _seekTo(Duration(seconds: sec));
                            },
                            onChanged: (val) {
                              setState(() {
                                final sec = (_duration.inSeconds * val).round();
                                _position = Duration(seconds: sec);
                              });
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDuration(_position),
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                _duration > Duration.zero ? _formatDuration(_duration) : '--:--',
                                style: const TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                            ],
                          ),
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
