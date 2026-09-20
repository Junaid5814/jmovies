import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
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
  VideoPlayerController? _controller;
  bool _isFullScreen = false;
  bool _showControls = true;
  Timer? _controlsTimer;
  int _currentSourceIndex = 0;
  bool _hasError = false;
  String _errorMessage = '';

  int get _resolvedId {
    if (widget.tmdbId != null && widget.tmdbId! > 0) return widget.tmdbId!;
    if (widget.id != null && widget.id! > 0) return widget.id!;
    for (var obj in [widget.show, widget.movie, widget.mediaItem, widget.media, widget.item]) {
      if (obj != null) {
        try {
          final val = obj.id;
          if (val != null && val is int && val > 0) return val;
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
    return 'Now Playing';
  }

  int get _resolvedSeason => widget.seasonNumber ?? widget.season ?? 1;
  int get _resolvedEpisode => widget.episodeNumber ?? 1;

  bool get _resolvedIsTv {
    if (widget.show != null || widget.episode != null || widget.isTv) return true;
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

  List<Map<String, String>> get _streamList {
    final id = _resolvedId;
    final s = _resolvedSeason;
    final e = _resolvedEpisode;

    if (_resolvedIsTv) {
      return [
        {
          'title': 'Original Audio (Fast HD)',
          'tag': 'English / Original',
          'url': 'https://vidsrc.cc/v2/embed/tv/$id/$s/$e',
          'type': 'hls'
        },
        {
          'title': 'Hindi Dubbed Stream',
          'tag': 'Hindi Audio',
          'url': 'https://multiembed.mov/?video_id=$id&tmdb=1&s=$s&e=$e',
          'type': 'hls'
        },
      ];
    } else {
      return [
        {
          'title': 'Original Audio (Fast HD)',
          'tag': 'English / Original',
          'url': 'https://vidsrc.cc/v2/embed/movie/$id',
          'type': 'hls'
        },
        {
          'title': 'Hindi Dubbed Stream',
          'tag': 'Hindi Audio',
          'url': 'https://multiembed.mov/?video_id=$id&tmdb=1',
          'type': 'hls'
        },
      ];
    }
  }

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    setState(() {
      _hasError = false;
    });

    final currentStream = _streamList[_currentSourceIndex];
    final uri = Uri.parse(currentStream['url']!);

    await _controller?.dispose();
    _controller = VideoPlayerController.networkUrl(
      uri,
      httpHeaders: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Referer': 'https://vidsrc.cc/',
      },
    );

    try {
      await _controller!.initialize();
      _controller!.play();
      _controller!.addListener(() {
        if (mounted) setState(() {});
      });
      _startControlsTimer();
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Direct stream connecting... Switch source if needed.';
        });
      }
    }
    if (mounted) setState(() {});
  }

  void _togglePlayPause() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _controlsTimer?.cancel();
        _showControls = true;
      } else {
        _controller!.play();
        _startControlsTimer();
      }
    });
  }

  void _seekRelative(int seconds) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    final current = _controller!.value.position;
    final target = current + Duration(seconds: seconds);
    _controller!.seekTo(target);
    _startControlsTimer();
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
    _startControlsTimer();
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _controller != null && _controller!.value.isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _startControlsTimer();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  void _openSourcePicker() {
    _controlsTimer?.cancel();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.75,
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Audio & Stream Source', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close, color: Colors.white54, size: 20), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 8),
                ...List.generate(_streamList.length, (idx) {
                  final isSel = idx == _currentSourceIndex;
                  final item = _streamList[idx];
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
                      title: Text(item['title']!, style: TextStyle(color: isSel ? Colors.redAccent : Colors.white, fontSize: 13.5, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                      subtitle: Text(item['tag']!, style: TextStyle(color: isSel ? Colors.redAccent.withOpacity(0.8) : Colors.white38, fontSize: 11)),
                      trailing: isSel ? const Icon(Icons.check_circle, color: Colors.redAccent, size: 18) : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _currentSourceIndex = idx;
                        });
                        _initPlayer();
                      },
                    ),
                  );
                }),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    ).then((_) => _startControlsTimer());
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    _controller?.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WakelockPlus.disable();
    super.dispose();
  }

  Widget _buildVideoPlayer() {
    final isInitialized = _controller != null && _controller!.value.isInitialized;
    final position = isInitialized ? _controller!.value.position : Duration.zero;
    final duration = isInitialized ? _controller!.value.duration : Duration.zero;

    return AspectRatio(
      aspectRatio: _isFullScreen ? (MediaQuery.of(context).size.width / MediaQuery.of(context).size.height) : (16 / 9),
      child: Container(
        color: Colors.black,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (isInitialized)
              FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: _controller!.value.size.width,
                  height: _controller!.value.size.height,
                  child: VideoPlayer(_controller!),
                ),
              )
            else if (_hasError)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 36),
                    const SizedBox(height: 8),
                    Text(_errorMessage, style: const TextStyle(color: Colors.white70, fontSize: 12), textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                      icon: const Icon(Icons.refresh, size: 16, color: Colors.white),
                      label: const Text('Try Again', style: TextStyle(color: Colors.white, fontSize: 12)),
                      onPressed: _initPlayer,
                    ),
                  ],
                ),
              )
            else
              const Center(child: CircularProgressIndicator(color: Colors.redAccent)),

            // Touch Listener for Controls
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _toggleControls,
            ),

            // Sleek Custom Video Controls Overlay (No Duplicate Web Controls)
            if (_showControls && isInitialized)
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _showControls ? 1.0 : 0.0,
                child: Container(
                  color: Colors.black.withOpacity(0.45),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Top Row: Back, Title, Audio/Source
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () {
                                if (_isFullScreen) {
                                  _toggleFullScreen();
                                } else {
                                  Navigator.pop(context);
                                }
                              },
                              child: const Padding(
                                padding: EdgeInsets.all(6),
                                child: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _resolvedTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                            ),
                            InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: _openSourcePicker,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white24, width: 0.8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.translate_rounded, color: Colors.redAccent, size: 13),
                                    const SizedBox(width: 5),
                                    Text(
                                      _streamList[_currentSourceIndex]['tag']!,
                                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Center: 10s Rewind, Play/Pause, 10s Forward
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            iconSize: 34,
                            icon: const Icon(Icons.replay_10_rounded, color: Colors.white),
                            onPressed: () => _seekRelative(-10),
                          ),
                          const SizedBox(width: 24),
                          IconButton(
                            iconSize: 52,
                            icon: Icon(
                              _controller!.value.isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
                              color: Colors.redAccent,
                            ),
                            onPressed: _togglePlayPause,
                          ),
                          const SizedBox(width: 24),
                          IconButton(
                            iconSize: 34,
                            icon: const Icon(Icons.forward_10_rounded, color: Colors.white),
                            onPressed: () => _seekRelative(10),
                          ),
                        ],
                      ),

                      // Bottom: Time, Red Slider, Fullscreen
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        child: Row(
                          children: [
                            Text(
                              _formatDuration(position),
                              style: const TextStyle(color: Colors.white, fontSize: 11),
                            ),
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 2.8,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                  activeTrackColor: Colors.redAccent,
                                  inactiveTrackColor: Colors.white24,
                                  thumbColor: Colors.redAccent,
                                ),
                                child: Slider(
                                  min: 0.0,
                                  max: duration.inMilliseconds.toDouble() > 0 ? duration.inMilliseconds.toDouble() : 1.0,
                                  value: position.inMilliseconds.toDouble().clamp(0.0, duration.inMilliseconds.toDouble() > 0 ? duration.inMilliseconds.toDouble() : 1.0),
                                  onChanged: (val) {
                                    _seekRelative((val - position.inMilliseconds) ~/ 1000);
                                  },
                                ),
                              ),
                            ),
                            Text(
                              _formatDuration(duration),
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: _toggleFullScreen,
                              child: Icon(
                                _isFullScreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ],
                        ),
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

  @override
  Widget build(BuildContext context) {
    if (_isFullScreen) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(child: _buildVideoPlayer()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SafeArea(
        child: Column(
          children: [
            // Top 16:9 Video Box (YouTube Style)
            _buildVideoPlayer(),

            // Scrollable Content Below Video
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

                    // Quick Badges
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                          child: const Text('HD', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _resolvedIsTv ? 'TV Series • Ep $_resolvedEpisode' : 'Movie',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: _openSourcePicker,
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
                                  _streamList[_currentSourceIndex]['tag']!,
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    const Divider(color: Colors.white12),
                    const SizedBox(height: 12),

                    // Clean Options / Details Area
                    const Text('Audio & Stream Details', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.surround_sound_rounded, color: Colors.redAccent, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Current Stream: ${_streamList[_currentSourceIndex]['title']}',
                                  style: const TextStyle(color: Colors.white, fontSize: 12.5),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: const [
                              Icon(Icons.aspect_ratio_rounded, color: Colors.white54, size: 18),
                              SizedBox(width: 10),
                              Text('Auto Fit 16:9 • Tap fullscreen for Cinema View', style: TextStyle(color: Colors.white54, fontSize: 11.5)),
                            ],
                          ),
                        ],
                      ),
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
