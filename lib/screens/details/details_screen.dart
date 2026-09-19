import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/movie_model.dart';
import '../../data/models/tv_model.dart';
import '../../providers/movie_providers.dart';
import '../player/player_screen.dart';

/// Single details screen for both movies and TV/anime titles. [isTv]
/// decides which TMDB endpoint is fetched and whether a "Watch Now" button
/// (movies) or a season chip selector + episode list (TV/anime) is shown.
class DetailsScreen extends ConsumerWidget {
  final int id;
  final bool isTv;

  const DetailsScreen({super.key, required this.id, required this.isTv});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isTv) {
      final showAsync = ref.watch(tvDetailsProvider(id));
      return Scaffold(
        backgroundColor: AppColors.pureBlack,
        body: showAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.crimson)),
          error: (e, _) => const Center(
            child: Text('Failed to load details', style: TextStyle(color: AppColors.textSecondary)),
          ),
          data: (show) => _TvDetailsBody(show: show),
        ),
      );
    }

    final movieAsync = ref.watch(movieDetailsProvider(id));
    return Scaffold(
      backgroundColor: AppColors.pureBlack,
      body: movieAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.crimson)),
        error: (e, _) => const Center(
          child: Text('Failed to load details', style: TextStyle(color: AppColors.textSecondary)),
        ),
        data: (movie) => _MovieDetailsBody(movie: movie),
      ),
    );
  }
}

// =========================================================================
// Movie details: standard "Watch Now" button
// =========================================================================

class _MovieDetailsBody extends StatelessWidget {
  final Movie movie;
  const _MovieDetailsBody({required this.movie});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        _Backdrop(imageUrl: movie.backdropUrl),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(movie.title, style: Theme.of(context).textTheme.displayLarge),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: AppColors.gold, size: 20),
                    const SizedBox(width: 4),
                    Text(movie.voteAverage.toStringAsFixed(1),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 16),
                    Text(movie.releaseYear, style: const TextStyle(color: AppColors.textSecondary)),
                    if (movie.runtimeMinutes > 0) ...[
                      const SizedBox(width: 16),
                      Text('${movie.runtimeMinutes} min',
                          style: const TextStyle(color: AppColors.textSecondary)),
                    ],
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlayerScreen.forMovie(movie),
                      ),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded, size: 28),
                    label: const Text('Watch Now'),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  ),
                ),
                const SizedBox(height: 28),
                Text('Synopsis', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  movie.overview.isEmpty ? 'No synopsis available.' : movie.overview,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (movie.cast.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  Text('Cast', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  _CastRow(cast: movie.cast),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// =========================================================================
// TV / Anime details: season chip selector + episode list
// =========================================================================

class _TvDetailsBody extends ConsumerWidget {
  final TvShow show;
  const _TvDetailsBody({required this.show});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedSeason = ref.watch(selectedSeasonProvider(show.id));

    return CustomScrollView(
      slivers: [
        _Backdrop(imageUrl: show.backdropUrl),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(show.name, style: Theme.of(context).textTheme.displayLarge),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: AppColors.gold, size: 20),
                    const SizedBox(width: 4),
                    Text(show.voteAverage.toStringAsFixed(1),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 16),
                    Text(show.firstAirYear, style: const TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(width: 16),
                    Text('${show.numberOfSeasons} Season${show.numberOfSeasons == 1 ? '' : 's'}',
                        style: const TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
                const SizedBox(height: 20),
                Text('Synopsis', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  show.overview.isEmpty ? 'No synopsis available.' : show.overview,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (show.cast.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text('Cast', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  _CastRow(cast: show.cast),
                ],
                if (show.seasons.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  Text('Seasons', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  _SeasonChipSelector(show: show, selectedSeason: selectedSeason),
                  const SizedBox(height: 20),
                  Text('Episodes', style: Theme.of(context).textTheme.titleMedium),
                ],
              ],
            ),
          ),
        ),
        if (show.seasons.isNotEmpty)
          _EpisodeListSliver(show: show, seasonNumber: selectedSeason),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }
}

/// Horizontal chip selector for seasons (Season 1, Season 2, ...).
class _SeasonChipSelector extends ConsumerWidget {
  final TvShow show;
  final int selectedSeason;
  const _SeasonChipSelector({required this.show, required this.selectedSeason});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: show.seasons.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final season = show.seasons[index];
          final isSelected = season.seasonNumber == selectedSeason;
          return GestureDetector(
            onTap: () =>
                ref.read(selectedSeasonProvider(show.id).notifier).state = season.seasonNumber,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.crimson : AppColors.charcoalElevated,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: isSelected ? AppColors.crimson : Colors.white12),
              ),
              alignment: Alignment.center,
              child: Text(
                season.name.isNotEmpty ? season.name : 'Season ${season.seasonNumber}',
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EpisodeListSliver extends ConsumerWidget {
  final TvShow show;
  final int seasonNumber;
  const _EpisodeListSliver({required this.show, required this.seasonNumber});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seasonAsync = ref.watch(seasonDetailProvider((tvId: show.id, season: seasonNumber)));

    return seasonAsync.when(
      loading: () => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator(color: AppColors.crimson)),
        ),
      ),
      error: (e, _) => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('Failed to load episodes.', style: TextStyle(color: AppColors.textSecondary)),
        ),
      ),
      data: (season) => SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _EpisodeTile(show: show, episode: season.episodes[index]),
          childCount: season.episodes.length,
        ),
      ),
    );
  }
}

class _EpisodeTile extends StatelessWidget {
  final TvShow show;
  final Episode episode;
  const _EpisodeTile({required this.show, required this.episode});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlayerScreen.forEpisode(show: show, episode: episode),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: episode.stillUrl.isEmpty
                      ? Container(
                          width: 130,
                          height: 74,
                          color: AppColors.charcoalElevated,
                          child: const Icon(Icons.tv_rounded, color: AppColors.textMuted),
                        )
                      : CachedNetworkImage(
                          imageUrl: episode.stillUrl,
                          width: 130,
                          height: 74,
                          fit: BoxFit.cover,
                        ),
                ),
                const Icon(Icons.play_circle_fill, color: Colors.white70, size: 32),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${episode.episodeNumber}. ${episode.name}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    episode.overview.isEmpty ? 'No description available.' : episode.overview,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (episode.runtimeMinutes > 0) ...[
                    const SizedBox(height: 4),
                    Text('${episode.runtimeMinutes} min',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================================
// Shared pieces
// =========================================================================

class _Backdrop extends StatelessWidget {
  final String imageUrl;
  const _Backdrop({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 380,
      pinned: true,
      backgroundColor: AppColors.pureBlack,
      leading: const BackButton(color: Colors.white),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(color: AppColors.charcoalElevated),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppColors.pureBlack.withOpacity(0.6),
                    AppColors.pureBlack,
                  ],
                  stops: const [0.3, 0.75, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CastRow extends StatelessWidget {
  final List<CastMember> cast;
  const _CastRow({required this.cast});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cast.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final actor = cast[index];
          return SizedBox(
            width: 72,
            child: Column(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppColors.charcoalElevated,
                  backgroundImage:
                      actor.profileUrl.isNotEmpty ? CachedNetworkImageProvider(actor.profileUrl) : null,
                  child: actor.profileUrl.isEmpty
                      ? const Icon(Icons.person, color: AppColors.textMuted)
                      : null,
                ),
                const SizedBox(height: 6),
                Text(actor.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    textAlign: TextAlign.center),
              ],
            ),
          );
        },
      ),
    );
  }
}
