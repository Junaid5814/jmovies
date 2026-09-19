import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

// ============================================================
// 1. PLAYBACK MODELS & ENUMS
// ============================================================

enum PlaybackState {
  idle,
  loading,
  detectingPlayer,
  ready,
  playing,
  buffering,
  stalled,
  paused,
  recovering,
  ended,
  failed,
}

enum SourceHealth {
  unknown,
  working,
  slow,
  failed,
}

enum FailureType {
  network,
  timeout,
  playerNotFound,
  playback,
  decode,
  unsupported,
  autoplay,
  unknown,
}

class StreamSource {
  final int index;
  final String title;
  final String subtitle;
  final String badge;
  final String category;
  final String url;

  SourceHealth health;
  int retryCount = 0;
  int bufferCount = 0;
  Duration? startupTime;
  DateTime? lastSuccess;
  DateTime? lastFailure;
  String? lastError;

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

// ============================================================
// 2. PLAYER SCREEN WIDGET
// ============================================================

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

// ============================================================
// 3. STATE & CONTROLLER LIFECYCLE
// ============================================================

class _PlayerScreenState extends State<PlayerScreen> with WidgetsBindingObserver {
  WebViewController? _controller;
  List<StreamSource> _sources = [];

  int _sessionId = 0;
  int _currentSourceIndex = 0;
  PlaybackState _playbackState = PlaybackState.idle;
  String _statusMessage = 'Initializing player engine...';

  bool _showControls = true;
  bool _playerDetected = false;
  bool _audioMutedByPolicy = false;
  bool _isDisposing = false;

  Timer? _controlsTimer;
  Timer? _startupTimer;
  Timer? _playerDetectionTimer;
  Timer? _bufferTimer;
  Timer? _progressTimer;
  Timer? _recoveryTimer;

  final Set<int> _exhaustedSources = {};
  final Map<int, int> _sourceAttempts = {};

  DateTime? _sourceStartedAt;
  DateTime? _lastProgressAt;
  double _lastVideoTime = -1;

  static const Duration startupTimeout = Duration(seconds: 14);
  static const Duration bufferTimeout = Duration(seconds: 10);
  static const Duration stallTimeout = Duration(seconds: 8);
  static const int maxRetriesPerSource = 2;

  // ==========================================================
  // 4. METADATA RESOLUTION
  // ==========================================================

  int get _resolvedId {
    if (widget.tmdbId != null && widget.tmdbId! > 0) return widget.tmdbId!;
    if (widget.id != null && widget.id! > 0) return widget.id!;

    for (final obj in [
      widget.movie,
      widget.show,
      widget.mediaItem,
      widget.media,
      widget.item,
    ]) {
      if (obj == null) continue;
      try {
        final value = obj.id;
        if (value != null) {
          final parsed = int.tryParse(value.toString());
          if (parsed != null && parsed > 0) return parsed;
        }
      } catch (_) {}
    }
    return 0;
  }

  String get _resolvedTitle {
    if (widget.title != null && widget.title!.trim().isNotEmpty) return widget.title!.trim();
    if (widget.name != null && widget.name!.trim().isNotEmpty) return widget.name!.trim();

    for (final obj in [
      widget.movie,
      widget.show,
      widget.mediaItem,
      widget.media,
      widget.item,
    ]) {
      if (obj == null) continue;
      try {
        final value = obj.title ?? obj.name ?? obj.originalTitle ?? obj.originalName;
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString().trim();
        }
      } catch (_) {}
    }
    return 'Streaming';
  }

  bool get _resolvedIsTv {
    if (widget.isTv) return true;
    if (widget.isMovie == false) return true;
    if (widget.show != null || widget.episode != null) return true;
    if ((widget.seasonNumber ?? 0) > 0 || (widget.season ?? 0) > 0) return true;

    for (final obj in [
      widget.mediaItem,
      widget.movie,
      widget.show,
      widget.media,
      widget.item,
    ]) {
      if (obj == null) continue;
      try {
        if (obj.mediaType == 'tv' || obj.isTv == true) return true;
      } catch (_) {}
    }
    return false;
  }

  int get _resolvedSeason {
    if ((widget.seasonNumber ?? 0) > 0) return widget.seasonNumber!;
    if ((widget.season ?? 0) > 0) return widget.season!;
    if (widget.episode != null) {
      try {
        final value = widget.episode.seasonNumber ?? widget.episode.season;
        if (value != null) return int.tryParse(value.toString()) ?? 1;
      } catch (_) {}
    }
    return 1;
  }

  int get _resolvedEpisode {
    if ((widget.episodeNumber ?? 0) > 0) return widget.episodeNumber!;
    if ((widget.number ?? 0) > 0) return widget.number!;
    if (widget.episode != null) {
      try {
        final value = widget.episode.episodeNumber ??
            widget.episode.episode ??
            widget.episode.number;
        if (value != null) return int.tryParse(value.toString()) ?? 1;
      } catch (_) {}
    }
    return 1;
  }

  // ==========================================================
  // 5. WORKING PRODUCTION SOURCE MATRIX
  // ==========================================================

  void _buildSourcesList() {
    final id = _resolvedId;
    final season = _resolvedSeason;
    final episode = _resolvedEpisode;
    final query = Uri.encodeComponent('$_resolvedTitle full episode $episode');

    if (_resolvedIsTv) {
      _sources = [
        StreamSource(
          index: 0,
          title: 'Server 1: VidLink Original (1080p HD)',
          subtitle: 'High-speed clean stream with subtitles',
          badge: 'English HD',
          category: 'Primary',
          url: 'https://vidlink.pro/tv/$id/$season/$episode?autoplay=true',
        ),
        StreamSource(
          index: 1,
          title: 'Server 2: MultiEmbed (Hindi / Multi-Audio)',
          subtitle: 'Includes Hindi, Urdu, Tamil & regional audio tracks',
          badge: 'Hindi Dubbed',
          category: 'Dubbed',
          url: 'https://multiembed.mov/?video_id=$id&tmdb=1&s=$season&e=$episode&autoplay=1',
        ),
        StreamSource(
          index: 2,
          title: 'Server 3: Anime Special Master (EmbedSu)',
          subtitle: 'Original Japanese audio with English & multi subs',
          badge: 'Anime JP/EN',
          category: 'Dubbed',
          url: 'https://embed.su/embed/tv/$id/$season/$episode',
        ),
        StreamSource(
          index: 3,
          title: 'Server 4: AutoEmbed Multi-Lang',
          subtitle: 'French, Spanish, and European multi-language streams',
          badge: 'French / Global',
          category: 'Mirrors',
          url: 'https://player.autoembed.cc/embed/tv/$id/$season/$episode',
        ),
        StreamSource(
          index: 4,
          title: 'Server 5: VidSrc Pro CDN',
          subtitle: 'Fast alternative 1080p fallback server',
          badge: 'Mirror Pro',
          category: 'Mirrors',
          url: 'https://vidsrc.cc/v2/embed/tv/$id/$season/$episode',
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

  // ==========================================================
  // 6. INITIALIZATION & LIFECYCLE
  // ==========================================================

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
    _initializeWebView();
    _startControlsTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isDisposing) return;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _executeJavaScript("var v = document.querySelector('video'); if(v) v.pause();");
    } else if (state == AppLifecycleState.resumed) {
      if (_playbackState == PlaybackState.playing || _playbackState == PlaybackState.buffering) {
        _executeJavaScript("var v = document.querySelector('video'); if(v && v.paused) v.play();");
      }
    }
  }

  // ==========================================================
  // 7. WEBVIEW & HOST WHITELIST
  // ==========================================================

  void _initializeWebView() {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
      )
      ..addJavaScriptChannel(
        'FlutterPlayerBridge',
        onMessageReceived: _handleJavaScriptMessage,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: _onPageStarted,
          onPageFinished: _onPageFinished,
          onWebResourceError: _onWebResourceError,
          onNavigationRequest: _onNavigationRequest,
        ),
      );

    _controller = controller;
    _loadSource(0);
  }

  void _onPageStarted(String url) {
    _playerDetected = false;
    _log('PAGE STARTED: $url');
  }

  void _onPageFinished(String url) {
    if (!mounted || _isDisposing) return;
    _log('PAGE FINISHED: $url');

    if (_playbackState == PlaybackState.loading) {
      setState(() {
        _playbackState = PlaybackState.detectingPlayer;
        _statusMessage = 'Connecting video stream...';
      });
    }
    _startPlayerDetection();
  }

  void _onWebResourceError(WebResourceError error) {
    if (!mounted || _isDisposing) return;
    if (error.isForMainFrame != true) return;

    final description = error.description.toLowerCase();
    final networkFailure = description.contains('err_name_not_resolved') ||
        description.contains('err_connection_refused') ||
        description.contains('err_connection_timed_out') ||
        description.contains('err_timed_out') ||
        description.contains('err_internet_disconnected') ||
        description.contains('err_address_unreachable') ||
        description.contains('err_cert') ||
        description.contains('err_ssl');

    if (networkFailure) {
      _failCurrentSource(
        FailureType.network,
        'Server unreachable (${error.description})',
        sessionToken: _sessionId,
      );
    }
  }

  NavigationDecision _onNavigationRequest(NavigationRequest request) {
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
    final allowedDomains = <String>{
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
    };

    final isAllowed = allowedDomains.any((domain) => host == domain || host.endsWith('.$domain'));
    if (isAllowed || uri.path.contains('.m3u8') || uri.path.contains('.mp4') || uri.path.contains('.ts')) {
      return NavigationDecision.navigate;
    }

    if (request.isMainFrame) {
      _log('Blocked main-frame ad redirect: ${request.url}');
      return NavigationDecision.prevent;
    }

    return NavigationDecision.navigate;
  }

  // ==========================================================
  // 8. SESSION-AWARE SOURCE LOADER
  // ==========================================================

  void _loadSource(int index, {bool retry = false}) {
    if (!mounted || _isDisposing) return;

    if (index < 0 || index >= _sources.length) {
      _showAllSourcesFailed();
      return;
    }

    final source = _sources[index];
    if (!retry && _exhaustedSources.contains(index)) {
      _tryNextSource();
      return;
    }

    _cancelPlaybackTimers();
    _sessionId++;
    final session = _sessionId;

    _currentSourceIndex = index;
    _playerDetected = false;
    _audioMutedByPolicy = false;
    _lastVideoTime = -1;
    _lastProgressAt = DateTime.now();
    _sourceStartedAt = DateTime.now();

    _sourceAttempts[index] = (_sourceAttempts[index] ?? 0) + 1;
    source.retryCount = _sourceAttempts[index]!;
    source.health = SourceHealth.unknown;
    source.lastError = null;

    setState(() {
      _playbackState = PlaybackState.loading;
      _statusMessage = 'Loading ${source.badge}...';
    });

    _log('[SESSION $session] Loading source $index: ${source.url}');

    final uri = Uri.tryParse(source.url);
    if (uri == null) {
      _failCurrentSource(FailureType.unknown, 'Invalid source URL', sessionToken: session);
      return;
    }

    _controller?.loadRequest(uri);

    // Startup Watchdog
    _startupTimer = Timer(startupTimeout, () {
      if (!_isCurrentSession(session) || !mounted) return;
      if (_playbackState != PlaybackState.playing && _playbackState != PlaybackState.paused) {
        _failCurrentSource(
          FailureType.timeout,
          'Playback startup timed out (14s)',
          sessionToken: session,
        );
      }
    });
  }

  // ==========================================================
  // 9. PLAYER DETECTION & AD SHIELD
  // ==========================================================

  void _startPlayerDetection() {
    _playerDetectionTimer?.cancel();
    final session = _sessionId;
    int attempts = 0;

    _playerDetectionTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted || _isDisposing || !_isCurrentSession(session) || _playbackState == PlaybackState.playing) {
        timer.cancel();
        return;
      }

      attempts++;
      _executeJavaScript(_buildPlayerDetectionScript());

      if (_playerDetected || attempts > 24) {
        timer.cancel();
      }
    });
  }

  String _buildPlayerDetectionScript() {
    return '''
(function() {
  try {
    window.open = function() { return null; };
    window.alert = function() {};
    window.confirm = function() { return true; };

    function post(event, detail) {
      try {
        if (window.FlutterPlayerBridge) {
          window.FlutterPlayerBridge.postMessage(JSON.stringify({ event: event, detail: detail || '' }));
        }
      } catch (_) {}
    }

    var video = document.querySelector('video');
    if (video) {
      if (!video.__flutterBridgeInstalled) {
        video.__flutterBridgeInstalled = true;
        video.addEventListener('loadedmetadata', function() { post('READY'); });
        video.addEventListener('canplay', function() { post('READY'); });
        video.addEventListener('playing', function() { post('PLAYING'); });
        video.addEventListener('waiting', function() { post('BUFFERING'); });
        video.addEventListener('stalled', function() { post('STALLED'); });
        video.addEventListener('pause', function() { post('PAUSED'); });
        video.addEventListener('ended', function() { post('ENDED'); });
        video.addEventListener('error', function() {
          var msg = video.error ? (video.error.code + ':' + (video.error.message || '')) : '';
          post('ERROR', msg);
        });
      }

      post('VIDEO_FOUND', JSON.stringify({ paused: video.paused, currentTime: video.currentTime }));

      if (video.paused) {
        video.muted = false;
        video.volume = 1.0;
        var p = video.play();
        if (p && p.catch) {
          p.catch(function() {
            video.muted = true;
            video.play().catch(function() {});
            post('AUTOPLAY_MUTED');
          });
        }
      }

      if (!video.paused && video.currentTime >= 0) {
        post('PLAYING');
      }
      return;
    }

    var button = document.querySelector('.vjs-big-play-button, .jw-display-icon-display, button[aria-label="Play"], [aria-label*="Play"], .play-btn, #play');
    if (button) {
      button.click();
    }
  } catch (e) {
    post('JS_ERROR', String(e));
  }
})();
''';
  }

  // ==========================================================
  // 10. REAL JS EVENTS & STALL DETECTION
  // ==========================================================

  void _handleJavaScriptMessage(JavaScriptMessage message) {
    if (!mounted || _isDisposing) return;

    try {
      final decoded = jsonDecode(message.message);
      if (decoded is! Map<String, dynamic>) return;

      final event = decoded['event']?.toString() ?? '';
      final detail = decoded['detail']?.toString() ?? '';

      _log('JS EVENT: $event $detail');

      switch (event) {
        case 'VIDEO_FOUND':
        case 'READY':
          _playerDetected = true;
          if (_playbackState == PlaybackState.loading || _playbackState == PlaybackState.detectingPlayer) {
            setState(() {
              _playbackState = PlaybackState.ready;
              _statusMessage = 'Starting stream...';
            });
          }
          break;

        case 'PLAYING':
          _onPlaying();
          break;

        case 'PROGRESS':
          _handleProgress(detail);
          break;

        case 'BUFFERING':
          _onBuffering();
          break;

        case 'STALLED':
          _onStalled();
          break;

        case 'PAUSED':
          _onPaused();
          break;

        case 'ENDED':
          _onEnded();
          break;

        case 'AUTOPLAY_MUTED':
          _audioMutedByPolicy = true;
          if (mounted) {
            setState(() => _statusMessage = 'Muted autoplay active. Tap video to unmute.');
          }
          break;

        case 'ERROR':
          _failCurrentSource(FailureType.playback, 'HTML5 Video error: $detail');
          break;

        case 'JS_ERROR':
          _log('JavaScript DOM error: $detail');
          break;
      }
    } catch (e) {
      _log('Bridge parse error: $e');
    }
  }

  void _onPlaying() {
    if (!mounted) return;
    final source = _sources[_currentSourceIndex];

    if (_sourceStartedAt != null) {
      source.startupTime = DateTime.now().difference(_sourceStartedAt!);
    }

    source.health = SourceHealth.working;
    source.lastSuccess = DateTime.now();
    _lastProgressAt = DateTime.now();

    if (_playbackState != PlaybackState.playing) {
      setState(() {
        _playbackState = PlaybackState.playing;
        _statusMessage = '';
      });
    }

    _startupTimer?.cancel();
    _bufferTimer?.cancel();
    _recoveryTimer?.cancel();

    _startProgressMonitor();
    _startControlsTimer();
  }

  void _onBuffering() {
    if (!mounted || _playbackState == PlaybackState.paused) return;

    _sources[_currentSourceIndex].bufferCount++;
    if (_playbackState != PlaybackState.buffering) {
      setState(() {
        _playbackState = PlaybackState.buffering;
        _statusMessage = 'Buffering stream...';
      });
    }

    _bufferTimer?.cancel();
    final session = _sessionId;

    _bufferTimer = Timer(bufferTimeout, () {
      if (!_isCurrentSession(session) || !mounted) return;
      if (_playbackState == PlaybackState.buffering) {
        _recoverPlayback(reason: 'Buffering timeout (10s)');
      }
    });
  }

  void _onStalled() {
    if (!mounted || _playbackState == PlaybackState.paused) return;
    setState(() {
      _playbackState = PlaybackState.stalled;
      _statusMessage = 'Playback stalled...';
    });
    _recoverPlayback(reason: 'Video playback stalled', delay: stallTimeout);
  }

  void _onPaused() {
    if (!mounted) return;
    if (_playbackState == PlaybackState.playing) {
      setState(() {
        _playbackState = PlaybackState.paused;
        _statusMessage = 'Paused';
      });
    }
  }

  void _onEnded() {
    if (!mounted) return;
    _cancelPlaybackTimers();
    setState(() {
      _playbackState = PlaybackState.ended;
      _statusMessage = 'Stream completed';
    });
  }

  // ==========================================================
  // 11. PROGRESS MONITOR
  // ==========================================================

  void _startProgressMonitor() {
    _progressTimer?.cancel();
    final session = _sessionId;

    _progressTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted || _isDisposing || !_isCurrentSession(session)) {
        timer.cancel();
        return;
      }
      if (_playbackState != PlaybackState.playing) return;

      const script = '''
(function() {
  try {
    var v = document.querySelector('video');
    if (v && window.FlutterPlayerBridge) {
      window.FlutterPlayerBridge.postMessage(JSON.stringify({
        event: 'PROGRESS',
        detail: JSON.stringify({ currentTime: v.currentTime, paused: v.paused })
      }));
    }
  } catch (_) {}
})();
''';
      _executeJavaScript(script);
    });
  }

  void _handleProgress(String detail) {
    try {
      final data = jsonDecode(detail);
      final currentTime = (data['currentTime'] as num?)?.toDouble() ?? 0;
      final paused = data['paused'] == true;

      if (currentTime > _lastVideoTime + 0.05) {
        _lastVideoTime = currentTime;
        _lastProgressAt = DateTime.now();
        if (_playbackState == PlaybackState.stalled) {
          _onPlaying();
        }
        return;
      }

      if (!paused && _lastProgressAt != null && DateTime.now().difference(_lastProgressAt!) >= stallTimeout) {
        _recoverPlayback(reason: 'No forward playback progress detected');
      }
    } catch (_) {}
  }

  // ==========================================================
  // 12. SMART RECOVERY & SILENT FAILOVER
  // ==========================================================

  void _recoverPlayback({required String reason, Duration delay = const Duration(seconds: 1)}) {
    if (!mounted || _isDisposing || _playbackState == PlaybackState.recovering) return;

    final session = _sessionId;
    setState(() {
      _playbackState = PlaybackState.recovering;
      _statusMessage = 'Recovering stream...';
    });

    _recoveryTimer?.cancel();
    _recoveryTimer = Timer(delay, () async {
      if (!mounted || _isDisposing || !_isCurrentSession(session)) return;

      _executeJavaScript("var v = document.querySelector('video'); if(v) v.play().catch(function(){});");
      await Future<void>.delayed(const Duration(seconds: 3));

      if (!mounted || _isDisposing || !_isCurrentSession(session)) return;

      if (_playbackState == PlaybackState.recovering ||
          _playbackState == PlaybackState.stalled ||
          _playbackState == PlaybackState.buffering) {
        _retryOrAdvance(reason: reason);
      }
    });
  }

  void _retryOrAdvance({required String reason}) {
    final index = _currentSourceIndex;
    final attempts = _sourceAttempts[index] ?? 0;

    if (attempts < maxRetriesPerSource) {
      _loadSource(index, retry: true);
      return;
    }
    _failCurrentSource(FailureType.timeout, reason);
  }

  void _failCurrentSource(FailureType type, String reason, {int? sessionToken}) {
    if (!mounted || _isDisposing) return;
    if (sessionToken != null && sessionToken != _sessionId) return;

    final index = _currentSourceIndex;
    final source = _sources[index];

    source.health = SourceHealth.failed;
    source.lastFailure = DateTime.now();
    source.lastError = reason;
    _exhaustedSources.add(index);
    _cancelPlaybackTimers();

    _showRecoverySnackBar(source);
    _tryNextSource();
  }

  void _tryNextSource() {
    for (int i = 0; i < _sources.length; i++) {
      if (!_exhaustedSources.contains(i)) {
        _loadSource(i);
        return;
      }
    }
    _showAllSourcesFailed();
  }

  void _showAllSourcesFailed() {
    if (!mounted) return;
    _cancelPlaybackTimers();
    setState(() {
      _playbackState = PlaybackState.failed;
      _statusMessage = 'All sources failed to load';
    });
  }

  void _retryAll() {
    _exhaustedSources.clear();
    _sourceAttempts.clear();
    for (final source in _sources) {
      source.health = SourceHealth.unknown;
      source.retryCount = 0;
      source.bufferCount = 0;
      source.lastError = null;
    }
    _loadSource(0);
  }

  // ==========================================================
  // 13. CONTROLS TIMING & UI HELPERS
  // ==========================================================

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _startControlsTimer();
  }

  void _showServerPicker() {
    _controlsTimer?.cancel();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF111111),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * .82,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 10, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.tune_rounded, color: Colors.redAccent),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Audio Dubbing & Streams',
                          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close, color: Colors.white54),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _sources.length,
                    itemBuilder: (_, index) {
                      final source = _sources[index];
                      final selected = index == _currentSourceIndex;
                      final failed = source.health == SourceHealth.failed;
                      final working = source.health == SourceHealth.working;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: selected
                              ? Colors.redAccent.withOpacity(.16)
                              : Colors.white.withOpacity(.04),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected ? Colors.redAccent : (failed ? Colors.red.withOpacity(0.3) : Colors.white12),
                          ),
                        ),
                        child: ListTile(
                          onTap: () {
                            Navigator.pop(ctx);
                            _exhaustedSources.remove(index);
                            _sourceAttempts[index] = 0;
                            source.health = SourceHealth.unknown;
                            _loadSource(index);
                          },
                          leading: Icon(
                            failed
                                ? Icons.error_outline
                                : (working
                                    ? Icons.check_circle_outline
                                    : (index == 1 ? Icons.translate_rounded : Icons.play_circle_outline)),
                            color: failed
                                ? Colors.redAccent
                                : (working ? Colors.greenAccent : Colors.white70),
                          ),
                          title: Text(
                            source.title,
                            style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            failed
                                ? 'Failed — tap to retry'
                                : (working ? '● Playback verified active' : source.subtitle),
                            style: TextStyle(
                              color: failed
                                  ? Colors.redAccent
                                  : (working ? Colors.greenAccent : Colors.white54),
                              fontSize: 11,
                            ),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: selected ? Colors.redAccent : Colors.white12,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              source.badge,
                              style: TextStyle(
                                color: selected ? Colors.white : Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
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
    ).then((_) {
      if (mounted) _startControlsTimer();
    });
  }

  void _showRecoverySnackBar(StreamSource source) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        backgroundColor: const Color(0xFF202020),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Row(
          children: [
            const Icon(Icons.sync_problem, color: Colors.amber, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${source.badge} unresponsive. Switching to backup server...',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isCurrentSession(int session) => session == _sessionId;

  void _cancelPlaybackTimers() {
    _startupTimer?.cancel();
    _playerDetectionTimer?.cancel();
    _bufferTimer?.cancel();
    _progressTimer?.cancel();
    _recoveryTimer?.cancel();

    _startupTimer = null;
    _playerDetectionTimer = null;
    _bufferTimer = null;
    _progressTimer = null;
    _recoveryTimer = null;
  }

  void _executeJavaScript(String script) {
    if (_isDisposing) return;
    try {
      _controller?.runJavaScript(script).catchError((_) {});
    } catch (_) {}
  }

  void _log(String message) {
    if (kDebugMode) debugPrint('[JMoviesPlayer] $message');
  }

  @override
  void dispose() {
    _isDisposing = true;
    WidgetsBinding.instance.removeObserver(this);
    _controlsTimer?.cancel();
    _cancelPlaybackTimers();

    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WakelockPlus.disable();
    super.dispose();
  }

  // ==========================================================
  // 14. BUILD METHOD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final source = _sources.isNotEmpty ? _sources[_currentSourceIndex] : null;
    final title = _resolvedIsTv
        ? '$_resolvedTitle • S$_resolvedSeason E$_resolvedEpisode'
        : _resolvedTitle;

    final isOverlayVisible = _playbackState == PlaybackState.loading ||
        _playbackState == PlaybackState.detectingPlayer ||
        _playbackState == PlaybackState.buffering ||
        _playbackState == PlaybackState.recovering ||
        _playbackState == PlaybackState.stalled;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Primary Fullscreen Webview Canvas
            if (controller != null) WebViewWidget(controller: controller),

            // 2. Translucent Tap Listener (Only active when controls are hidden to reveal top bar)
            if (!_showControls)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _toggleControls,
                ),
              ),

            // 3. Status & Buffering Indicator
            if (isOverlayVisible)
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(.85),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2.8, color: Colors.redAccent),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _statusMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),

            // 4. Exhausted Sources Recovery Overlay
            if (_playbackState == PlaybackState.failed)
              Container(
                color: Colors.black.withOpacity(.95),
                alignment: Alignment.center,
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF181818),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.redAccent.withOpacity(.5)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.wifi_off_rounded, color: Colors.redAccent, size: 48),
                        const SizedBox(height: 14),
                        const Text(
                          'Playback Interrupted',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Available stream mirrors did not respond in your region. Check your internet connection or switch to fallback.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white60, fontSize: 13),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _retryAll,
                              icon: const Icon(Icons.refresh, color: Colors.white70),
                              label: const Text('Retry All', style: TextStyle(color: Colors.white)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white24),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: _showServerPicker,
                              icon: const Icon(Icons.tune, color: Colors.white),
                              label: const Text('Sources', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
              duration: const Duration(milliseconds: 220),
              opacity: _showControls ? 1.0 : 0.0,
              child: IgnorePointer(
                ignoring: !_showControls,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
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
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(.65),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 17),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 20),
                        tooltip: 'Reload Stream',
                        onPressed: () {
                          _sourceAttempts[_currentSourceIndex] = 0;
                          _exhaustedSources.remove(_currentSourceIndex);
                          _loadSource(_currentSourceIndex);
                        },
                      ),
                      const SizedBox(width: 4),
                      if (source != null)
                        InkWell(
                          onTap: _showServerPicker,
                          borderRadius: BorderRadius.circular(22),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: Colors.redAccent),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.tune, color: Colors.redAccent, size: 14),
                                const SizedBox(width: 6),
                                Text(
                                  source.badge,
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
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
