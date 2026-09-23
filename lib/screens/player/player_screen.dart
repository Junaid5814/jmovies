import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class PlayerScreen extends StatefulWidget {
  final dynamic movie;
  final dynamic show;
  final int? tmdbId;
  final String? title;
  final bool isTv;
  final int? seasonNumber;
  final int? episodeNumber;
  final bool isAnime; 

  const PlayerScreen({
    super.key,
    this.movie,
    this.show,
    this.tmdbId,
    this.title,
    this.isTv = false,
    this.seasonNumber,
    this.episodeNumber,
    this.isAnime = false,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player _player;
  late final VideoController _videoController;

  StreamSubscription<String>? _errorSubscription;
  StreamSubscription<Tracks>? _tracksSubscription;
  
  bool _linkFound = false;
  bool _isWebViewFallbackMode = false; 
  bool _isLoading = true;
  
  int _currentServerIndex = 0;
  late final List<String> _globalServers;
  Timer? _serverTimeoutTimer;

  int get _resolvedId {
    if (widget.tmdbId != null && widget.tmdbId! > 0) return widget.tmdbId!;
    try { return int.tryParse(widget.movie?.id?.toString() ?? widget.show?.id?.toString() ?? '0') ?? 0; } catch (_) { return 0; }
  }

  String get _resolvedTitle => widget.title ?? 'Luxury Player';
  bool get _resolvedIsTv => widget.isTv || widget.show != null || widget.seasonNumber != null;
  int get _resolvedSeason => widget.seasonNumber ?? 1;
  int get _resolvedEpisode => widget.episodeNumber ?? 1;

  @override
  void initState() {
    super.initState();
    _enterFullscreen();
    _buildServerDatabase();

    _player = Player();
    _videoController = VideoController(_player);

    _errorSubscription = _player.stream.error.listen((message) {
      if (mounted && message.trim().isNotEmpty) _moveToNextServerOrWebView();
    });

    _startServerTimeout();
  }

  // FIXED: Servers ke sath ab ID, Season aur Episode dynamically attach hoga!
  void _buildServerDatabase() {
    final id = _resolvedId;
    final s = _resolvedSeason;
    final e = _resolvedEpisode;

    if (widget.isAnime) {
      _globalServers = [
        _resolvedIsTv ? 'https://vidsrc.me/embed/tv?tmdb=$id&season=$s&episode=$e' : 'https://vidsrc.me/embed/movie?tmdb=$id',
        _resolvedIsTv ? 'https://autoembed.cc/embed/player.php?id=$id&s=$s&e=$e' : 'https://autoembed.cc/embed/player.php?id=$id',
        _resolvedIsTv ? 'https://vidcore.org/embed/tv?tmdb=$id&season=$s&episode=$e' : 'https://vidcore.org/embed/movie?tmdb=$id',
        _resolvedIsTv ? 'https://vidsrc.cc/v2/embed/tv/$id/$s/$e' : 'https://vidsrc.cc/v2/embed/movie/$id',
      ];
    } else {
      _globalServers = [
        _resolvedIsTv ? 'https://autoembed.cc/embed/player.php?id=$id&s=$s&e=$e' : 'https://autoembed.cc/embed/player.php?id=$id',
        _resolvedIsTv ? 'https://vidsrc.sbs/embed/tv?tmdb=$id&season=$s&episode=$e' : 'https://vidsrc.sbs/embed/movie?tmdb=$id',
        _resolvedIsTv ? 'https://vidsrc.me/embed/tv?tmdb=$id&season=$s&episode=$e' : 'https://vidsrc.me/embed/movie?tmdb=$id',
        _resolvedIsTv ? 'https://vidsrc.cc/v2/embed/tv/$id/$s/$e' : 'https://vidsrc.cc/v2/embed/movie/$id',
        _resolvedIsTv ? 'https://vidlink.pro/tv/$id/$s/$e?autoplay=true' : 'https://vidlink.pro/movie/$id?autoplay=true',
      ];
    }
  }

  void _startServerTimeout() {
    _serverTimeoutTimer?.cancel();
    _serverTimeoutTimer = Timer(const Duration(seconds: 8), () { // 6 se 8 seconds behtar hai proxy ke liye
      if (!_linkFound && mounted && !_isWebViewFallbackMode) {
        _moveToNextServerOrWebView();
      }
    });
  }

  void _moveToNextServerOrWebView() {
    if (_currentServerIndex < _globalServers.length - 1) {
      if (mounted) {
        setState(() {
          _currentServerIndex++;
        });
        _startServerTimeout();
      }
    } else {
      if (mounted) {
        setState(() {
          _isWebViewFallbackMode = true;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _enterFullscreen() async {
    await WakelockPlus.enable();
    await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _playExtractedLink(String url, Map<String, String> extractedHeaders) async {
    if (!mounted) return;
    _serverTimeoutTimer?.cancel();
    
    final Map<String, String> headers = {
      "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
    };
    headers.addAll(extractedHeaders);

    try {
      await _player.open(Media(url, httpHeaders: headers), play: true);
      if (mounted) {
        setState(() {
          _linkFound = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      _moveToNextServerOrWebView();
    }
  }

  @override
  void dispose() {
    _serverTimeoutTimer?.cancel();
    _errorSubscription?.cancel();
    _tracksSubscription?.cancel();
    _player.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          
          // 1. BACKGROUND ENGINE
          // FIXED: WebView tab hi chalega jab Native player off ho (Double Audio Fix)
          if (!_linkFound || _isWebViewFallbackMode)
            InAppWebView(
              // FIXED: Key property adds fresh reload on server change
              key: ValueKey(_currentServerIndex),
              initialUrlRequest: URLRequest(url: WebUri(_globalServers[_currentServerIndex])),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                mediaPlaybackRequiresUserGesture: false,
                useShouldInterceptRequest: true,
                userAgent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
              ),
              onLoadStop: (controller, url) async {
                 await controller.evaluateJavascript(source: """
                   setInterval(function() {
                     var btn = document.querySelector('.play-btn, #play-button, .vjs-big-play-button');
                     if (btn) btn.click();
                   }, 1000);
                 """);
              },
              shouldInterceptRequest: (controller, request) async {
                final reqUrl = request.url.toString();
                if ((reqUrl.contains('.m3u8') || reqUrl.contains('.mp4')) && !_linkFound && !_isWebViewFallbackMode) {
                  if (!reqUrl.contains('blank') && !reqUrl.contains('dummy')) {
                    Map<String, String> headers = {};
                    request.headers?.forEach((key, value) => headers[key] = value.toString());
                    Future.microtask(() => _playExtractedLink(reqUrl, headers));
                  }
                }
                return null;
              },
            ),

          // 2. PREMIUM NATIVE PLAYER 
          if (_linkFound && !_isWebViewFallbackMode)
            Container(
              color: Colors.black,
              child: Video(
                controller: _videoController,
                fit: BoxFit.contain,
                controls: AdaptiveVideoControls,
              ),
            ),

          // 3. SEAMLESS LUXURY LOADING OVERLAY
          if (_isLoading && !_isWebViewFallbackMode)
            Container(
              color: Colors.black,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Color(0xFFE50914), strokeWidth: 3),
                    const SizedBox(height: 16),
                    Text(
                      'Optimizing Stream (Server ${_currentServerIndex + 1})...', 
                      style: const TextStyle(color: Colors.white70, fontSize: 13, letterSpacing: 0.5),
                    ),
                  ],
                ),
              ),
            ),

          // 4. FLOATING NATIVE BACK BUTTON
          Positioned(
            top: 16,
            left: 16,
            child: SafeArea(
              child: IconButton(
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
