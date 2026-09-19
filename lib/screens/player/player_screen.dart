import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

// ==========================================
// 1. DOMAIN MODELS & ENUMS
// ==========================================

enum PlaybackState {
  idle,
  connecting,
  ready,
  playing,
  buffering,
  stalled,
  paused,
  ended,
  failed,
}

enum SourceHealth {
  unknown,
  working,
  slow,
  failed,
}

class StreamSource {
  final int index;
  final String title;
  final String subtitle;
  final String badge;
  final String category;
  final String url;
  SourceHealth health;

  StreamSource({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.category,
    required this.url,
    this.health = SourceHealth.unknown,
  });
}

// ==========================================
// 2. MAIN PLAYER SCREEN WIDGET
// ==========================================

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

class _PlayerScreenState extends State<PlayerScreen> with WidgetsBindingObserver {
  WebViewController? _controller;
  
  // Playback & Session state
  int _sessionId = 0;
  int _currentSourceIndex = 0;
  PlaybackState _playbackState = PlaybackState.idle;
  String _statusMessage = 'Initializing engine...';
  bool _showTopBar = true;
  Timer? _hideControlsTimer;

  // Watchdogs & Timers
  Timer? _playbackTimeoutTimer;
  Timer? _domWatcherTimer;
  final Set<int> _exhaustedSources = {};

  late List<StreamSource> _sources;

  // ==========================================
  // 3. PARAMETER RESOLUTION HELPERS
  // ==========================================

  int get _resolvedId {
    if (widget.tmdbId != null && widget.tmdbId! > 0) return widget.tmdbId!;
    if (widget.id != null && widget.id! > 0) return widget.id!;
    for (var obj in [widget.movie, widget.show, widget.mediaItem, widget.media, widget.item]) {
      if (obj != null) {
        try {
          final val = obj.id;
          if (val != null) {
            final parsed = int.tryParse(val.toString());
            if (parsed != null && parsed > 0) return parsed;
          }
        } catch (_) {}
      }
    }
    return 0;
  }

  String get _resolvedTitle {
    if (widget.title != null && widget.title!.trim().isNotEmpty) return widget.title!.trim();
    if (widget.name != null && widget.name!.trim().isNotEmpty) return widget.name!.trim();
    for (var obj in [widget.movie, widget.show, widget.mediaItem, widget.media, widget.item]) {
      if (obj != null) {
        try {
          final t = obj.title ?? obj.name ?? obj.originalTitle ?? obj.originalName;
          if (t != null && t.toString().trim().isNotEmpty) return t.toString().trim();
        } catch (_) {}
      }
    }
    return 'Streaming';
  }

  bool get _resolvedIsTv {
    if (widget.isTv) return true;
    if (widget.isMovie == false) return true;
    if (widget.show != null || widget.episode != null) return true;
    if ((widget.seasonNumber != null && widget.seasonNumber! > 0) || (widget.season != null && widget.season! > 0)) return true;
    for (var obj in [widget.mediaItem, widget.movie, widget.show, widget.media, widget.item]) {
      if (obj != null) {
        try {
          if (obj.mediaType == 'tv' || obj.isTv == true) return true;
        } catch (_) {}
      }
    }
    return false;
  }

  int get _resolvedSeason {
    if (widget.seasonNumber != null && widget.seasonNumber! > 0) return widget.seasonNumber!;
    if (widget.season != null && widget.season! > 0) return widget.season!;
    if (widget.episode != null) {
      try {
        final s = widget.episode.seasonNumber ?? widget.episode.season;
        if (s != null) return int.tryParse(s.toString()) ?? 1;
      } catch (_) {}
    }
    return 1;
  }

  int get _resolvedEpisode {
    if (widget.episodeNumber != null && widget.episodeNumber! > 0) return widget.episodeNumber!;
    if (widget.number != null && widget.number! > 0) return widget.number!;
    if (widget.episode != null) {
      try {
        final e = widget.episode.episodeNumber ?? widget.episode.episode ?? widget.episode.number;
        if (e != null) return int.tryParse(e.toString()) ?? 1;
      } catch (_) {}
    }
    return 1;
  }

  // ==========================================
  // 4. SOURCE MANAGER INITIALIZATION
  // ==========================================

  void _buildSourcesList() {
    final id = _resolvedId;
    final s = _resolvedSeason;
    final e = _resolvedEpisode;
    final query = Uri.encodeComponent('$_resolvedTitle full episode $e');

    if (_resolvedIsTv) {
      _sources = [
        StreamSource(
          index: 0,
          title: 'Server 1: VidLink Original (1080p HD)',
          subtitle: 'High-speed clean stream with subtitles',
          badge: 'English HD',
          category: 'Primary',
          url: 'https://vidlink.pro/tv/$id/$s/$e?autoplay=true',
        ),
        StreamSource(
          index: 1,
          title: 'Server 2: MultiEmbed (Hindi / Multi-Audio)',
          subtitle: 'Includes Hindi, Urdu, Tamil & regional audio tracks',
          badge: 'Hindi Dubbed',
          category: 'Dubbed',
          url: 'https://multiembed.mov/?video_id=$id&tmdb=1&s=$s&e=$e&autoplay=1',
        ),
        StreamSource(
          index: 2,
          title: 'Server 3: Anime Special Master (EmbedSu)',
          subtitle: 'Original Japanese audio with English & multi subs',
          badge: 'Anime JP/EN',
          category: 'Dubbed',
          url: 'https://embed.su/embed/tv/$id/$s/$e',
        ),
        StreamSource(
          index: 3,
          title: 'Server 4: AutoEmbed Multi-Lang',
          subtitle: 'French, Spanish, and European multi-language streams',
          badge: 'French / Global',
          category: 'Mirrors',
          url: 'https://player.autoembed.cc/embed/tv/$id/$s/$e',
        ),
        StreamSource(
          index: 4,
          title: 'Server 5: VidSrc Pro CDN',
          subtitle: 'Fast alternative 1080p fallback server',
          badge: 'Mirror Pro',
          category: 'Mirrors',
          url: 'https://vidsrc.cc/v2/embed/tv/$id/$s/$e',
        ),
        StreamSource(
          index: 5,
          title: 'Server 6: Regional Direct Official Stream',
          subtitle: 'Official stream for Pakistani and Asian drama titles',
          badge: 'Official HD',
          category: 'Mirrors',
          url: 'https://www.youtube.com/embed?listType=search&list=$query&autoplay=1',
        ),
      ];
    } else {
      _sources = [
        StreamSource(
          index: 0,
          title: 'Server 1: VidLink Original (1080p HD)',
          subtitle: 'High bitrate 1080p movie stream with subtitles',
          badge: 'English HD',
          category: 'Primary',
          url: 'https://vidlink.pro/movie/$id?autoplay=true',
        ),
        StreamSource(
          index: 1,
          title: 'Server 2: MultiEmbed (Hindi / Multi-Audio)',
          subtitle: 'Includes Hindi, Urdu & regional Indian dubbed audio',
          badge: 'Hindi Dubbed',
          category: 'Dubbed',
          url: 'https://multiembed.mov/?video_id=$id&tmdb=1&autoplay=1',
        ),
        StreamSource(
          index: 2,
          title: 'Server 3: Anime Movie Master (EmbedSu)',
          subtitle: 'Japanese original audio + English & multi subtitles',
          badge: 'Anime JP/EN',
          category: 'Dubbed',
          url: 'https://embed.su/embed/movie/$id',
        ),
        StreamSource(
          index: 3,
          title: 'Server 4: AutoEmbed Multi-Lang',
          subtitle: 'French, Spanish, and European audio options',
          badge: 'French / Global',
          category: 'Mirrors',
          url: 'https://player.autoembed.cc/embed/movie/$id',
        ),
        StreamSource(
          index: 4,
          title: 'Server 5: VidSrc Pro CDN',
          subtitle: 'Fast alternative 1080p/4K fallback server',
          badge: 'Mirror Pro',
          category: 'Mirrors',
          url: 'https://vidsrc.cc/v2/embed/movie/$id',
        ),
        StreamSource(
          index: 5,
          title: 'Server 6: SmashyStream Direct',
          subtitle: 'Multi-player backup fallback mirror',
          badge: 'Backup CDN',
          category: 'Mirrors',
          url: 'https://player.smashy.stream/movie/$id',
        ),
      ];
    }
  }

  // ==========================================
  // 5. LIFECYCLE & WEBVIEW CONTROLLER SETUP
  // ==========================================

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WakelockPlus.enable();

    _buildSourcesList();
    _initializeWebViewController();
    _startHideTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _executeJavaScript("var v = document.querySelector('video'); if(v) v.pause();");
    } else if (state == AppLifecycleState.resumed) {
      if (_playbackState == PlaybackState.playing) {
        _executeJavaScript("var v = document.querySelector('video'); if(v && v.paused) v.play();");
      }
    }
  }

  void _initializeWebViewController() {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
      )
      ..setBackgroundColor(Colors.black)
      ..addJavaScriptChannel(
        'FlutterPlayerBridge',
        onMessageReceived: _handleJavaScriptMessage,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (kDebugMode) debugPrint('[PlayerEngine] Page started: $url');
          },
          onPageFinished: (url) {
            if (kDebugMode) debugPrint('[PlayerEngine] Page loaded: $url');
            _injectMonitorAndAutoPlay();
          },
          onWebResourceError: (error) {
            // Strict check: only handle real connection breakdown on the primary HTML document
            if (error.isForMainFrame == true) {
              final desc = error.description.toLowerCase();
              if (desc.contains('net::err_name_not_resolved') ||
                  desc.contains('net::err_connection_refused') ||
                  desc.contains('net::err_connection_timed_out') ||
                  desc.contains('net::err_timed_out') ||
                  desc.contains('net::err_cert') ||
                  desc.contains('net::err_ssl')) {
                _onSourceFailed(_sessionId, 'DNS or Network unreachable (${error.description})');
              }
            }
          },
          onNavigationRequest: _validateNavigationRequest,
        ),
      );

    _controller = controller;
    _loadStreamWithSession(_currentSourceIndex);
  }

  NavigationDecision _validateNavigationRequest(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    if (uri == null) return NavigationDecision.prevent;

    final scheme = uri.scheme.toLowerCase();
    if (scheme == 'about' || scheme == 'blob' || scheme == 'data') {
      return NavigationDecision.navigate;
    }
    if (scheme != 'http' && scheme != 'https') {
      return NavigationDecision.prevent;
    }

    final host = uri.host.toLowerCase();
    final allowedDomains = [
      'vidlink.pro',
      'multiembed.mov',
      'embed.su',
      'autoembed.cc',
      'vidsrc.cc',
      'vidsrc.me',
      'vidsrc.to',
      'smashy.stream',
      'smashystream.xyz',
      'youtube.com',
      'googlevideo.com',
      'cloudflare.com',
      'gstatic.com',
      'googleapis.com',
    ];

    for (final domain in allowedDomains) {
      if (host == domain || host.endsWith('.$domain')) {
        return NavigationDecision.navigate;
      }
    }

    final path = uri.path.toLowerCase();
    if (path.contains('.m3u8') || path.contains('.mp4') || path.contains('.ts')) {
      return NavigationDecision.navigate;
    }

    if (kDebugMode) {
      debugPrint('[PlayerSecurity] Blocked unwanted redirect: ${request.url}');
    }
    return NavigationDecision.prevent;
  }

  // ==========================================
  // 6. SESSION-TOKEN LOAD & SMART FALLBACK
  // ==========================================

  void _loadStreamWithSession(int index) {
    if (!mounted) return;

    _sessionId++;
    final currentSession = _sessionId;

    _playbackTimeoutTimer?.cancel();
    _domWatcherTimer?.cancel();

    setState(() {
      _currentSourceIndex = index;
      _playbackState = PlaybackState.connecting;
      _statusMessage = 'Connecting to ${_sources[index]['badge']}...';
    });

    final targetUrl = _sources[index]['url'];
    if (kDebugMode) {
      debugPrint('[PlayerSession: $currentSession] Loading source $index: $targetUrl');
    }

    _controller?.loadRequest(Uri.parse(targetUrl));

    // Health Watchdog: 12 seconds to confirm real playback or trigger fallback
    _playbackTimeoutTimer = Timer(const Duration(seconds: 12), () {
      if (currentSession != _sessionId || !mounted) return;
      if (_playbackState != PlaybackState.playing) {
        _onSourceFailed(currentSession, 'Stream playback initiation timed out (12s)');
      }
    });
  }

  void _onSourceFailed(int sessionToken, String reason) {
    if (sessionToken != _sessionId || !mounted) return;

    if (kDebugMode) {
      debugPrint('[PlayerSession: $sessionToken] FAILED: $reason');
    }

    _sources[_currentSourceIndex].health = SourceHealth.failed;
    _exhaustedSources.add(_currentSourceIndex);

    // Look for next unexhausted server
    int nextIndex = -1;
    for (int i = 0; i < _sources.length; i++) {
      if (!_exhaustedSources.contains(i)) {
        nextIndex = i;
        break;
      }
    }

    if (nextIndex != -1) {
      // Smooth non-disruptive floating indicator
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1E1E1E),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: Row(
            children: [
              const Icon(Icons.sync_problem_rounded, color: Colors.amber, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${_sources[_currentSourceIndex]['badge']} is unresponsive. Auto-switching to ${_sources[nextIndex]['badge']}...',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      );

      _loadStreamWithSession(nextIndex);
    } else {
      // All servers exhausted in this cycle
      _playbackTimeoutTimer?.cancel();
      _domWatcherTimer?.cancel();
      setState(() {
        _playbackState = PlaybackState.failed;
        _statusMessage = 'All stream mirrors failed to respond.';
      });
    }
  }

  // ==========================================
  // 7. JS HEALTH MONITOR & DOM INJECTION
  // ==========================================

  void _handleJavaScriptMessage(JavaScriptMessage message) {
    try {
      final data = json.decode(message.message) as Map<String, dynamic>;
      final event = data['event'] as String? ?? '';

      if (kDebugMode) {
        debugPrint('[JSBridge -> Flutter] Event: $event');
      }

      switch (event) {
        case 'PLAYING':
          if (mounted && _playbackState != PlaybackState.playing) {
            setState(() {
              _playbackState = PlaybackState.playing;
              _sources[_currentSourceIndex].health = SourceHealth.working;
            });
            _playbackTimeoutTimer?.cancel();
            _startHideTimer();
          }
          break;

        case 'BUFFERING':
        case 'WAITING':
          if (mounted && _playbackState == PlaybackState.playing) {
            setState(() => _playbackState = PlaybackState.buffering);
          }
          break;

        case 'STALLED':
          if (mounted && _playbackState == PlaybackState.playing) {
            setState(() {
              _playbackState = PlaybackState.stalled;
              _sources[_currentSourceIndex].health = SourceHealth.slow;
            });
          }
          break;

        case 'PAUSED':
          if (mounted && _playbackState == PlaybackState.playing) {
            setState(() => _playbackState = PlaybackState.paused);
          }
          break;

        case 'ERROR':
          final detail = data['detail'] as String? ?? '';
          _onSourceFailed(_sessionId, 'HTML5 Video Error: $detail');
          break;
      }
    } catch (_) {}
  }

  void _injectMonitorAndAutoPlay() {
    _domWatcherTimer?.cancel();
    final currentSession = _sessionId;
    int attempts = 0;

    _domWatcherTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      attempts++;
      if (!mounted || currentSession != _sessionId || _playbackState == PlaybackState.playing || attempts > 16) {
        timer.cancel();
        return;
      }

      const script = '''
        (function() {
          try {
            window.open = function() { return null; };
            window.alert = function() {};
            window.confirm = function() { return true; };

            function post(evt, d) {
              if (window.FlutterPlayerBridge) {
                window.FlutterPlayerBridge.postMessage(JSON.stringify({ event: evt, detail: d || '' }));
              }
            }

            var v = document.querySelector('video');
            if (v) {
              if (!v.__monitored) {
                v.__monitored = true;
                v.addEventListener('playing', function() { post('PLAYING'); });
                v.addEventListener('waiting', function() { post('BUFFERING'); });
                v.addEventListener('stalled', function() { post('STALLED'); });
                v.addEventListener('pause', function() { post('PAUSED'); });
                v.addEventListener('error', function() { post('ERROR', v.error ? v.error.message : ''); });
              }

              v.muted = false;
              v.volume = 1.0;
              if (v.paused) {
                var p = v.play();
                if (p !== undefined) {
                  p.catch(function() {
                    v.muted = true;
                    v.play().catch(function(){});
                  });
                }
              }

              if (!v.paused && v.currentTime > 0) {
                post('PLAYING');
              }
            } else {
              var btn = document.querySelector('.play-btn, .vjs-big-play-button, button[aria-label="Play"], #play, .jw-display-icon-display, svg[data-icon="play"]');
              if (btn) btn.click();
            }
          } catch(e) {}
        })();
      ''';

      _executeJavaScript(script);
    });
  }

  void _executeJavaScript(String code) {
    try {
      _controller?.runJavaScript(code).catchError((_) {});
    } catch (_) {}
  }

  // ==========================================
  // 8. USER CONTROLS & TIMERS
  // ==========================================

  void _startHideTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showTopBar = false);
    });
  }

  void _toggleControlsVisibility() {
    setState(() => _showTopBar = !_showTopBar);
    if (_showTopBar) _startHideTimer();
  }

  void _showServerPickerSheet() {
    _hideControlsTimer?.cancel();
    final sources = _sources;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141414),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.tune_rounded, color: Colors.redAccent, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Audio Dubbing & Streams',
                          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(color: Colors.white12, height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: sources.length,
                    itemBuilder: (ctx, idx) {
                      final item = sources[idx];
                      final isSelected = idx == _currentSourceIndex;
                      final isFailed = item.health == SourceHealth.failed;
                      final isWorking = item.health == SourceHealth.working;

                      Color statusColor = Colors.white70;
                      String statusText = item.subtitle;

                      if (isWorking) {
                        statusColor = Colors.greenAccent;
                        statusText = '● Verified Playback Active';
                      } else if (isFailed) {
                        statusColor = Colors.redAccent;
                        statusText = '⚠ Unresponsive in this session (tap to retry)';
                      }

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.redAccent.withOpacity(0.18)
                              : Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? Colors.redAccent
                                : (isFailed ? Colors.red.withOpacity(0.3) : Colors.white10),
                            width: 1.0,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                          leading: Icon(
                            idx == 1
                                ? Icons.translate_rounded
                                : (idx == 2
                                    ? Icons.animation_rounded
                                    : (idx == 0 ? Icons.hd_rounded : Icons.dns_rounded)),
                            color: isSelected ? Colors.redAccent : statusColor,
                            size: 22,
                          ),
                          title: Text(
                            item.title,
                            style: TextStyle(
                              color: isSelected ? Colors.redAccent : Colors.white,
                              fontSize: 13.5,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            statusText,
                            style: TextStyle(
                              color: statusColor.withOpacity(0.8),
                              fontSize: 11,
                            ),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.redAccent : Colors.white12,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              item.badge,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.white70,
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(ctx);
                            _exhaustedSources.remove(idx);
                            item.health = SourceHealth.unknown;
                            _loadStreamWithSession(idx);
                            _startHideTimer();
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).then((_) => _startHideTimer());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideControlsTimer?.cancel();
    _playbackTimeoutTimer?.cancel();
    _domWatcherTimer?.cancel();

    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WakelockPlus.disable();
    super.dispose();
  }

  // ==========================================
  // 9. BUILD METHOD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final activeSource = _sources[_currentSourceIndex];
    final headerTitle = _resolvedIsTv
        ? '$_resolvedTitle • S$_resolvedSeason E$_resolvedEpisode'
        : _resolvedTitle;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // 1. Primary Fullscreen Web Canvas
            if (_controller != null) WebViewWidget(controller: _controller!),

            // 2. Full-Screen Gestures (Only active when controls are hidden to reveal top bar)
            if (!_showTopBar)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _toggleControlsVisibility,
                ),
              ),

            // 3. Smooth Connecting / Buffering Spinner
            if (_playbackState == PlaybackState.connecting || _playbackState == PlaybackState.buffering)
              Container(
                color: _playbackState == PlaybackState.connecting ? Colors.black : Colors.transparent,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(color: Colors.redAccent, strokeWidth: 2.8),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _statusMessage,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // 4. Exhausted Mirrors Recovery Card
            if (_playbackState == PlaybackState.failed)
              Container(
                color: Colors.black.withOpacity(0.94),
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 28),
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: const Color(0xFF181818),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.redAccent.withOpacity(0.6), width: 1.2),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.wifi_off_rounded, color: Colors.redAccent, size: 48),
                        const SizedBox(height: 12),
                        const Text(
                          'Playback Interrupted',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'All stream providers are currently unreachable in your region. Check internet connection or choose another source.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () {
                                _exhaustedSources.clear();
                                for (var s in _sources) {
                                  s.health = SourceHealth.unknown;
                                }
                                _loadStreamWithSession(0);
                              },
                              icon: const Icon(Icons.replay_rounded, color: Colors.white70, size: 18),
                              label: const Text('Retry All', style: TextStyle(color: Colors.white)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white24),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: _showServerPickerSheet,
                              icon: const Icon(Icons.tune_rounded, color: Colors.white, size: 18),
                              label: const Text('Select Source', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // 5. Sleek Floating Header Bar
            AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: _showTopBar ? 1.0 : 0.0,
              child: IgnorePointer(
                ignoring: !_showTopBar,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black.withOpacity(0.92), Colors.transparent],
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
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          headerTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 20),
                        tooltip: 'Reload Stream',
                        onPressed: () => _loadStreamWithSession(_currentSourceIndex),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: _showServerPickerSheet,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.redAccent.withOpacity(0.85), width: 1.0),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.tune_rounded, color: Colors.redAccent, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                activeSource.badge,
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
          ],
        ),
      ),
    );
  }
}
