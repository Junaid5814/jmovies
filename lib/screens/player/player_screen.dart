import 'dart:async';
import 'dart:convert';
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
  bool _showHud = true;
  Timer? _hudTimer;
  bool _isLoading = true;

  // Video State
  double _currentPosition = 0;
  double _totalDuration = 0;
  bool _isPlaying = true;
  bool _isDraggingSlider = false;
  double _dragSliderValue = 0;

  // Gestures (Brightness & Volume)
  double _brightness = 1.0;
  double _volume = 1.0;
  String? _gestureLabel;
  IconData? _gestureIcon;
  Timer? _gestureTimer;

  // Screen Aspect Modes (0: Contain, 1: Fill, 2: Cover)
  int _aspectMode = 0;
  final List<String> _aspectLabels = ['Fit', 'Stretch', 'Zoom'];

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
    if (widget.show != null || widget.episode != null || widget.isTv) return true;
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
    final s = _resolvedSeason;
    final e = _resolvedEpisode;

    if (_resolvedIsTv) {
      return [
        {'name': 'Fast HD (English/Original)', 'badge': 'FAST', 'url': 'https://vidlink.pro/tv/$id/$s/$e?autoplay=true'},
        {'name': 'Hindi Dubbed / Multi-Audio', 'badge': 'HINDI/DUB', 'url': 'https://multiembed.mov/?video_id=$id&tmdb=1&s=$s&e=$e&autoplay=1'},
        {'name': 'AutoEmbed (Anime & Global)', 'badge': 'BACKUP', 'url': 'https://player.autoembed.cc/embed/tv/$id/$s/$e'},
      ];
    } else {
      return [
        {'name': 'Fast HD (English/Original)', 'badge': 'FAST', 'url': 'https://vidlink.pro/movie/$id?autoplay=true'},
        {'name': 'Hindi Dubbed / Multi-Audio', 'badge': 'HINDI/DUB', 'url': 'https://multiembed.mov/?video_id=$id&tmdb=1&autoplay=1'},
        {'name': 'AutoEmbed (Backup)', 'badge': 'BACKUP', 'url': 'https://player.autoembed.cc/embed/movie/$id'},
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
      ..addJavaScriptChannel(
        'PlayerBridge',
        onMessageReceived: (JavaScriptMessage msg) {
          try {
            final data = jsonDecode(msg.message);
            if (!_isDraggingSlider && mounted) {
              setState(() {
                _currentPosition = (data['currentTime'] as num).toDouble();
                _totalDuration = (data['duration'] as num).toDouble();
                _isPlaying = !(data['paused'] as bool);
              });
            }
          } catch (_) {}
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
            _injectCleanCinemaEngine();
          },
          onNavigationRequest: (req) {
            final u = req.url.toLowerCase();
            if (u.startsWith('blob:') ||
                u.startsWith('about:') ||
                u.contains('vidlink') ||
                u.contains('multiembed') ||
                u.contains('autoembed') ||
                u.contains('m3u8') ||
                u.contains('mp4')) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(Uri.parse(_servers[_currentServer]['url']!));

    _startHudTimer();
  }

  void _injectCleanCinemaEngine() {
    const js = """
      (function() {
        window.open = function() { return null; };

        // 1. Hide all web player controls, banners, and overlays via CSS
        var style = document.getElementById('cinema-clean-style');
        if (!style) {
          style = document.createElement('style');
          style.id = 'cinema-clean-style';
          style.innerHTML = `
            video::-webkit-media-controls,
            video::-webkit-media-controls-enclosure,
            .jw-controls, .vjs-control-bar, .controls, .plyr__controls,
            .art-controls, .dplayer-controller, header, footer,
            .top-bar, .vjs-big-play-button, button[aria-label="Play"],
            #play, .jw-display-icon-display, svg[data-icon="play"] {
              display: none !important;
              opacity: 0 !important;
              visibility: hidden !important;
              pointer-events: none !important;
            }
            body, html {
              background: black !important;
              overflow: hidden !important;
            }
          `;
          document.head.appendChild(style);
        }

        // 2. Auto-Play and status polling loop
        setInterval(function() {
          var v = document.querySelector('video');
          if (v) {
            if (v.paused && !window._userPaused) {
              v.muted = false;
              v.play().catch(function(){});
            }
            if (window.PlayerBridge) {
              PlayerBridge.postMessage(JSON.stringify({
                currentTime: v.currentTime || 0,
                duration: v.duration || 0,
                paused: v.paused,
                volume: v.volume || 1.0
              }));
            }
          }
        }, 500);
      })();
    """;
    _controller.runJavaScript(js).catchError((_) {});
  }

  void _seekTo(double seconds) {
    _controller.runJavaScript("var v = document.querySelector('video'); if (v) { v.currentTime = $seconds; }").catchError((_) {});
  }

  void _seekRelative(int deltaSeconds) {
    final target = (_currentPosition + deltaSeconds).clamp(0.0, _totalDuration > 0 ? _totalDuration : 99999.0);
    _seekTo(target);
    _triggerGestureFeedback(
      deltaSeconds > 0 ? '+$deltaSeconds Sec' : '$deltaSeconds Sec',
      deltaSeconds > 0 ? Icons.fast_forward_rounded : Icons.fast_rewind_rounded,
    );
  }

  void _togglePlayPause() {
    setState(() => _isPlaying = !_isPlaying);
    final js = """
      var v = document.querySelector('video');
      if (v) {
        if (v.paused) {
          window._userPaused = false;
          v.play();
        } else {
          window._userPaused = true;
          v.pause();
        }
      }
    """;
    _controller.runJavaScript(js).catchError((_) {});
    _triggerGestureFeedback(_isPlaying ? 'Playing' : 'Paused', _isPlaying ? Icons.play_arrow_rounded : Icons.pause_rounded);
  }

  void _cycleAspectRatio() {
    setState(() {
      _aspectMode = (_aspectMode + 1) % 3;
    });
    final fits = ['contain', 'fill', 'cover'];
    final js = "var v = document.querySelector('video'); if (v) { v.style.objectFit = '${fits[_aspectMode]}'; v.style.width = '100vw'; v.style.height = '100vh'; }";
    _controller.runJavaScript(js).catchError((_) {});
    _triggerGestureFeedback('Mode: ${_aspectLabels[_aspectMode]}', Icons.aspect_ratio_rounded);
  }

  void _handleVerticalDrag(DragUpdateDetails details, bool isLeftHalf, double screenHeight) {
    final delta = -details.primaryDelta! / screenHeight;
    if (isLeftHalf) {
      // Adjust Brightness
      setState(() {
        _brightness = (_brightness + delta).clamp(0.15, 1.0);
      });
      _triggerGestureFeedback(
        'Brightness ${(_brightness * 100).round()}%',
        _brightness > 0.5 ? Icons.brightness_high_rounded : Icons.brightness_low_rounded,
      );
    } else {
      // Adjust Volume
      setState(() {
        _volume = (_volume + delta).clamp(0.0, 1.0);
      });
      _controller.runJavaScript("var v = document.querySelector('video'); if (v) { v.volume = $_volume; v.muted = false; }").catchError((_) {});
      _triggerGestureFeedback(
        'Volume ${(_volume * 100).round()}%',
        _volume > 0.0 ? Icons.volume_up_rounded : Icons.volume_off_rounded,
      );
    }
  }

  void _triggerGestureFeedback(String label, IconData icon) {
    setState(() {
      _gestureLabel = label;
      _gestureIcon = icon;
    });
    _gestureTimer?.cancel();
    _gestureTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _gestureLabel = null);
    });
  }

  void _startHudTimer() {
    _hudTimer?.cancel();
    _hudTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showHud = false);
    });
  }

  void _toggleHud() {
    setState(() => _showHud = !_showHud);
    if (_showHud) _startHudTimer();
  }

  String _formatDuration(double seconds) {
    if (seconds.isNaN || seconds.isInfinite || seconds <= 0) return '00:00';
    final duration = Duration(seconds: seconds.round());
    final h = duration.inHours;
    final m = duration.inMinutes.remainder(60);
    final s = duration.inSeconds.remainder(60);
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _showServerSheet() {
    _hudTimer?.cancel();
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
                    const Text('Select Stream & Audio', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close, color: Colors.white54, size: 20), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 8),
                ...List.generate(_servers.length, (idx) {
                  final isSel = idx == _currentServer;
                  final srv = _servers[idx];
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
                      title: Text(srv['name']!, style: TextStyle(color: isSel ? Colors.redAccent : Colors.white, fontSize: 14, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                      trailing: isSel ? const Icon(Icons.check_circle, color: Colors.redAccent, size: 18) : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _currentServer = idx;
                          _isLoading = true;
                          _currentPosition = 0;
                        });
                        _controller.loadRequest(Uri.parse(srv['url']!));
                        _startHudTimer();
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
    ).then((_) => _startHudTimer());
  }

  @override
  void dispose() {
    _hudTimer?.cancel();
    _gestureTimer?.cancel();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Background Web Player
            WebViewWidget(controller: _controller),

            // Smooth Brightness Dimmer Overlay
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.black.withOpacity((1.0 - _brightness) * 0.85),
                ),
              ),
            ),

            // Gestures Detection Layer (Left = Brightness, Right = Volume, Double-Tap = Seek)
            Positioned.fill(
              child: Row(
                children: [
                  // Left Screen Half
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: _toggleHud,
                      onDoubleTap: () => _seekRelative(-10),
                      onVerticalDragUpdate: (d) => _handleVerticalDrag(d, true, size.height),
                    ),
                  ),
                  // Right Screen Half
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: _toggleHud,
                      onDoubleTap: () => _seekRelative(10),
                      onVerticalDragUpdate: (d) => _handleVerticalDrag(d, false, size.height),
                    ),
                  ),
                ],
              ),
            ),

            // Gesture Visual Indicator (MX Player style center badge)
            if (_gestureLabel != null)
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.8), width: 1.2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_gestureIcon, color: Colors.redAccent, size: 24),
                      const SizedBox(width: 10),
                      Text(
                        _gestureLabel!,
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),

            // Buffering / Loading Indicator
            if (_isLoading)
              Container(
                color: Colors.black,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Colors.redAccent),
                      const SizedBox(height: 14),
                      Text('Starting ${_servers[_currentServer]['name']}...', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),
              ),

            // Top Bar (Back button, Title, Server Switch)
            AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: _showHud ? 1.0 : 0.0,
              child: IgnorePointer(
                ignoring: !_showHud,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
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
                              border: Border.all(color: Colors.redAccent.withOpacity(0.8), width: 0.8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.tune_rounded, color: Colors.redAccent, size: 14),
                                const SizedBox(width: 6),
                                Text(
                                  _servers[_currentServer]['badge']!,
                                  style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
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
            ),

            // Bottom Bar (Timeline, Play/Pause, Duration, Aspect Ratio)
            AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: _showHud ? 1.0 : 0.0,
              child: IgnorePointer(
                ignoring: !_showHud,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Colors.black.withOpacity(0.95)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Seek Slider Bar
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3.5,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                            activeTrackColor: Colors.redAccent,
                            inactiveTrackColor: Colors.white24,
                            thumbColor: Colors.redAccent,
                            overlayColor: Colors.redAccent.withOpacity(0.2),
                          ),
                          child: Slider(
                            min: 0.0,
                            max: _totalDuration > 0 ? _totalDuration : 1.0,
                            value: _isDraggingSlider
                                ? _dragSliderValue.clamp(0.0, _totalDuration > 0 ? _totalDuration : 1.0)
                                : _currentPosition.clamp(0.0, _totalDuration > 0 ? _totalDuration : 1.0),
                            onChanged: (val) {
                              setState(() {
                                _isDraggingSlider = true;
                                _dragSliderValue = val;
                              });
                            },
                            onChangeEnd: (val) {
                              _seekTo(val);
                              setState(() {
                                _currentPosition = val;
                                _isDraggingSlider = false;
                              });
                              _startHudTimer();
                            },
                          ),
                        ),
                        // Bottom Controls Row
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          child: Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                                onPressed: _togglePlayPause,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${_formatDuration(_isDraggingSlider ? _dragSliderValue : _currentPosition)} / ${_formatDuration(_totalDuration)}',
                                style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w500),
                              ),
                              const Spacer(),
                              InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: _cycleAspectRatio,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.white24, width: 0.8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.aspect_ratio_rounded, color: Colors.white, size: 14),
                                      const SizedBox(width: 5),
                                      Text(
                                        _aspectLabels[_aspectMode],
                                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
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
