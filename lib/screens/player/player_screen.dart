import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class WatchWebviewScreen extends StatefulWidget {
  final dynamic movie;
  final dynamic show;
  final dynamic episode;
  final int? tmdbId;
  final int? id;
  final String? title;
  final String? name;
  final bool isTv;
  final int? seasonNumber;
  final int? episodeNumber;

  const WatchWebviewScreen({
    super.key,
    this.movie,
    this.show,
    this.episode,
    this.tmdbId,
    this.id,
    this.title,
    this.name,
    this.isTv = false,
    this.seasonNumber,
    this.episodeNumber,
  });

  @override
  State<WatchWebviewScreen> createState() => _WatchWebviewScreenState();
}

class _WatchWebviewScreenState extends State<WatchWebviewScreen> {
  InAppWebViewController? _webViewController;
  bool _isLoading = true;
  bool _hasError = false;
  
  // Custom Player States
  bool _isPlaying = false;
  bool _showControls = true;
  bool _isFullScreen = false;
  double _currentPosition = 0;
  double _totalDuration = 1; // Prevent division by zero
  
  Timer? _controlsTimer;
  Timer? _syncTimer;
  int _currentServerIndex = 0;

  // Servers List (Fail-Proof)
  List<Map<String, String>> get _servers {
    final id = _resolvedId;
    final s = widget.seasonNumber ?? 1;
    final e = widget.episodeNumber ?? 1;
    final isTv = widget.isTv || widget.show != null;

    if (isTv) {
      return [
        {'name': 'VidSrc (Fast)', 'url': 'https://vidsrc.cc/v2/embed/tv/$id/$s/$e'},
        {'name': 'MultiEmbed', 'url': 'https://multiembed.mov/?video_id=$id&tmdb=1&s=$s&e=$e'},
        {'name': 'AutoEmbed', 'url': 'https://autoembed.co/tv/tmdb/$id-$s-$e'},
      ];
    } else {
      return [
        {'name': 'VidSrc (Fast)', 'url': 'https://vidsrc.cc/v2/embed/movie/$id'},
        {'name': 'MultiEmbed', 'url': 'https://multiembed.mov/?video_id=$id&tmdb=1'},
        {'name': 'AutoEmbed', 'url': 'https://autoembed.co/movie/tmdb/$id'},
      ];
    }
  }

  // Smart ID Resolver
  int get _resolvedId {
    if (widget.tmdbId != null && widget.tmdbId! > 0) return widget.tmdbId!;
    if (widget.id != null && widget.id! > 0) return widget.id!;
    for (var obj in [widget.movie, widget.show]) {
      if (obj != null) {
        if (obj is Map && obj['id'] != null) return int.tryParse(obj['id'].toString()) ?? 0;
        try {
          return int.tryParse(obj.id.toString()) ?? 0;
        } catch (_) {}
      }
    }
    return 0;
  }

  String get _resolvedTitle {
    return widget.title ?? widget.name ?? 'Now Playing';
  }

  // THE MAGIC: JS Script to hide controls across all iframes
  final String _injectionJS = """
    function hideAllControls() {
      // Hide CSS elements
      let style = document.createElement('style');
      style.innerHTML = `
        *::-webkit-media-controls-panel { display: none !important; opacity: 0 !important; }
        *::-webkit-media-controls-play-button { display: none !important; }
        *::-webkit-media-controls { display: none !important; }
        .plyr__controls { display: none !important; }
        .jw-controls { display: none !important; }
        .vjs-control-bar { display: none !important; }
      `;
      document.head.appendChild(style);
      
      // Force disable video controls property
      let videos = document.getElementsByTagName('video');
      for(let i=0; i<videos.length; i++){
        videos[i].controls = false;
        videos[i].removeAttribute('controls');
        // Prevent click to pause from their player
        videos[i].style.pointerEvents = 'none'; 
      }
    }
    // Run multiple times in case video loads dynamically
    hideAllControls();
    setTimeout(hideAllControls, 1000);
    setTimeout(hideAllControls, 3000);
  """;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _startControlsTimer();
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    _syncTimer?.cancel();
    WakelockPlus.disable();
    _exitFullScreen();
    super.dispose();
  }

  // --- Core Sync Engine (Flutter to WebView) ---
  
  void _startSyncEngine() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(milliseconds: 1000), (timer) async {
      if (_webViewController != null) {
        // Fetch current time
        final timeRes = await _webViewController!.evaluateJavascript(
            source: "try { document.querySelector('video').currentTime; } catch(e) { 0; }");
        // Fetch duration
        final durRes = await _webViewController!.evaluateJavascript(
            source: "try { document.querySelector('video').duration; } catch(e) { 0; }");
        // Check if playing
        final pausedRes = await _webViewController!.evaluateJavascript(
            source: "try { document.querySelector('video').paused; } catch(e) { true; }");

        if (mounted) {
          setState(() {
            if (timeRes != null && timeRes is num) _currentPosition = timeRes.toDouble();
            if (durRes != null && durRes is num && durRes > 0) _totalDuration = durRes.toDouble();
            if (pausedRes != null && pausedRes is bool) _isPlaying = !pausedRes;
          });
        }
      }
    });
  }

  void _togglePlayPause() {
    if (_webViewController != null) {
      if (_isPlaying) {
        _webViewController!.evaluateJavascript(source: "try { document.querySelector('video').pause(); } catch(e) {}");
      } else {
        _webViewController!.evaluateJavascript(source: "try { document.querySelector('video').play(); } catch(e) {}");
      }
      setState(() => _isPlaying = !_isPlaying);
      _startControlsTimer();
    }
  }

  void _seekTo(double seconds) {
    if (_webViewController != null) {
      _webViewController!.evaluateJavascript(
          source: "try { document.querySelector('video').currentTime = $seconds; } catch(e) {}");
      setState(() => _currentPosition = seconds);
      _startControlsTimer();
    }
  }

  void _seekRelative(double seconds) {
    _seekTo((_currentPosition + seconds).clamp(0.0, _totalDuration));
  }

  // --- UI Controls ---

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _startControlsTimer();
  }

  void _enterFullScreen() {
    setState(() => _isFullScreen = true);
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _exitFullScreen() {
    setState(() => _isFullScreen = false);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  String _formatTime(double seconds) {
    final d = Duration(seconds: seconds.toInt());
    final min = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final sec = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$min:$sec' : '$min:$sec';
  }

  void _switchServer(int index) {
    setState(() {
      _currentServerIndex = index;
      _isLoading = true;
      _hasError = false;
    });
    _webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri(_servers[index]['url']!)));
    Navigator.pop(context); // close bottom sheet
  }

  void _showServerPicker() {
    _controlsTimer?.cancel();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select Stream Server', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ...List.generate(_servers.length, (i) {
                final isCurrent = i == _currentServerIndex;
                return ListTile(
                  leading: Icon(Icons.dns_rounded, color: isCurrent ? Colors.redAccent : Colors.white54),
                  title: Text(_servers[i]['name']!, style: TextStyle(color: isCurrent ? Colors.redAccent : Colors.white)),
                  trailing: isCurrent ? const Icon(Icons.check_circle, color: Colors.redAccent) : null,
                  onTap: () => _switchServer(i),
                );
              }),
            ],
          ),
        );
      },
    ).then((_) => _startControlsTimer());
  }

  // --- Build UI ---

  Widget _buildWebView() {
    return Stack(
      children: [
        // 1. Core Web Engine
        InAppWebView(
          initialUrlRequest: URLRequest(url: WebUri(_servers[_currentServerIndex]['url']!)),
          initialSettings: InAppWebViewSettings(
            mediaPlaybackRequiresUserGesture: false,
            allowsInlineMediaPlayback: true,
            iframeAllowFullscreen: true,
            transparentBackground: true,
            supportZoom: false,
            disableContextMenu: true,
          ),
          // UserScript ensures injection happens on main frame AND all iframes (VidSrc uses iframes)
          initialUserScripts: UnmodifiableListView<UserScript>([
            UserScript(
              source: _injectionJS,
              injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
              forMainFrameOnly: false, // CRITICAL: Inject into iframes
            )
          ]),
          onWebViewCreated: (controller) {
            _webViewController = controller;
          },
          onLoadStop: (controller, url) {
            if (mounted) setState(() => _isLoading = false);
            // Run script manually one more time just in case
            controller.evaluateJavascript(source: _injectionJS);
            _startSyncEngine();
          },
          onReceivedError: (controller, req, error) {
            if (mounted) setState(() => _hasError = true);
          },
        ),

        // 2. Loading State
        if (_isLoading)
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.redAccent),
                SizedBox(height: 12),
                Text("Bypassing Server Security...", style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),

        // 3. Transparent Gesture Detector (Intercepts touches to prevent web interactions)
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleControls,
          // We don't absorb double taps so they don't leak into webview
          onDoubleTap: () => _toggleControls(),
        ),

        // 4. Flutter Native Custom Overlay
        if (_showControls && !_isLoading)
          AnimatedOpacity(
            opacity: _showControls ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 250),
            child: Container(
              color: Colors.black.withOpacity(0.5),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: () => _isFullScreen ? _exitFullScreen() : Navigator.pop(context),
                          child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "$_resolvedTitle${widget.isTv ? '(S${widget.seasonNumber} E${widget.episodeNumber})' : ''}",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.settings_applications, color: Colors.white),
                          onTap: _showServerPicker,
                        ),
                      ],
                    ),
                  ),

                  // Center Play/Pause Controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        iconSize: 40,
                        icon: const Icon(Icons.replay_10_rounded, color: Colors.white),
                        onPressed: () => _seekRelative(-10),
                      ),
                      const SizedBox(width: 24),
                      IconButton(
                        iconSize: 64,
                        icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, color: Colors.redAccent),
                        onPressed: _togglePlayPause,
                      ),
                      const SizedBox(width: 24),
                      IconButton(
                        iconSize: 40,
                        icon: const Icon(Icons.forward_10_rounded, color: Colors.white),
                        onPressed: () => _seekRelative(10),
                      ),
                    ],
                  ),

                  // Bottom Slider & Time
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      children: [
                        Text(_formatTime(_currentPosition), style: const TextStyle(color: Colors.white, fontSize: 12)),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: Colors.redAccent,
                              thumbColor: Colors.redAccent,
                              trackHeight: 3,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                            ),
                            child: Slider(
                              min: 0,
                              max: _totalDuration,
                              value: _currentPosition.clamp(0, _totalDuration),
                              onChangeStart: (_) => _syncTimer?.cancel(),
                              onChanged: (val) => setState(() => _currentPosition = val),
                              onChangeEnd: (val) {
                                _seekTo(val);
                                _startSyncEngine();
                              },
                            ),
                          ),
                        ),
                        Text(_formatTime(_totalDuration), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(width: 12),
                        InkWell(
                          onTap: _isFullScreen ? _exitFullScreen : _enterFullScreen,
                          child: Icon(_isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen, color: Colors.white),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isFullScreen) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(child: _buildWebView()),
      );
    }

    // Portrait Mode UI (YouTube Style)
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SafeArea(
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: _buildWebView(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_resolvedTitle, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                      widget.isTv ? 'Season ${widget.seasonNumber} • Episode ${widget.episodeNumber}' : 'Full Movie',
                      style: const TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    const Text("Active Server", style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _showServerPicker,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          border: Border.all(color: Colors.white12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.dns_rounded, color: Colors.redAccent),
                            const SizedBox(width: 12),
                            Expanded(child: Text(_servers[_currentServerIndex]['name']!, style: const TextStyle(color: Colors.white))),
                            const Icon(Icons.swap_horiz, color: Colors.white54),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
