import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../data/services/stream_resolver.dart';

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
  VideoPlayerController? _controller;
  List<AppStream> _streams = [];
  int _currentStreamIndex = 0;
  
  bool _isLoadingStreams = true;
  bool _isPlayerLoading = false;
  bool _showControls = true;
  Timer? _hideControlsTimer;

  int get _resolvedId {
    if (widget.tmdbId != null && widget.tmdbId! > 0) return widget.tmdbId!;
    for (var obj in [widget.movie, widget.show, widget.mediaItem]) {
      if (obj != null) {
        try {
          final id = obj.id;
          if (id != null) return int.tryParse(id.toString()) ?? 0;
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
          final t = obj.title ?? obj.name;
          if (t != null && t.toString().isNotEmpty) return t.toString();
        } catch (_) {}
      }
    }
    return 'Streaming';
  }

  bool get _resolvedIsTv => widget.isTv || widget.show != null || widget.episode != null || (widget.seasonNumber != null && widget.seasonNumber! > 0);
  int get _resolvedSeason => widget.seasonNumber ?? (widget.episode?.seasonNumber ?? 1);
  int get _resolvedEpisode => widget.episodeNumber ?? (widget.episode?.episodeNumber ?? 1);

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _fetchStreamsAndPlay();
  }

  Future<void> _fetchStreamsAndPlay() async {
    setState(() => _isLoadingStreams = true);
    final streams = await StreamResolver.getStreams(
      tmdbId: _resolvedId,
      isTv: _resolvedIsTv,
      season: _resolvedSeason,
      episode: _resolvedEpisode,
    );

    if (mounted) {
      setState(() {
        _streams = streams;
        _isLoadingStreams = false;
      });
      if (_streams.isNotEmpty) {
        _initPlayerForStream(0);
      }
    }
  }

  Future<void> _initPlayerForStream(int index, {Duration? startAt}) async {
    setState(() {
      _currentStreamIndex = index;
      _isPlayerLoading = true;
    });

    final oldController = _controller;
    _controller = null; // Detach UI instantly
    await oldController?.dispose();

    final stream = _streams[index];
    final newController = VideoPlayerController.networkUrl(
      Uri.parse(stream.url),
      httpHeaders: stream.headers,
    );

    try {
      await newController.initialize();
      if (startAt != null) {
        await newController.seekTo(startAt);
      }
      newController.play();
      newController.addListener(() => setState(() {})); // Rebuild on progress
      
      if (mounted) {
        setState(() {
          _controller = newController;
          _isPlayerLoading = false;
        });
        _startHideControlsTimer();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _controller = newController;
          _isPlayerLoading = false;
        });
      }
    }
  }

  void _switchServer(int index) async {
    if (index == _currentStreamIndex || _streams.isEmpty) return;
    
    // Save current timestamp to resume from exact same second
    final currentPosition = _controller?.value.position;
    await _initPlayerForStream(index, startAt: currentPosition);
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _startHideControlsTimer();
  }

  void _toggleFullScreen(bool isLandscape) {
    if (isLandscape) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${duration.inHours > 0 ? '${duration.inHours}:' : ''}$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _controller?.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WakelockPlus.disable();
    super.dispose();
  }

  Widget _buildPlayer(bool isLandscape) {
    return AspectRatio(
      aspectRatio: isLandscape ? MediaQuery.of(context).size.aspectRatio : 16 / 9,
      child: Container(
        color: Colors.black,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Video Player
            if (_controller != null && _controller!.value.isInitialized)
              VideoPlayer(_controller!),

            // Loading / Error States
            if (_isLoadingStreams)
              const CircularProgressIndicator(color: Colors.redAccent)
            else if (_streams.isEmpty)
              const Text('No streams found. Please try another title.', style: TextStyle(color: Colors.white70))
            else if (_isPlayerLoading)
              const CircularProgressIndicator(color: Colors.redAccent)
            else if (_controller != null && _controller!.value.hasError)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.white54, size: 40),
                  const SizedBox(height: 8),
                  const Text('Stream failed. Try Server 2.', style: TextStyle(color: Colors.white70)),
                  TextButton(
                    onPressed: () => _switchServer((_currentStreamIndex + 1) % _streams.length),
                    child: const Text('Switch Server', style: TextStyle(color: Colors.redAccent)),
                  )
                ],
              ),

            // Controls Overlay
            if (_controller != null && _controller!.value.isInitialized)
              GestureDetector(
                onTap: _toggleControls,
                onDoubleTap: () => _toggleFullScreen(isLandscape),
                child: AnimatedOpacity(
                  opacity: _showControls ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    color: Colors.black45,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Top Bar
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              if (isLandscape)
                                IconButton(
                                  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                                  onPressed: () => _toggleFullScreen(true),
                                ),
                              Expanded(
                                child: Text(
                                  _resolvedTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Center Play/Pause
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.replay_10_rounded, color: Colors.white, size: 40),
                              onPressed: () {
                                final pos = _controller!.value.position - const Duration(seconds: 10);
                                _controller!.seekTo(pos < Duration.zero ? Duration.zero : pos);
                                _startHideControlsTimer();
                              },
                            ),
                            const SizedBox(width: 20),
                            IconButton(
                              icon: Icon(
                                _controller!.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                                color: Colors.redAccent,
                                size: 60,
                              ),
                              onPressed: () {
                                _controller!.value.isPlaying ? _controller!.pause() : _controller!.play();
                                _startHideControlsTimer();
                              },
                            ),
                            const SizedBox(width: 20),
                            IconButton(
                              icon: const Icon(Icons.forward_10_rounded, color: Colors.white, size: 40),
                              onPressed: () {
                                final pos = _controller!.value.position + const Duration(seconds: 10);
                                _controller!.seekTo(pos);
                                _startHideControlsTimer();
                              },
                            ),
                          ],
                        ),
                        // Bottom Seekbar
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              Text(_formatDuration(_controller!.value.position), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderThemeData(
                                    thumbColor: Colors.redAccent,
                                    activeTrackColor: Colors.redAccent,
                                    inactiveTrackColor: Colors.white24,
                                    trackHeight: 3.0,
                                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                                  ),
                                  child: Slider(
                                    min: 0.0,
                                    max: _controller!.value.duration.inSeconds.toDouble(),
                                    value: _controller!.value.position.inSeconds.toDouble().clamp(0.0, _controller!.value.duration.inSeconds.toDouble()),
                                    onChanged: (val) {
                                      _controller!.seekTo(Duration(seconds: val.toInt()));
                                      _startHideControlsTimer();
                                    },
                                  ),
                                ),
                              ),
                              Text(_formatDuration(_controller!.value.duration), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: Icon(isLandscape ? Icons.fullscreen_exit : Icons.fullscreen, color: Colors.white),
                                onPressed: () => _toggleFullScreen(isLandscape),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        top: !isLandscape,
        bottom: !isLandscape,
        child: isLandscape
            ? _buildPlayer(true)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPlayer(false),
                  
                  // YouTube-Style Scrollable Info & Audio Menus below player
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _resolvedTitle,
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          if (_resolvedIsTv)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Season $_resolvedSeason • Episode $_resolvedEpisode',
                                style: const TextStyle(color: Colors.white54, fontSize: 14),
                              ),
                            ),
                          
                          const SizedBox(height: 24),
                          const Text('Audio Tracks & Servers', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          
                          if (_streams.isEmpty && !_isLoadingStreams)
                            const Text('No audio sources found.', style: TextStyle(color: Colors.white54))
                          else
                            ...List.generate(_streams.length, (index) {
                              final stream = _streams[index];
                              final isSelected = index == _currentStreamIndex;
                              return GestureDetector(
                                onTap: () => _switchServer(index),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isSelected ? Colors.redAccent.withOpacity(0.15) : const Color(0xFF161616),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: isSelected ? Colors.redAccent : Colors.transparent),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        stream.isDubbed ? Icons.translate : Icons.dns,
                                        color: isSelected ? Colors.redAccent : Colors.white54,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          stream.name,
                                          style: TextStyle(
                                            color: isSelected ? Colors.redAccent : Colors.white,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                      if (isSelected)
                                        const Icon(Icons.check_circle, color: Colors.redAccent, size: 20),
                                    ],
                                  ),
                                ),
                              );
                            }),
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
