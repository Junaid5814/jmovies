import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/config/app_config.dart';
import '../../data/models/video_source_model.dart' hide AudioTrack, SubtitleTrack;
import '../../data/services/stream_source_service.dart';

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

  Tracks _tracks = const Tracks();
  bool _isLoading = true;
  bool _isBuffering = false;
  String? _errorMessage;
  bool _usingDemoStream = false;

  int get _resolvedId {
    if (widget.tmdbId != null && widget.tmdbId! > 0) {
      return widget.tmdbId!;
    }
    try {
      final dynamic id = widget.movie?.id;
      if (id != null) {
        return int.tryParse(id.toString()) ?? 0;
      }
    } catch (_) {}
    try {
      final dynamic id = widget.show?.id;
      if (id != null) {
        return int.tryParse(id.toString()) ?? 0;
      }
    } catch (_) {}
    try {
      final dynamic id = widget.mediaItem?.id;
      if (id != null) {
        return int.tryParse(id.toString()) ?? 0;
      }
    } catch (_) {}
    return 0;
  }

  String get _resolvedTitle {
    final suppliedTitle = widget.title?.trim();
    if (suppliedTitle != null && suppliedTitle.isNotEmpty) {
      return suppliedTitle;
    }
    try {
      final dynamic value = widget.movie?.title;
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    } catch (_) {}
    try {
      final dynamic value = widget.show?.name;
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    } catch (_) {}
    try {
      final dynamic value = widget.mediaItem?.title;
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    } catch (_) {}
    return 'JMovies Player';
  }

  bool get _resolvedIsTv {
    return widget.isTv ||
        widget.show != null ||
        widget.episode != null ||
        widget.seasonNumber != null;
  }

  int get _resolvedSeason {
    if (widget.seasonNumber != null && widget.seasonNumber! > 0) {
      return widget.seasonNumber!;
    }
    try {
      final dynamic value = widget.episode?.seasonNumber;
      return int.tryParse(value?.toString() ?? '') ?? 1;
    } catch (_) {
      return 1;
    }
  }

  int get _resolvedEpisode {
    if (widget.episodeNumber != null && widget.episodeNumber! > 0) {
      return widget.episodeNumber!;
    }
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
      setState(() {
        _tracks = tracks;
      });
    });

    _bufferingSubscription = _player.stream.buffering.listen((buffering) {
      if (!mounted) return;
      setState(() {
        _isBuffering = buffering;
      });
    });

    _errorSubscription = _player.stream.error.listen((message) {
      if (!mounted || message.trim().isEmpty) return;
      setState(() {
        _errorMessage = 'Video could not be played. Please check the stream connection.';
        _isLoading = false;
      });
    });

    _loadVideo();
  }

  Future<void> _enterFullscreen() async {
    await WakelockPlus.enable();
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _loadVideo() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_resolvedId <= 0) {
        throw const FormatException('Invalid TMDB content ID.');
      }

      final service = StreamSourceService(
        baseUrl: AppConfig.hasStreamApiBaseUrl
            ? AppConfig.normalizedStreamApiBaseUrl
            : null,
      );

      final StreamBundle bundle;

      if (_resolvedIsTv) {
        bundle = await service
            .fetchEpisodeStreamBundle(
              _resolvedId,
              _resolvedSeason,
              _resolvedEpisode,
            )
            .timeout(const Duration(seconds: 30));
      } else {
        bundle = await service
            .fetchMovieStreamBundle(_resolvedId)
            .timeout(const Duration(seconds: 30));
      }

      if (bundle.sources.isEmpty) {
        throw const FormatException('No playable master stream was returned.');
      }

      final source = bundle.sources.first;
      _usingDemoStream = source.id.startsWith('placeholder');

      await _player.open(
        Media(source.url),
        play: true,
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _tracks = _player.state.tracks;
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'The video took too long to load. Check your internet connection.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to load this video.';
      });
    }
  }

  Future<void> _openSettings() async {
    if (_isLoading || _errorMessage != null) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF121212),
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return _PlaybackSettingsSheet(
          player: _player,
          tracks: _tracks,
        );
      },
    );

    if (mounted) {
      setState(() {
        _tracks = _player.state.tracks;
      });
    }
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

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: isLandscape
          ? null
          : AppBar(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              title: Text(
                _resolvedTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
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
        child: Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_errorMessage == null)
                    Video(
                      controller: _videoController,
                      fit: BoxFit.contain,
                      controls: AdaptiveVideoControls,
                    ),
                  if (_isLoading)
                    const ColoredBox(
                      color: Colors.black,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFE50914),
                        ),
                      ),
                    ),
                  if (!_isLoading && _isBuffering && _errorMessage == null)
                    const IgnorePointer(
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFE50914),
                        ),
                      ),
                    ),
                  if (_errorMessage != null)
                    _PlayerErrorView(
                      message: _errorMessage!,
                      onRetry: _loadVideo,
                    ),
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
            if (!isLandscape && _usingDemoStream)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                color: const Color(0xFF171717),
                child: const Text(
                  'Demo stream active — connect STREAM_API_BASE_URL to play your catalogue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
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

  const _PlayerErrorView({
    required this.message,
    required this.onRetry,
  });

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
              const Icon(
                Icons.play_disabled_rounded,
                color: Colors.white54,
                size: 56,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                ),
              ),
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

  const _PlaybackSettingsSheet({
    required this.player,
    required this.tracks,
  });

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

  List<AudioTrack> get _audioTracks {
    return _uniqueById<AudioTrack>(
      _tracks.audio.where((track) => track.id != 'no').toList(),
    );
  }

  List<SubtitleTrack> get _subtitleTracks {
    return _uniqueById<SubtitleTrack>(_tracks.subtitle);
  }

  List<VideoTrack> get _videoTracks {
    return _uniqueById<VideoTrack>(
      _tracks.video.where((track) => track.id != 'no').toList(),
    );
  }

  List<T> _uniqueById<T>(List<T> tracks) {
    final ids = <String>{};
    final result = <T>[];

    for (final track in tracks) {
      final dynamic value = track;
      final id = value.id.toString();

      if (ids.add(id)) {
        result.add(track);
      }
    }
    return result;
  }

  String _audioLabel(AudioTrack track) {
    if (track.id == 'auto') return 'Automatic';
    final title = track.title?.trim();
    final language = track.language?.trim();

    if (title != null && title.isNotEmpty) return title;
    if (language != null && language.isNotEmpty) return language.toUpperCase();
    return 'Audio ${track.id}';
  }

  String _subtitleLabel(SubtitleTrack track) {
    if (track.id == 'no') return 'Off';
    if (track.id == 'auto') return 'Automatic';
    final title = track.title?.trim();
    final language = track.language?.trim();

    if (title != null && title.isNotEmpty) return title;
    if (language != null && language.isNotEmpty) return language.toUpperCase();
    return 'Subtitle ${track.id}';
  }

  String _videoLabel(VideoTrack track) {
    if (track.id == 'auto') return 'Auto';
    if (track.h != null && track.h! > 0) return '${track.h}p';
    final title = track.title?.trim();
    if (title != null && title.isNotEmpty) return title;
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
            const Text(
              'Playback Settings',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 24),
            const _SettingsHeading(
              icon: Icons.language_rounded,
              title: 'Audio & Language',
            ),
            if (_audioTracks.isEmpty)
              const _EmptyTrackMessage(
                message: 'No alternate audio track found in this stream.',
              )
            else
              ..._audioTracks.map(
                (track) => RadioListTile<String>(
                  value: track.id,
                  groupValue: selected.audio.id,
                  activeColor: const Color(0xFFE50914),
                  title: Text(
                    _audioLabel(track),
                    style: const TextStyle(color: Colors.white),
                  ),
                  onChanged: (_) async {
                    await widget.player.setAudioTrack(track);
                    if (mounted) setState(() {});
                  },
                ),
              ),
            const Divider(color: Colors.white12, height: 32),
            const _SettingsHeading(
              icon: Icons.subtitles_rounded,
              title: 'Subtitles',
            ),
            if (_subtitleTracks.isEmpty)
              const _EmptyTrackMessage(
                message: 'No subtitle track found in this stream.',
              )
            else
              ..._subtitleTracks.map(
                (track) => RadioListTile<String>(
                  value: track.id,
                  groupValue: selected.subtitle.id,
                  activeColor: const Color(0xFFE50914),
                  title: Text(
                    _subtitleLabel(track),
                    style: const TextStyle(color: Colors.white),
                  ),
                  onChanged: (_) async {
                    await widget.player.setSubtitleTrack(track);
                    if (mounted) setState(() {});
                  },
                ),
              ),
            const Divider(color: Colors.white12, height: 32),
            const _SettingsHeading(
              icon: Icons.high_quality_rounded,
              title: 'Video Quality',
            ),
            if (_videoTracks.isEmpty)
              const _EmptyTrackMessage(
                message: 'Adaptive quality is controlled automatically.',
              )
            else
              ..._videoTracks.map(
                (track) => RadioListTile<String>(
                  value: track.id,
                  groupValue: selected.video.id,
                  activeColor: const Color(0xFFE50914),
                  title: Text(
                    _videoLabel(track),
                    style: const TextStyle(color: Colors.white),
                  ),
                  onChanged: (_) async {
                    await widget.player.setVideoTrack(track);
                    if (mounted) setState(() {});
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SettingsHeading extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SettingsHeading({
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFE50914)),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _EmptyTrackMessage extends StatelessWidget {
  final String message;

  const _EmptyTrackMessage({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 16,
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 13,
        ),
      ),
    );
  }
}
