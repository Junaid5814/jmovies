import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class WatchWebviewScreen extends StatefulWidget {
  final int tmdbId;
  final String title;
  final bool isTv;
  final int? seasonNumber;
  final int? episodeNumber;

  const WatchWebviewScreen({
    super.key,
    required this.tmdbId,
    required this.title,
    required this.isTv,
    this.seasonNumber,
    this.episodeNumber,
  });

  @override
  State<WatchWebviewScreen> createState() => _WatchWebviewScreenState();
}

class _WatchWebviewScreenState extends State<WatchWebviewScreen> {
  InAppWebViewController? _controller;
  bool _isLoading = true;
  double _progress = 0;
  int _currentServer = 0;
  bool _showControls = true;
  Timer? _hideTimer;

  List<Map<String, String>> get _servers {
    final id = widget.tmdbId;
    final s = widget.seasonNumber ?? 1;
    final e = widget.episodeNumber ?? 1;

    if (widget.isTv) {
      return [
        {
          'name': 'Server 1 (MultiEmbed - Hindi/Urdu Dub)',
          'tag': 'Hindi Dub',
          'url': 'https://multiembed.mov/?video_id=$id&tmdb=1&s=$s&e=$e&autoplay=1',
        },
        {
          'name': 'Server 2 (VidSrc Pro HD)',
          'tag': 'English HD',
          'url': 'https://vidsrc.cc/v2/embed/tv/$id/$s/$e',
        },
        {
          'name': 'Server 3 (EmbedSU Asian/Anime)',
          'tag': 'Anime & K-Drama',
          'url': 'https://embed.su/embed/tv/$id/$s/$e',
        },
        {
          'name': 'Server 4 (VidLink Mirror)',
          'tag': 'Fast Mirror',
          'url': 'https://vidlink.pro/tv/$id/$s/$e?autoplay=true',
        },
      ];
    } else {
      return [
        {
          'name': 'Server 1 (MultiEmbed - Hindi/Urdu Dub)',
          'tag': 'Hindi Dub',
          'url': 'https://multiembed.mov/?video_id=$id&tmdb=1&autoplay=1',
        },
        {
          'name': 'Server 2 (VidSrc Pro HD)',
          'tag': 'English HD',
          'url': 'https://vidsrc.cc/v2/embed/movie/$id',
        },
        {
          'name': 'Server 3 (EmbedSU 4K)',
          'tag': 'Ultra HD',
          'url': 'https://embed.su/embed/movie/$id',
        },
        {
          'name': 'Server 4 (VidLink Mirror)',
          'tag': 'Fast Mirror',
          'url': 'https://vidlink.pro/movie/$id?autoplay=true',
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
    _startHideTimer();
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
                        idx == 0 ? Icons.translate_rounded : Icons.dns_rounded,
                        color: isSel ? Colors.redAccent : Colors.white70,
                        size: 20,
                      ),
                      title: Text(
                        srv['name']!,
                        style: TextStyle(
                          color: isSel ? Colors.redAccent : Colors.white,
                          fontSize: 13.5,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        srv['tag']!,
                        style: TextStyle(
                          color: isSel ? Colors.redAccent.withOpacity(0.8) : Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                      trailing: isSel
                          ? const Icon(Icons.check_circle, color: Colors.redAccent, size: 18)
                          : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _currentServer = idx;
                          _isLoading = true;
                        });
                        _controller?.loadUrl(
                          urlRequest: URLRequest(url: WebUri(srv['url']!)),
                        );
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
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = _servers[_currentServer];

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
                    'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36',
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
                // Auto-trigger video play without clicking
                controller.evaluateJavascript(source: """
                  (function() {
                    window.open = function() { return null; };
                    setInterval(function() {
                      const btn = document.querySelector('.play-btn, .vjs-big-play-button, button[aria-label="Play"], #play, .jw-display-icon-display, svg[data-icon="play"]');
                      if (btn) btn.click();
                      const v = document.querySelector('video');
                      if (v && v.paused) v.play().catch(function(){});
                    }, 500);
                  })();
                """);
              },
              onCreateWindow: (controller, createWindowAction) async {
                // Blocks external popups/ads completely
                return false;
              },
              shouldOverrideUrlLoading: (controller, navigationAction) async {
                final uri = navigationAction.request.url;
                if (uri == null) return NavigationActionPolicy.CANCEL;

                final url = uri.toString().toLowerCase();

                // Whitelist only safe video stream links & players
                if (url.startsWith('blob:') ||
                    url.startsWith('about:') ||
                    url.contains('multiembed') ||
                    url.contains('vidsrc') ||
                    url.contains('embed.su') ||
                    url.contains('vidlink') ||
                    url.contains('stream') ||
                    url.contains('cdn') ||
                    url.contains('m3u8') ||
                    url.contains('mp4')) {
                  return NavigationActionPolicy.ALLOW;
                }

                return NavigationActionPolicy.CANCEL;
              },
            ),

            // Tap detector to show / hide top control bar
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _toggleControls,
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
              opacity: _showControls ? 1.0 : 0.0,
              child: IgnorePointer(
                ignoring: !_showControls,
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
                          widget.title,
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
                        onTap: _showServerSheet,
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
