import 'dart:async';
import 'dart:io';
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
  final int? episodeNumber;
  final int? season;
  final int? number;
  final String? customStreamUrl;

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
    this.customStreamUrl,
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
    this.customStreamUrl,
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
    this.customStreamUrl,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  VideoPlayerController? _videoController;
  File? _tempVideoFile;
  HttpClient? _httpClient;
  StreamSubscription? _downloadSub;
  IOSink? _fileSink;

  bool _isDownloading = true;
  bool _isPlayerReady = false;
  bool _showControls = true;
  bool _isDragging = false;
  double _downloadProgress = 0.0;
  int _downloadedBytes = 0;
  int _totalBytes = 0;

  Timer? _controlsTimer;

  String get _resolvedTitle {
    if (widget.title != null && widget.title!.isNotEmpty) return widget.title!;
    if (widget.name != null && widget.name!.isNotEmpty) return widget.name!;
    for (var obj in [widget.mediaItem, widget.movie, widget.media, widget.item]) {
      if (obj != null) {
        try {
          final t = obj.title ?? obj.name;
          if (t != null && t.toString().isNotEmpty) return t.toString();
        } catch (_) {}
      }
    }
    return 'Now Playing';
  }

  String get _resolvedStreamUrl {
    if (widget.customStreamUrl != null && widget.customStreamUrl!.isNotEmpty) {
      return widget.customStreamUrl!;
    }
    return 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';
  }

  @override
  void initState() {
    super.initState();
    _lockLandscape();
    _startCacheAndPlayback();
    _resetControlsTimer();
  }

  Future<void> _lockLandscape() async {
    await WakelockPlus.enable();
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _startCacheAndPlayback() async {
    try {
      final tempDir = Directory.systemTemp;
      final uniqueName = 'jmovies_cache_${DateTime.now().millisecondsSinceEpoch}.mp4';
      _tempVideoFile = File('${tempDir.path}/$uniqueName');
      _fileSink = _tempVideoFile!.openWrite();

      _httpClient = HttpClient();
      final request = await _httpClient!.getUrl(Uri.parse(_resolvedStreamUrl));
      final response = await request.close();

      _totalBytes = response.contentLength;
      bool playerTriggered = false;

      _downloadSub = response.listen(
        (chunk) async {
          _fileSink?.add(chunk);
          _downloadedBytes += chunk.length;

          if (_totalBytes > 0 && mounted) {
            setState(() {
              _downloadProgress = (_downloadedBytes / _totalBytes).clamp(0.0, 1.0);
            });
          }

          // Buffer check: 3MB aate hi local play start!
          if (!playerTriggered && _downloadedBytes >= (3 * 1024 * 1024)) {
            playerTriggered = true;
            await _fileSink?.flush();
            _initPlayerFromFile();
          }
        },
        onDone: () async {
          await _fileSink?.flush();
          await _fileSink?.close();
          _fileSink = null;

          if (mounted) setState(() => _isDownloading = false);
          if (!playerTriggered) {
            _initPlayerFromFile();
          }
        },
        onError: (err) {
          debugPrint('Stream cache error: $err');
        },
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint('Cache initialization failed: $e');
    }
  }

  Future<void> _initPlayerFromFile() async {
    if (_tempVideoFile == null || !await _tempVideoFile!.exists()) return;

    _videoController = VideoPlayerController.file(_tempVideoFile!)
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isPlayerReady = true;
          });
          _videoController!.play();
          _videoController!.addListener(() {
            if (mounted && !_isDragging) setState(() {});
          });
        }
      });
  }

  void _resetControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && (_videoController?.value.isPlaying ?? false)) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _resetControlsTimer();
  }

  void _seekRelative(int seconds) {
    if (_videoController == null || !_videoController!.value.isInitialized) return;
    final current = _videoController!.value.position;
    final target = current + Duration(seconds: seconds);
    _videoController!.seekTo(target < Duration.zero ? Duration.zero : target);
    _resetControlsTimer();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    final h = d.inHours;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _downloadSub?.cancel();
    _httpClient?.close();

    try {
      _fileSink?.close();
    } catch (_) {}

    _controlsTimer?.cancel();
    _videoController?.dispose();

    // AUTO-DELETE: Exit hote hi file phone se permanently delete!
    if (_tempVideoFile != null && _tempVideoFile!.existsSync()) {
      try {
        _tempVideoFile!.deleteSync();
        debugPrint('Cache file deleted successfully on exit.');
      } catch (e) {
        debugPrint('Failed to delete temp video: $e');
      }
    }

    WakelockPlus.disable();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seasonNum = widget.seasonNumber ?? widget.season;
    final epNum = widget.episodeNumber ?? widget.episode ?? widget.number;
    final headerInfo = widget.isTv && seasonNum != null && epNum != null
        ? '$_resolvedTitle • S${seasonNum}E$epNum'
        : _resolvedTitle;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _toggleControls,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Hardware Native Video Player
            if (_isPlayerReady && _videoController != null)
              Center(
                child: AspectRatio(
                  aspectRatio: _videoController!.value.aspectRatio,
                  child: VideoPlayer(_videoController!),
                ),
              )
            else
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.redAccent, strokeWidth: 3),
                    const SizedBox(height: 18),
                    Text(
                      'Buffering into cache (${(_downloadProgress * 100).toInt()}%)...',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Ready to stream smoothly without buffering',
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ),

            // 2. Top Bar
            AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: _showControls ? 1.0 : 0.0,
              child: IgnorePointer(
                ignoring: !_showControls,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
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
                          headerInfo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (_isDownloading)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.redAccent.withOpacity(0.6)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 10,
                                height: 10,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${(_downloadProgress * 100).toInt()}% Cached',
                                style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // 3. Center Controls (10s back, Play/Pause, 10s forward)
            if (_showControls && _isPlayerReady && _videoController != null)
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      iconSize: 42,
                      icon: const Icon(Icons.replay_10_rounded, color: Colors.white),
                      onPressed: () => _seekRelative(-10),
                    ),
                    const SizedBox(width: 40),
                    IconButton(
                      iconSize: 68,
                      icon: Icon(
                        _videoController!.value.isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                        color: Colors.redAccent,
                      ),
                      onPressed: () {
                        setState(() {
                          _videoController!.value.isPlaying ? _videoController!.pause() : _videoController!.play();
                        });
                        _resetControlsTimer();
                      },
                    ),
                    const SizedBox(width: 40),
                    IconButton(
                      iconSize: 42,
                      icon: const Icon(Icons.forward_10_rounded, color: Colors.white),
                      onPressed: () => _seekRelative(10),
                    ),
                  ],
                ),
              ),

            // 4. Bottom Scrubber
            if (_isPlayerReady && _videoController != null)
              AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: _showControls ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !_showControls,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(18, 28, 18, 14),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.transparent, Colors.black87],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 3.5,
                              activeTrackColor: Colors.redAccent,
                              inactiveTrackColor: Colors.white24,
                              thumbColor: Colors.redAccent,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                            ),
                            child: Slider(
                              value: _videoController!.value.duration.inMilliseconds > 0
                                  ? (_videoController!.value.position.inMilliseconds / _videoController!.value.duration.inMilliseconds).clamp(0.0, 1.0)
                                  : 0.0,
                              onChangeStart: (_) => _isDragging = true,
                              onChangeEnd: (val) {
                                _isDragging = false;
                                final ms = (_videoController!.value.duration.inMilliseconds * val).toInt();
                                _videoController!.seekTo(Duration(milliseconds: ms));
                              },
                              onChanged: (val) {
                                setState(() {});
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDuration(_videoController!.value.position),
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  _formatDuration(_videoController!.value.duration),
                                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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
