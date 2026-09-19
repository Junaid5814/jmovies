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
  final int? tmdbId;
  final String? title;
  final bool isTv;
  final int? seasonNumber;
  final int? episodeNumber;

  const PlayerScreen({
    super.key,
    this.movie,
    this.show,
    this.episode,
    this.mediaItem,
    this.tmdbId,
    this.title,
    this.isTv = false,
    this.seasonNumber,
    this.episodeNumber,
  });

  const PlayerScreen.forMovie(
    this.movie, {
    super.key,
    this.show,
    this.episode,
    this.mediaItem,
    this.tmdbId,
    this.title,
    this.isTv = false,
    this.seasonNumber,
    this.episodeNumber,
  });

  const PlayerScreen.forEpisode({
    super.key,
    this.show,
    this.episode,
    this.movie,
    this.mediaItem,
    this.tmdbId,
    this.title,
    this.isTv = true,
    this.seasonNumber,
    this.episodeNumber,
    int? season,
    int? number,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final WebViewController _controller;
  int _currentSourceIndex = 0;
  bool _showTopBar = true;
  Timer? _hideTimer;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  Timer? _autoFallbackTimer;

  int get _resolvedId {
    if (widget.tmdbId != null && widget.tmdbId! > 0) return widget.tmdbId!;
    for (var obj in [widget.movie, widget.show, widget.mediaItem]) {
      if (obj != null) {
        try {
          final id = obj.id;
          if (id != null) {
            final parsed = int.tryParse(id.toString());
            if (parsed != null && parsed > 0) return parsed;
          }
        } catch (_) {}
      }
    }
    return 0;
  }

  String get _resolvedTitle {
    if (widget.title != null && widget.title!.isNotEmpty) return widget.title!;
    for (var obj in [widget.movie, widget.show, widget.mediaItem]) {
      if (obj != null) {
        try {
          final t = obj.title ?? obj.name ?? obj.originalTitle ?? obj.originalName;
          if (t != null && t.toString().isNotEmpty) return t.toString();
        } catch (_) {}
      }
    }
    return 'Streaming';
  }

  bool get _resolvedIsTv {
    if (widget.isTv) return true;
    if (widget.show != null || widget.episode != null) return true;
    if (widget.seasonNumber != null && widget.seasonNumber! > 0) return true;
    for (var obj in [widget.mediaItem, widget.movie, widget.show]) {
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
    if (widget.episode != null) {
      try {
        final e = widget.episode.episodeNumber ?? widget.episode.episode ?? widget.episode.number;
        if (e != null) return int.tryParse(e.toString()) ?? 1;
      } catch (_) {}
    }
    return 1;
  }

  List<Map<String, String>> get _sources {
    final id = _resolvedId;
    final s = _resolvedSeason;
    final e = _resolvedEpisode;
    final query = Uri.encodeComponent('$_resolvedTitle full episode $e');

    if (_resolvedIsTv) {
      return [
        {
          'title': 'Server 1: VidLink Original (1080p HD)',
          'subtitle': 'Fastest buffer-free stream with multi subtitles',
          'badge': 'English HD',
          'group': 'Primary Streams',
          'url': 'https://vidlink.pro/tv/$id/$s/$e?autoplay=true',
        },
        {
          'title': 'Server 2: Hindi Dubbed & Multi-Audio',
          'subtitle': 'Includes Hindi, Urdu, Tamil, and English tracks',
          'badge': 'Hindi Dubbed',
          'group': 'Dubbing & Regional',
          'url': 'https://multiembed.mov/?video_id=$id&tmdb=1&s=$s&e=$e&autoplay=1',
        },
        {
          'title': 'Server 3: Anime Special (EmbedSu)',
          'subtitle': 'Japanese audio with English/Multi subs & fast CDN',
          'badge': 'Anime JP/EN',
          'group': 'Dubbing & Regional',
          'url': 'https://embed.su/embed/tv/$id/$s/$e',
        },
        {
          'title': 'Server 4: AutoEmbed Multi-Lang',
          'subtitle': 'European, French, and Spanish dubbed streams',
          'badge': 'Multi / French',
          'group': 'Fast Mirrors',
          'url': 'https://player.autoembed.cc/embed/tv/$id/$s/$e',
        },
        {
          'title': 'Server 5: VidSrc Pro Mirror',
          'subtitle': 'Ultra-fast fallback server for TV episodes',
          'badge': 'Mirror 1',
          'group': 'Fast Mirrors',
          'url': 'https://vidsrc.cc/v2/embed/tv/$id/$s/$e',
        },
        {
          'title': 'Server 6: Pakistani / Regional Direct Stream',
          'subtitle': 'High quality official stream for Asian/Pakistani dramas',
          'badge': 'Official HD',
          'group': 'Dubbing & Regional',
          'url': 'https://www.youtube.com/embed?listType=search&list=$query&autoplay=1',
        },
      ];
    } else {
      return [
        {
          'title': 'Server 1: VidLink Original (1080p HD)',
          'subtitle': 'Highest bitrate 1080p stream with multi subtitles',
          'badge': 'English HD',
          'group': 'Primary Streams',
          'url': 'https://vidlink.pro/movie/$id?autoplay=true',
        },
        {
          'title': 'Server 2: Hindi Dubbed & Multi-Audio',
          'subtitle': 'Includes Hindi, Urdu & regional Indian dubs',
          'badge': 'Hindi Dubbed',
          'group': 'Dubbing & Regional',
          'url': 'https://multiembed.mov/?video_id=$id&tmdb=1&autoplay=1',
        },
        {
          'title': 'Server 3: Anime Movie Master (EmbedSu)',
          'subtitle': 'Original Japanese sound + English & Multi subtitles',
          'badge': 'Anime JP/EN',
          'group': 'Dubbing & Regional',
          'url': 'https://embed.su/embed/movie/$id',
        },
        {
          'title': 'Server 4: AutoEmbed Multi-Lang',
          'subtitle': 'French, Spanish, and European audio options',
          'badge': 'Multi / French',
          'group': 'Fast Mirrors',
          'url': 'https://player.autoembed.cc/embed/movie/$id',
        },
        {
          'title': 'Server 5: VidSrc Pro Mirror',
          'subtitle': 'Ultra-fast alternative 1080p/4K server',
          'badge': 'Mirror 1',
          'group': 'Fast Mirrors',
          'url': 'https://vidsrc.cc/v2/embed/movie/$id',
        },
        {
          'title': 'Server 6: SmashyStream Direct',
          'subtitle': 'Multi-player fallback backup source',
          'badge': 'Backup CDN',
          'group': 'Fast Mirrors',
          'url': 'https://player.smashy.stream/movie/$id',
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

    _initController();
    _loadStream(_currentSourceIndex);
    _startHideTimer();
  }

  void _initController() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent('Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36')
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _hasError = false;
              });
            }
          },
          onPageFinished: (url) {
            if (mounted) setState(() => _isLoading = false);
            _injectAdShieldAndAutoPlay();
          },
          onWebResourceError: (error) {
            // Check if main stream page failed to load
            if (error.isForMainFrame == true) {
              _handleStreamFailure('Network error: ${error.description}');
            }
          },
          onNavigationRequest: (req) {
            final u = req.url.toLowerCase();
            // Whitelist safe streaming hosts and media formats
            if (u.startsWith('blob:') ||
                u.startsWith('about:') ||
                u.contains('vidlink') ||
                u.contains('multiembed') ||
                u.contains('embed.su') ||
                u.contains('autoembed') ||
                u.contains('vidsrc') ||
                u.contains('smashy') ||
                u.contains('youtube') ||
                u.contains('googlevideo') ||
                u.contains('m3u8') ||
                u.contains('mp4')) {
              return NavigationDecision.navigate;
            }
            // Block all external redirects & betting popups
            return NavigationDecision.prevent;
          },
        ),
      );
  }

  void _loadStream(int index) {
    _autoFallbackTimer?.cancel();
    setState(() {
      _currentSourceIndex = index;
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    final targetUrl = _sources[index]['url']!;
    _controller.loadRequest(Uri.parse(targetUrl));

    // 14-second safety guard: If video doesn't play or server stalls, give user an instant option
    _autoFallbackTimer = Timer(const Duration(seconds: 14), () {
      if (_isLoading && mounted) {
        _handleStreamFailure('Stream response took too long');
      }
    });
  }

  void _handleStreamFailure(String reason) {
    _autoFallbackTimer?.cancel();
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _hasError = true;
      _errorMessage = reason;
    });
  }

  void _switchToNextServer() {
    final nextIndex = (_currentSourceIndex + 1) % _sources.length;
    _loadStream(nextIndex);
  }

  void _injectAdShieldAndAutoPlay() {
    const shieldJs = '''
      (function() {
        // Block popups and redirects
        window.open = function() { return null; };
        window.alert = function() {};
        window.confirm = function() { return true; };

        // Clean, non-blocking auto-play trigger
        var attempts = 0;
        var interval = setInterval(function() {
          attempts++;
          var playBtn = document.querySelector('.play-btn, .vjs-big-play-button, button[aria-label="Play"], #play, .jw-display-icon-display, svg[data-icon="play"]');
          if (playBtn) playBtn.click();

          var v = document.querySelector('video');
          if (v) {
            v.muted = false;
            v.volume = 1.0;
            if (v.paused) v.play().catch(function(){});
          }

          if (attempts > 8) clearInterval(interval);
        }, 650);
      })();
    ''';
    _controller.runJavaScript(shieldJs).catchError((_) {});
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showTopBar = false);
    });
  }

  void _showServerSheet() {
    _hideTimer?.cancel();
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                          'Audio Dubbing & Servers',
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

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.redAccent.withOpacity(0.18) : Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? Colors.redAccent : Colors.white10,
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
                            color: isSelected ? Colors.redAccent : Colors.white70,
                            size: 22,
                          ),
                          title: Text(
                            item['title']!,
                            style: TextStyle(
                              color: isSelected ? Colors.redAccent : Colors.white,
                              fontSize: 13.5,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            item['subtitle']!,
                            style: TextStyle(
                              color: isSelected ? Colors.redAccent.withOpacity(0.8) : Colors.white38,
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
                              item['badge']!,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.white70,
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(ctx);
                            _loadStream(idx);
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
    _hideTimer?.cancel();
    _autoFallbackTimer?.cancel();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WakelockPlus.disable();
    super.dispose();
  }

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
            // Full Video Canvas - Clean & smooth native HTML5 player
            WebViewWidget(controller: _controller),

            // Top screen touch detection to toggle UI bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 80,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  setState(() => _showTopBar = !_showTopBar);
                  if (_showTopBar) _startHideTimer();
                },
              ),
            ),

            // Modern Loading Screen
            if (_isLoading)
              Container(
                color: Colors.black,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Colors.redAccent, strokeWidth: 2.8),
                      const SizedBox(height: 16),
                      Text(
                        'Connecting to ${activeSource['badge']} Stream...',
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        activeSource['title']!,
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),

            // Auto-Fallback / Server Error Card
            if (_hasError)
              Container(
                color: Colors.black.withOpacity(0.92),
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
                        const Icon(Icons.cloud_off_rounded, color: Colors.redAccent, size: 48),
                        const SizedBox(height: 12),
                        const Text(
                          'Server Unreachable',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${activeSource['title']} is currently not responding in your region.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _loadStream(_currentSourceIndex),
                              icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 18),
                              label: const Text('Retry Server', style: TextStyle(color: Colors.white)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white24),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: _switchToNextServer,
                              icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 18),
                              label: const Text('Try Next Mirror', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

            // Sleek Netflix-Style Top Header Bar
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
                      // Refresh button
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 20),
                        tooltip: 'Reload Stream',
                        onPressed: () => _loadStream(_currentSourceIndex),
                      ),
                      const SizedBox(width: 4),
                      // Audio Dubbing & Server Switcher Pill
                      InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: _showServerSheet,
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
                                activeSource['badge']!,
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
