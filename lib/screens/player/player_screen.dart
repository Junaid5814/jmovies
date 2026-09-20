import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../data/services/m3u8_extractor_service.dart';

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
  VideoPlayerController? _controller;
  List<M3u8Stream> _availableStreams = [];
  int _currentStreamIndex = 0;
  bool _isLoading = true;
  bool _showControls = true;
  bool _isFullScreen = false;
  String _errorMessage = '';
  Timer? _hideTimer;

  int get _resolvedId {
    if (widget.tmdbId != null && widget.tmdbId! > 0) return widget.tmdbId!;
    if (widget.id != null && widget.id! > 0) return widget.id!;
    for (var obj in [widget.movie, widget.show, widget.mediaItem, widget.media, widget.item]) {
      if (obj != null) {
        try {
          final v = obj.id;
          if (v != null && v is int && v > 0) return v;
        } catch (_) {}
      }
    }
    return 0;
  }

  String get _resolvedTitle {
    if (widget.title != null && widget.title!.isNotEmpty) return widget.title!;
    if (widget.name != null && widget.name!.isNotEmpty) return widget.name!;
    for (var obj in [widget.movie, widget.show, widget.mediaItem, widget.media, widget.item]) {
      if (obj != null) {
        try {
          final t = obj.title ?? obj.name;
          if (t != null && t.toString().isNotEmpty) return t.toString();
        } catch (_) {}
      }
    }
    return 'Streaming Movie';
  }

  int get _resolvedSeason => widget.seasonNumber ?? widget.season ?? 1;
  int get _resolvedEpisode => widget.episodeNumber ?? 1;

  bool get _resolvedIsTv {
    if (widget.isTv) return true;
    if (widget.show != null || widget.episode != null) return true;
    if (widget.seasonNumber != null && widget.seasonNumber! > 0) return true;
    for (var obj in [widget.mediaItem, widget.movie, widget.media, widget.item]) {
      if (obj != null) {
        try {
          if (obj.mediaType == 'tv') return true;
        } catch (_) {}
      }
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _fetchAndPlayM3u8();
  }

  Future<void> _fetchAndPlayM3u8() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final streams = await M3u8ExtractorService.extractStreams(
        tmdbId: _resolvedId,
        isTv: _resolvedIsTv,
        season: _resolvedSeason,
        episode: _resolvedEpisode,
      );

      if (streams.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No valid HLS stream found for this title.';
        });
        return;
      }

      setState(() {
        _availableStreams = streams;
      });

      await _initializeStream(_currentStreamIndex);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to extract stream: $e';
      });
    }
  }

  Future<void> _initializeStream(int index) async {
    if (_availableStreams.isEmpty) return;

    final targetStream = _availableStreams[index];
    await _controller?.dispose();

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _currentStreamIndex = index;
    });

    try {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(targetStream.streamUrl),
        httpHeaders: targetStream.headers,
      );

      await _controller!.initialize();
      _controller!.play();
      _controller!.addListener(_playerListener);

      setState(() => _isLoading = false);
      _startHideTimer();
    } catch (e) {
      debugPrint('Native Player Error: $e');
      if (index + 1 < _availableStreams.length) {
        _initializeStream(index + 1);
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Stream playback failed. Server rejected request.';
        });
      }
    }
  }

  void _playerListener() {
    if (mounted) setState(() {});
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && (_controller?.value.isPlaying ?? false)) {
        setState(() => _showControls = false);
      }
    });
  }

  void _togglePlayPause() {
    if (_controller == null) return;
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _showControls = true;
        _hideTimer?.cancel();
      } else {
        _controller!.play();
        _startHideTimer();
      }
    });
  }

  void _seekRelative(int seconds) {
    if (_controller == null) return;
    final current = _controller!.value.position;
    final target = current + Duration(seconds: seconds);
    _controller!.seekTo(target);
    _startHideTimer();
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
      if (_isFullScreen) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    });
  }

  void _openStreamSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Native HLS Server',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...List.generate(_availableStreams.length, (idx) {
                final s = _availableStreams[idx];
                final isSel = idx == _currentStreamIndex;
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: isSel ? Colors.redAccent.withOpacity(0.18) : Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isSel ? Colors.redAccent : Colors.transparent),
                  ),
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.stream_rounded, color: isSel ? Colors.redAccent : Colors.white70),
                    title: Text(s.serverName, style: TextStyle(color: isSel ? Colors.redAccent : Colors.white, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                    subtitle: Text('${s.audioLanguage} • ${s.quality}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                    trailing: isSel ? const Icon(Icons.check_circle, color: Colors.redAccent, size: 18) : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      _initializeStream(idx);
                    },
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$m:$s';
    }
    return '$m:$s';
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller?.removeListener(_playerListener);
    _controller?.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WakelockPlus.disable();
    super.dispose();
  }

  Widget _buildVideoPlayerSurface() {
    return AspectRatio(
      aspectRatio: _isFullScreen ? (MediaQuery.of(context).size.width / MediaQuery.of(context).size.height) : (16 / 9),
      child: Container(
        color: Colors.black,
        child: GestureDetector(
          onTap: () {
            setState(() => _showControls = !_showControls);
            if (_showControls) _startHideTimer();
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_controller != null && _controller!.value.isInitialized)
                Center(
                  child: AspectRatio(
                    aspectRatio: _controller!.value.aspectRatio,
                    child: VideoPlayer(_controller!),
                  ),
                ),

              if (_isLoading)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      CircularProgressIndicator(color: Colors.redAccent, strokeWidth: 3),
                      SizedBox(height: 12),
                      Text('Buffering HLS Stream...', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),

              if (_errorMessage.isNotEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_errorMessage, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                  ),
                ),

              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _showControls ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !_showControls,
                  child: Container(
                    color: Colors.black45,
                    child: Stack(
                      children: [
                        Positioned(
                          top: 10,
                          left: 10,
                          right: 10,
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                                onPressed: () {
                                  if (_isFullScreen) {
                                    _toggleFullScreen();
                                  } else {
                                    Navigator.pop(context);
                                  }
                                },
                              ),
                              Expanded(
                                child: Text(
                                  _resolvedTitle,
                                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.settings_rounded, color: Colors.white, size: 20),
                                onPressed: _openStreamSheet,
                              ),
                            ],
                          ),
                        ),

                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                iconSize: 38,
                                icon: const Icon(Icons.replay_10_rounded, color: Colors.white),
                                onPressed: () => _seekRelative(-10),
                              ),
                              const SizedBox(width: 24),
                              IconButton(
                                iconSize: 54,
                                icon: Icon(
                                  (_controller?.value.isPlaying ?? false) ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
                                  color: Colors.redAccent,
                                ),
                                onPressed: _togglePlayPause,
                              ),
                              const SizedBox(width: 24),
                              IconButton(
                                iconSize: 38,
                                icon: const Icon(Icons.forward_10_rounded, color: Colors.white),
                                onPressed: () => _seekRelative(10),
                              ),
                            ],
                          ),
                        ),

                        Positioned(
                          bottom: 6,
                          left: 14,
                          right: 14,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                  trackHeight: 3,
                                  activeTrackColor: Colors.redAccent,
                                  inactiveTrackColor: Colors.white24,
                                  thumbColor: Colors.redAccent,
                                ),
                                child: Slider(
                                  value: _controller?.value.position.inMilliseconds.toDouble() ?? 0.0,
                                  max: (_controller?.value.duration.inMilliseconds.toDouble() ?? 1.0).clamp(1.0, double.infinity),
                                  onChanged: (val) {
                                    _controller?.seekTo(Duration(milliseconds: val.toInt()));
                                    _startHideTimer();
                                  },
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDuration(_controller?.value.position ?? Duration.zero),
                                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                                  ),
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    icon: Icon(_isFullScreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded, color: Colors.white, size: 22),
                                    onPressed: _toggleFullScreen,
                                  ),
                                  Text(
                                    _formatDuration(_controller?.value.duration ?? Duration.zero),
                                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                                  ),
                                ],
                              ),
                            ],
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isFullScreen) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(child: _buildVideoPlayerSurface()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SafeArea(
        child: Column(
          children: [
            _buildVideoPlayerSurface(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _resolvedTitle,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                          child: const Text('HLS Direct', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _resolvedIsTv ? 'TV Series • Ep $_resolvedEpisode' : 'Movie',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: _openStreamSheet,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white24, width: 0.8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.tune_rounded, color: Colors.redAccent, size: 14),
                                const SizedBox(width: 5),
                                Text(
                                  _availableStreams.isNotEmpty ? _availableStreams[_currentStreamIndex].audioLanguage : 'Servers',
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
