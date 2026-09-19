import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/movie_model.dart';
import '../../data/models/tv_model.dart';
import '../../data/models/video_source_model.dart';
import '../../providers/movie_providers.dart';

/// Fullscreen streaming player for both movies and TV episodes.
///
/// Source-switching model: [StreamBundle.sources] lists the available
/// playable sources (e.g. different CDN edges/qualities from YOUR
/// backend), presented to the user as "Server 1/2/3". If the
/// currently selected source fails, playback automatically advances to
/// the next one.
///
/// NOTE on multi-audio: the base `video_player` plugin has no public API
/// for switching in-stream HLS audio tracks. Where a real ExoPlayer-backed
/// player (e.g. better_player_plus) is wired in later, [AudioTrack.trackId]
/// can drive native track selection directly. Until then, this screen
/// switches audio by re-pointing playback at a separate, language-specific
/// URL when one is provided (see [AudioTrack.url]).
class PlayerScreen extends ConsumerStatefulWidget {
  final String title;
  final Future<StreamBundle> Function(WidgetRef ref) fetchBundle;

  const PlayerScreen._({required this.title, required this.fetchBundle});

  factory PlayerScreen.forMovie(Movie movie) => PlayerScreen._(
        title: movie.title,
        fetchBundle: (ref) =>
            ref.read(movieRepositoryProvider).getMovieStreamBundle(movie.id),
      );

  factory PlayerScreen.forEpisode({
    required TvShow show,
    required Episode episode,
  }) =>
      PlayerScreen._(
        title: '${show.name} · S${episode.seasonNumber} E${episode.episodeNumber} · ${episode.name}',
        fetchBundle: (ref) => ref.read(movieRepositoryProvider).getEpisodeStreamBundle(
              show.id,
              episode.seasonNumber,
              episode.episodeNumber,
            ),
      );

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  VideoPlayerController? _videoController;
  List<VideoSource> _sources = [];
  int _currentSourceIndex = 0;
  int _currentAudioIndex = 0;
  int _currentQualityIndex = 0;
  int? _currentSubtitleIndex; // null = off
  bool _isInitializing = true;
  String? _errorMessage;
  double _playbackSpeed = 1.0;
  BoxFit _aspectFit = BoxFit.contain;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WakelockPlus.enable();
    _loadStreamBundle();
  }

  Future<void> _loadStreamBundle() async {
    try {
      // 60s timeout tolerates slow networks before giving up on this attempt.
      final bundle = await widget.fetchBundle(ref).timeout(const Duration(seconds: 60));
      if (bundle.sources.isEmpty) {
        setState(() {
          _errorMessage = 'No playable sources found for this title.';
          _isInitializing = false;
        });
        return;
      }
      _sources = bundle.sources;
      await _initPlayer(sourceIndex: 0);
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not reach the streaming backend.';
        _isInitializing = false;
      });
    }
  }

  VideoSource get _activeSource => _sources[_currentSourceIndex];

  String _resolveActiveUrl() {
    final source = _activeSource;
    // Priority: explicit quality selection > audio-specific URL > source default.
    if (source.qualities.isNotEmpty && _currentQualityIndex < source.qualities.length) {
      return source.qualities[_currentQualityIndex].url;
    }
    if (source.audioTracks.isNotEmpty &&
        _currentAudioIndex < source.audioTracks.length &&
        source.audioTracks[_currentAudioIndex].url != null) {
      return source.audioTracks[_currentAudioIndex].url!;
    }
    return source.url;
  }

  /// Initializes the player for source [sourceIndex]. On failure,
  /// automatically falls back to the next available source
  /// (Server 1 -> 2 -> 3), tolerating slow connections with a
  /// 60s timeout per attempt.
  Future<void> _initPlayer({required int sourceIndex}) async {
    if (sourceIndex >= _sources.length) {
      setState(() {
        _errorMessage = 'All sources failed. Please try again later.';
        _isInitializing = false;
      });
      return;
    }

    setState(() {
      _isInitializing = true;
      _errorMessage = null;
      _currentSourceIndex = sourceIndex;
      _currentAudioIndex = 0;
      _currentQualityIndex = 0;
      _currentSubtitleIndex = null;
    });

    await _disposeController();

    final url = _resolveActiveUrl();
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));

    try {
      await controller.initialize().timeout(const Duration(seconds: 60));
      await controller.setPlaybackSpeed(_playbackSpeed);
      await controller.play();

      setState(() {
        _videoController = controller;
        _isInitializing = false;
      });
    } catch (e) {
      // Automatic fallback logic: this source is slow/offline, try the next.
      if (sourceIndex + 1 < _sources.length) {
        _initPlayer(sourceIndex: sourceIndex + 1);
      } else {
        setState(() {
          _errorMessage =
              'Source "${_sources[sourceIndex].label}" failed and no fallback sources remain.';
          _isInitializing = false;
        });
      }
    }
  }

  /// Re-initializes playback at the current position when audio/quality
  /// selection changes the active URL.
  Future<void> _reloadAtCurrentPosition() async {
    final previousPosition = _videoController?.value.position ?? Duration.zero;
    await _disposeController();

    final url = _resolveActiveUrl();
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    setState(() => _isInitializing = true);

    try {
      await controller.initialize().timeout(const Duration(seconds: 60));
      await controller.seekTo(previousPosition);
      await controller.setPlaybackSpeed(_playbackSpeed);
      await controller.play();
      setState(() {
        _videoController = controller;
        _isInitializing = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to switch track.';
        _isInitializing = false;
      });
    }
  }

  Future<void> _disposeController() async {
    await _videoController?.dispose();
    _videoController = null;
  }

  void _showSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.charcoal,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Select Server',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
            ),
            ..._sources.asMap().entries.map((entry) {
              final i = entry.key;
              final source = entry.value;
              final isActive = i == _currentSourceIndex;
              return ListTile(
                leading: Icon(
                  isActive ? Icons.play_circle_fill : Icons.dns_rounded,
                  color: isActive ? AppColors.crimson : AppColors.textSecondary,
                ),
                title: Text(_serverLabel(i, source), style: const TextStyle(color: Colors.white)),
                subtitle: Text(source.format.name.toUpperCase(),
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                trailing: isActive ? const Icon(Icons.check_circle, color: AppColors.crimson) : null,
                onTap: () {
                  Navigator.pop(context);
                  if (i != _currentSourceIndex) _initPlayer(sourceIndex: i);
                },
              );
            }),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  String _serverLabel(int index, VideoSource source) {
    const names = ['Server 1', 'Server 2', 'Server 3', 'Server 4'];
    final name = index < names.length ? names[index] : 'Server ${index + 1}';
    return '$name · ${source.label}';
  }

  void _showAudioSheet() {
    final tracks = _activeSource.audioTracks;
    if (tracks.isEmpty) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.charcoal,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Audio Language',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
            ),
            ...tracks.asMap().entries.map((entry) {
              final i = entry.key;
              final track = entry.value;
              final isActive = i == _currentAudioIndex;
              return ListTile(
                leading: Icon(Icons.language_rounded,
                    color: isActive ? AppColors.crimson : AppColors.textSecondary),
                title: Text(track.language, style: const TextStyle(color: Colors.white)),
                trailing: isActive ? const Icon(Icons.check_circle, color: AppColors.crimson) : null,
                onTap: () {
                  Navigator.pop(context);
                  if (i != _currentAudioIndex) {
                    setState(() => _currentAudioIndex = i);
                    _reloadAtCurrentPosition();
                  }
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showQualitySheet() {
    final qualities = _activeSource.qualities;
    if (qualities.isEmpty) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.charcoal,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Video Quality',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
            ),
            ...qualities.asMap().entries.map((entry) {
              final i = entry.key;
              final q = entry.value;
              final isActive = i == _currentQualityIndex;
              return ListTile(
                leading: Icon(Icons.hd_rounded,
                    color: isActive ? AppColors.crimson : AppColors.textSecondary),
                title: Text(q.label, style: const TextStyle(color: Colors.white)),
                trailing: isActive ? const Icon(Icons.check_circle, color: AppColors.crimson) : null,
                onTap: () {
                  Navigator.pop(context);
                  if (i != _currentQualityIndex) {
                    setState(() => _currentQualityIndex = i);
                    _reloadAtCurrentPosition();
                  }
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showSubtitleSheet() {
    final subs = _activeSource.subtitles;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.charcoal,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Subtitles',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
            ),
            ListTile(
              leading: Icon(Icons.subtitles_off_rounded,
                  color: _currentSubtitleIndex == null ? AppColors.crimson : AppColors.textSecondary),
              title: const Text('Off', style: TextStyle(color: Colors.white)),
              trailing: _currentSubtitleIndex == null
                  ? const Icon(Icons.check_circle, color: AppColors.crimson)
                  : null,
              onTap: () {
                setState(() => _currentSubtitleIndex = null);
                Navigator.pop(context);
              },
            ),
            if (subs.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No subtitle tracks available for this source.',
                    style: TextStyle(color: AppColors.textMuted)),
              )
            else
              ...subs.asMap().entries.map((entry) {
                final i = entry.key;
                final sub = entry.value;
                final isActive = i == _currentSubtitleIndex;
                return ListTile(
                  leading: Icon(
                    sub.isEmbedded ? Icons.closed_caption_rounded : Icons.subtitles_rounded,
                    color: isActive ? AppColors.crimson : AppColors.textSecondary,
                  ),
                  title: Text(sub.language, style: const TextStyle(color: Colors.white)),
                  subtitle: Text(sub.isEmbedded ? 'Embedded' : 'External file',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  trailing: isActive ? const Icon(Icons.check_circle, color: AppColors.crimson) : null,
                  onTap: () {
                    // NOTE: rendering external .vtt/.srt text on top of the
                    // video needs a subtitle-overlay package (e.g.
                    // subtitle_wrapper) wired here; this UI captures the
                    // selection so that integration is a drop-in later.
                    setState(() => _currentSubtitleIndex = i);
                    Navigator.pop(context);
                  },
                );
              }),
          ],
        ),
      ),
    );
  }

  void _showSpeedSheet() {
    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.charcoal,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: speeds.map((s) {
            return ListTile(
              title: Text('${s}x', style: const TextStyle(color: Colors.white)),
              trailing:
                  _playbackSpeed == s ? const Icon(Icons.check, color: AppColors.crimson) : null,
              onTap: () {
                setState(() => _playbackSpeed = s);
                _videoController?.setPlaybackSpeed(s);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WakelockPlus.disable();
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Center(child: _buildPlayerBody()),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerBody() {
    if (_isInitializing) {
      final isFallbackAttempt = _currentSourceIndex > 0;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.crimson),
          const SizedBox(height: 16),
          Text(
            isFallbackAttempt
                ? 'Buffering alternative server…'
                : 'Connecting to stream…',
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      );
    }

    if (_errorMessage != null) {
      return _PlayerErrorView(
        message: _errorMessage!,
        onRetry: () => _initPlayer(sourceIndex: 0),
      );
    }

    if (_videoController == null || !_videoController!.value.isInitialized) {
      return const SizedBox.shrink();
    }

    return _CustomVideoControls(
      controller: _videoController!,
      title: widget.title,
      currentSourceLabel: _serverLabel(_currentSourceIndex, _activeSource),
      aspectFit: _aspectFit,
      hasAudioTracks: _activeSource.audioTracks.length > 1,
      hasQualities: _activeSource.qualities.length > 1,
      onToggleAspect: () {
        setState(() {
          _aspectFit = switch (_aspectFit) {
            BoxFit.contain => BoxFit.cover,
            BoxFit.cover => BoxFit.fill,
            _ => BoxFit.contain,
          };
        });
      },
      onOpenServers: _showSourceSheet,
      onOpenAudio: _showAudioSheet,
      onOpenQuality: _showQualitySheet,
      onOpenSubtitles: _showSubtitleSheet,
      onOpenSpeed: _showSpeedSheet,
    );
  }
}

/// Fully custom playback control surface: play/pause, double-tap ±10s skip,
/// scrub bar, aspect toggle (Fit/Zoom/Stretch), speed, server/audio/quality/
/// subtitle pickers.
class _CustomVideoControls extends StatefulWidget {
  final VideoPlayerController controller;
  final String title;
  final String currentSourceLabel;
  final BoxFit aspectFit;
  final bool hasAudioTracks;
  final bool hasQualities;
  final VoidCallback onToggleAspect;
  final VoidCallback onOpenServers;
  final VoidCallback onOpenAudio;
  final VoidCallback onOpenQuality;
  final VoidCallback onOpenSubtitles;
  final VoidCallback onOpenSpeed;

  const _CustomVideoControls({
    required this.controller,
    required this.title,
    required this.currentSourceLabel,
    required this.aspectFit,
    required this.hasAudioTracks,
    required this.hasQualities,
    required this.onToggleAspect,
    required this.onOpenServers,
    required this.onOpenAudio,
    required this.onOpenQuality,
    required this.onOpenSubtitles,
    required this.onOpenSpeed,
  });

  @override
  State<_CustomVideoControls> createState() => _CustomVideoControlsState();
}

class _CustomVideoControlsState extends State<_CustomVideoControls> {
  bool _controlsVisible = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTick);
    _scheduleHide();
  }

  void _onTick() => setState(() {});

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 5), () { // spec: 4-5s auto-hide
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _scheduleHide();
  }

  void _skip(Duration delta) {
    final pos = widget.controller.value.position;
    widget.controller.seekTo(pos + delta);
    _scheduleHide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    widget.controller.removeListener(_onTick);
    super.dispose();
  }

  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  String _aspectLabel(BoxFit fit) => switch (fit) {
        BoxFit.contain => 'Fit',
        BoxFit.cover => 'Zoom',
        _ => 'Stretch',
      };

  @override
  Widget build(BuildContext context) {
    final value = widget.controller.value;
    final position = value.position;
    final duration = value.duration;

    return GestureDetector(
      onTap: _toggleControls,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: widget.aspectFit,
            child: SizedBox(
              width: value.size.width,
              height: value.size.height,
              child: VideoPlayer(widget.controller),
            ),
          ),
          // Double-tap zones for ±10s skip.
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onDoubleTap: () => _skip(const Duration(seconds: -10)),
                  behavior: HitTestBehavior.translucent,
                ),
              ),
              const SizedBox(width: 80), // leave center for play/pause tap
              Expanded(
                child: GestureDetector(
                  onDoubleTap: () => _skip(const Duration(seconds: 10)),
                  behavior: HitTestBehavior.translucent,
                ),
              ),
            ],
          ),
          if (_controlsVisible)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.55),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                  stops: const [0, 0.25, 0.6, 1],
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(56, 8, 16, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.title,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: widget.onOpenServers,
                            icon: const Icon(Icons.dns_rounded, color: Colors.white, size: 18),
                            label: Text(widget.currentSourceLabel,
                                style: const TextStyle(color: Colors.white, fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _controlIcon(Icons.replay_10_rounded, () => _skip(const Duration(seconds: -10))),
                        const SizedBox(width: 32),
                        _controlIcon(
                          value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                          () {
                            value.isPlaying ? widget.controller.pause() : widget.controller.play();
                            _scheduleHide();
                          },
                          size: 64,
                        ),
                        const SizedBox(width: 32),
                        _controlIcon(Icons.forward_10_rounded, () => _skip(const Duration(seconds: 10))),
                      ],
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Text(_formatDuration(position), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 2,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                              ),
                              child: Slider(
                                min: 0,
                                max: duration.inMilliseconds.toDouble().clamp(1, double.infinity),
                                value: position.inMilliseconds.clamp(0, duration.inMilliseconds).toDouble(),
                                onChanged: (v) => widget.controller.seekTo(Duration(milliseconds: v.toInt())),
                              ),
                            ),
                          ),
                          Text(_formatDuration(duration), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        reverse: true,
                        child: Row(
                          children: [
                            if (widget.hasAudioTracks)
                              _pillButton(Icons.language_rounded, 'Audio', widget.onOpenAudio),
                            if (widget.hasQualities)
                              _pillButton(Icons.hd_rounded, 'Quality', widget.onOpenQuality),
                            _pillButton(Icons.subtitles_outlined, 'Subtitles', widget.onOpenSubtitles),
                            _pillButton(Icons.speed_rounded, '${widget.controller.value.playbackSpeed}x',
                                widget.onOpenSpeed),
                            _pillButton(Icons.aspect_ratio_rounded, _aspectLabel(widget.aspectFit),
                                widget.onToggleAspect),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _pillButton(IconData icon, String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white, size: 18),
        label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        style: TextButton.styleFrom(
          backgroundColor: Colors.white12,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),
      ),
    );
  }

  Widget _controlIcon(IconData icon, VoidCallback onTap, {double size = 44}) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, color: Colors.white, size: size),
    );
  }
}

class _PlayerErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const _PlayerErrorView({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.crimson, size: 40),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ],
      ),
    );
  }
}
