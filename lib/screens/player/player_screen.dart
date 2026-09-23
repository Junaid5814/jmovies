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
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player _player;
  late final VideoController _videoController;

  StreamSubscription<String>? _errorSubscription;
  StreamSubscription<Tracks>? _tracksSubscription;
  StreamSubscription<bool>? _bufferingSubscription;

  bool _linkFound = false;
  Tracks _tracks = const Tracks();
  bool _isLoading = true;
  bool _isBuffering = false;
  String? _errorMessage;

  int get _resolvedId {
    if (widget.tmdbId != null && widget.tmdbId! > 0) return widget.tmdbId!;
    try {
      final dynamic id = widget.movie?.id;
      if (id != null) return int.tryParse(id.toString()) ?? 0;
    } catch (_) {}
    try {
      final dynamic id = widget.show?.id;
      if (id != null) return int.tryParse(id.toString()) ?? 0;
    } catch (_) {}
    try {
      final dynamic id = widget.mediaItem?.id;
      if (id != null) return int.tryParse(id.toString()) ?? 0;
    } catch (_) {}
    return 0;
  }

  String get _resolvedTitle {
    final suppliedTitle = widget.title?.trim();
    if (suppliedTitle != null && suppliedTitle.isNotEmpty) return suppliedTitle;
    try {
      final dynamic value = widget.movie?.title;
      if (value != null && value.toString().trim().isNotEmpty) return value.toString().trim();
    } catch (_) {}
    try {
      final dynamic value = widget.show?.name;
      if (value != null && value.toString().trim().isNotEmpty) return value.toString().trim();
    } catch (_) {}
    try {
      final dynamic value = widget.mediaItem?.title;
      if (value != null && value.toString().trim().isNotEmpty) return value.toString().trim();
    } catch (_) {}
    return 'JMovies Player';
  }

  bool get _resolvedIsTv {
    return widget.isTv || widget.show != null || widget.episode != null || widget.seasonNumber != null;
  }

  int get _resolvedSeason {
    if (widget.seasonNumber != null && widget.seasonNumber! > 0) return widget.seasonNumber!;
    try {
      final dynamic value = widget.episode?.seasonNumber;
      return int.tryParse(value?.toString() ?? '') ?? 1;
    } catch (_) {
      return 1;
    }
  }

  int get _resolvedEpisode {
    if (widget.episodeNumber != null && widget.episodeNumber! > 0) return widget.episodeNumber!;
    try {
      final dynamic value = widget.episode?.episodeNumber;
      return int.tryParse(value?.toString() ?? '') ?? 1;
    } catch (_) {
      return 1;
    }
  }

  @override
  void initState() {
    super.initState();
    _enterFullscreen();

    _player = Player();
    _videoController = VideoController(_player);

    _tracksSubscription = _player.stream.tracks.listen((tracks) {
      if (!mounted) return;
      setState(() => _tracks = tracks);
    });

    _bufferingSubscription = _player.stream.buffering.listen((buffering) {
      if (!mounted) return;
      setState(() => _isBuffering = buffering);
    });

    _errorSubscription = _player.stream.error.listen((message) {
      if (!mounted || message.trim().isEmpty) return;
      setState(() {
        _errorMessage = 'Native playback failed. Link might be protected.';
        _isLoading = false;
      });
    });

    Future.delayed(const Duration(seconds: 25), () {
      if (!_linkFound && mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Stream extraction failed. Please try again.';
        });
      }
    });
  }

  Future<void> _enterFullscreen() async {
    await WakelockPlus.enable();
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _playExtractedLink(String url, Map<String, String> extractedHeaders) async {
    if (!mounted) return;
    
    final Map<String, String> headers = {
      "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
      "Referer": "https://vidlink.pro/",
      "Origin": "https://vidlink.pro"
    };
    
    extractedHeaders.forEach((key, value) {
      headers[key] = value;
    });

    try {
      await _player.open(Media(url, httpHeaders: headers), play: true);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _tracks = _player.state.tracks;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load stream into Native Player.';
        });
      }
    }
  }

  Future<void> _openSettings() async {
    if (_isLoading || _errorMessage != null) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF121212),
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _PlaybackSettingsSheet(player: _player, tracks: _tracks),
    );
    if (mounted) setState(() => _tracks = _player.state.tracks);
  }

  @override
  void dispose() {
    _errorSubscription?.cancel();
    _tracksSubscription?.cancel();
    _bufferingSubscription?.cancel();
    _player.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    
    // Yahan URL theek kiya gaya hai
    final targetUrl = _resolvedIsTv
        ? 'https://vidlink.pro/tv/$_resolvedId/$_resolvedSeason/$_resolvedEpisode?autoplay=true'
        : 'https://vidlink.pro/movie/$_resolvedId?autoplay=true';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: isLandscape
          ? null
          : AppBar(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              title: Text(_resolvedTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
              actions: [
                IconButton(
                  tooltip: 'Playback settings',
                  onPressed: _openSettings,
                  icon: const Icon(Icons.tune_rounded),
                ),
              ],
            ),
      body: SafeArea(
        top: !isLandscape,
        bottom: !isLandscape,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. HIDDEN WEBVIEW
            if (!_linkFound && _errorMessage == null)
              IgnorePointer(
                child: Opacity(
                  opacity: 0.0, 
                  child: InAppWebView(
                    initialUrlRequest: URLRequest(url: WebUri(targetUrl)),
                    initialSettings: InAppWebViewSettings(
                      javaScriptEnabled: true,
                      mediaPlaybackRequiresUserGesture: false,
                      useShouldInterceptRequest: true,
                      userAgent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
                    ),
                    onLoadStop: (controller, url) async {
                       await controller.evaluateJavascript(source: """
                          setInterval(() => {
                             let btn = document.querySelector('.play-btn, .vjs-big-play-button, #play-button');
                             if(btn) btn.click();
                          }, 1000);
                       """);
                    },
                    shouldInterceptRequest: (controller, request) async {
                      final reqUrl = request.url.toString();
                      if ((reqUrl.contains('.m3u8') || reqUrl.contains('.mp4')) && !_linkFound) {
                        if (!reqUrl.contains('blank') && !reqUrl.contains('dummy')) {
                          _linkFound = true;
                          Map<String, String> headers = {};
                          request.headers?.forEach((key, value) => headers[key] = value.toString());
                          
                          Future.microtask(() => _playExtractedLink(reqUrl, headers));
                        }
                      }
                      return null;
                    },
                  ),
                ),
              ),

            // 2. NATIVE PLAYER
            if (_linkFound && _errorMessage == null)
              Video(
                controller: _videoController,
                fit: BoxFit.contain,
                controls: AdaptiveVideoControls,
              ),

            // 3. LOADING UI
            if (_isLoading)
              const ColoredBox(
                color: Colors.black,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Color(0xFFE50914)),
                      SizedBox(height: 16),
                      Text(
                        'Extracting Multi-Language Streams...',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),

            // 4. BUFFERING OVERLAY
            if (!_isLoading && _isBuffering && _errorMessage == null)
               ColoredBox(
                color: Colors.black.withOpacity(0.5),
                child: const Center(
                  child: CircularProgressIndicator(color: Color(0xFFE50914)),
                ),
              ),

            // 5. ERROR UI
            if (_errorMessage != null)
              _PlayerErrorView(
                message: _errorMessage!,
                onRetry: () {
                  setState(() {
                    _errorMessage = null;
                    _isLoading = true;
                    _linkFound = false;
                  });
                },
              ),

            // 6. NATIVE CONTROLS OVERLAY FOR LANDSCAPE
            if (isLandscape && !_isLoading && _errorMessage == null)
              Positioned(
                top: 12,
                right: 12,
                child: SafeArea(
                  child: IconButton.filledTonal(
                    tooltip: 'Audio, subtitles and quality',
                    onPressed: _openSettings,
                    icon: const Icon(Icons.tune_rounded),
                  ),
                ),
              ),
            if (isLandscape)
              Positioned(
                top: 12,
                left: 12,
                child: SafeArea(
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PlayerErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _PlayerErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.play_disabled_rounded, color: Colors.white54, size: 56),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 15)),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE50914),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaybackSettingsSheet extends StatefulWidget {
  final Player player;
  final Tracks tracks;
  const _PlaybackSettingsSheet({required this.player, required this.tracks});

  @override
  State<_PlaybackSettingsSheet> createState() => _PlaybackSettingsSheetState();
}

class _PlaybackSettingsSheetState extends State<_PlaybackSettingsSheet> {
  late Tracks _tracks;

  @override
  void initState() {
    super.initState();
    _tracks = widget.tracks;
  }

  List<AudioTrack> get _audioTracks => _uniqueById<AudioTrack>(_tracks.audio.where((track) => track.id != 'no').toList());
  List<SubtitleTrack> get _subtitleTracks => _uniqueById<SubtitleTrack>(_tracks.subtitle);
  List<VideoTrack> get _videoTracks => _uniqueById<VideoTrack>(_tracks.video.where((track) => track.id != 'no').toList());

  List<T> _uniqueById<T>(List<T> tracks) {
    final ids = <String>{};
    final result = <T>[];
    for (final track in tracks) {
      final dynamic value = track;
      if (ids.add(value.id.toString())) result.add(track);
    }
    return result;
  }

  String _audioLabel(AudioTrack track) {
    if (track.id == 'auto') return 'Automatic';
    if (track.title?.trim().isNotEmpty ?? false) return track.title!.trim();
    if (track.language?.trim().isNotEmpty ?? false) return track.language!.trim().toUpperCase();
    return 'Audio ${track.id}';
  }

  String _subtitleLabel(SubtitleTrack track) {
    if (track.id == 'no') return 'Off';
    if (track.id == 'auto') return 'Automatic';
    if (track.title?.trim().isNotEmpty ?? false) return track.title!.trim();
    if (track.language?.trim().isNotEmpty ?? false) return track.language!.trim().toUpperCase();
    return 'Subtitle ${track.id}';
  }

  String _videoLabel(VideoTrack track) {
    if (track.id == 'auto') return 'Auto';
    if (track.h != null && track.h! > 0) return '${track.h}p';
    if (track.title?.trim().isNotEmpty ?? false) return track.title!.trim();
    return 'Quality ${track.id}';
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.player.state.track;
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.82,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: [
            const Text('Playback Settings', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 24),
            
            const _SettingsHeading(icon: Icons.language_rounded, title: 'Audio & Language'),
            if (_audioTracks.isEmpty) const _EmptyTrackMessage(message: 'No alternate audio track found.')
            else ..._audioTracks.map((track) => RadioListTile<String>(
              value: track.id, 
              groupValue: selected.audio.id, 
              activeColor: const Color(0xFFE50914),
              title: Text(_audioLabel(track), style: const TextStyle(color: Colors.white)),
              onChanged: (val) async { 
                await widget.player.setAudioTrack(track); 
                if (mounted) setState(() {}); 
              },
            )),
            
            const Divider(color: Colors.white12, height: 32),
            
            const _SettingsHeading(icon: Icons.subtitles_rounded, title: 'Subtitles'),
            if (_subtitleTracks.isEmpty) const _EmptyTrackMessage(message: 'No subtitle track found.')
            else ..._subtitleTracks.map((track) => RadioListTile<String>(
              value: track.id, 
              groupValue: selected.subtitle.id, 
              activeColor: const Color(0xFFE50914),
              title: Text(_subtitleLabel(track), style: const TextStyle(color: Colors.white)),
              onChanged: (val) async { 
                await widget.player.setSubtitleTrack(track); 
                if (mounted) setState(() {}); 
              },
            )),
            
            const Divider(color: Colors.white12, height: 32),
            
            const _SettingsHeading(icon: Icons.high_quality_rounded, title: 'Video Quality'),
            if (_videoTracks.isEmpty) const _EmptyTrackMessage(message: 'Adaptive quality is controlled automatically.')
            else ..._videoTracks.map((track) => RadioListTile<String>(
              value: track.id, 
              groupValue: selected.video.id, 
              activeColor: const Color(0xFFE50914),
              title: Text(_videoLabel(track), style: const TextStyle(color: Colors.white)),
              onChanged: (val) async { 
                await widget.player.setVideoTrack(track); 
                if (mounted) setState(() {}); 
              },
            )),
          ],
        ),
      ),
    );
  }
}

class _SettingsHeading extends StatelessWidget {
  final IconData icon; 
  final String title;
  const _SettingsHeading({required this.icon, required this.title});
  @override
  Widget build(BuildContext context) {
    return Row(children: [Icon(icon, color: const Color(0xFFE50914)), const SizedBox(width: 10), Text(title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700))]);
  }
}

class _EmptyTrackMessage extends StatelessWidget {
  final String message;
  const _EmptyTrackMessage({required this.message});
  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16), child: Text(message, style: const TextStyle(color: Colors.white54, fontSize: 13)));
  }
}
