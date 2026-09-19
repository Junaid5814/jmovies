import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/media_item.dart';
import '../../providers/movie_providers.dart';
import '../../widgets/media_carousel.dart';
import '../../widgets/media_section_row.dart';
import '../../widgets/top_10_row.dart';
import '../search/search_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(homeModeProvider);

    return Scaffold(
      backgroundColor: AppColors.pureBlack,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            const SizedBox(height: 14),
            const _ModePillSwitcher(),
            const SizedBox(height: 4),
            Expanded(
              child: IndexedStack(
                index: mode.index,
                children: const [
                  _MoviesFeed(),
                  _SeriesFeed(),
                  _AnimeFeed(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              SvgPicture.asset('assets/icons/jmovies_logo.svg', height: 30),
              const SizedBox(width: 10),
              Text('Jmovies',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 22)),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded, color: Colors.white, size: 26),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SearchScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

/// Top 3-mode pill switcher: Movies / Series & Dramas / Anime.
/// Switching modes only updates [homeModeProvider] — the [IndexedStack]
/// above keeps all three feeds alive, so changing tabs never reloads the
/// scaffold or re-fetches data that's already loaded.
class _ModePillSwitcher extends ConsumerWidget {
  const _ModePillSwitcher();

  static const _pills = [
    (mode: HomeMode.movies, label: '🎬 Movies'),
    (mode: HomeMode.series, label: '📺 Series & Dramas'),
    (mode: HomeMode.anime, label: '⚡ Anime'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(homeModeProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: _pills.map((pill) {
          final isActive = mode == pill.mode;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GestureDetector(
                onTap: () => ref.read(homeModeProvider.notifier).state = pill.mode,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.crimson : AppColors.charcoalElevated,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: AppColors.crimson.withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 250),
                    style: TextStyle(
                      color: isActive ? Colors.white : AppColors.textSecondary,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                      fontSize: 12,
                    ),
                    child: Text(
                      pill.label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// =========================================================================
// Movies tab: Now in Cinemas, Top 10 Movies Today, Bollywood Blockbusters,
// Hollywood Action Hits.
// =========================================================================

class _MoviesFeed extends ConsumerWidget {
  const _MoviesFeed();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hero = ref.watch(moviesHeroProvider);
    final nowPlaying = ref.watch(nowPlayingInCinemaProvider);
    final top10 = ref.watch(top10MoviesTodayProvider);
    final bollywood = ref.watch(bollywoodHitsProvider);
    final action = ref.watch(hollywoodActionHitsProvider);

    return RefreshIndicator(
      color: AppColors.crimson,
      backgroundColor: AppColors.charcoal,
      onRefresh: () async {
        ref.invalidate(moviesHeroProvider);
        ref.invalidate(nowPlayingInCinemaProvider);
        ref.invalidate(top10MoviesTodayProvider);
        ref.invalidate(bollywoodHitsProvider);
        ref.invalidate(hollywoodActionHitsProvider);
      },
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: hero.when(
              data: (items) => MediaHeroCarousel(items: items),
              loading: () => const SizedBox(
                height: 460,
                child: Center(child: CircularProgressIndicator(color: AppColors.crimson)),
              ),
              error: (e, _) => _ErrorBanner(message: e.toString()),
            ),
          ),
          SliverToBoxAdapter(
            child: nowPlaying.when(
              data: (movies) => MediaSectionRow(
                title: 'Now in Cinemas',
                items: MediaItem.fromMovies(movies),
              ),
              loading: () => const MediaSectionRow(title: 'Now in Cinemas', items: [], isLoading: true),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
          SliverToBoxAdapter(
            child: top10.when(
              data: (movies) =>
                  Top10Row(title: 'Top 10 Movies Today', items: MediaItem.fromMovies(movies)),
              loading: () => const Top10Row(title: 'Top 10 Movies Today', items: [], isLoading: true),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
          SliverToBoxAdapter(
            child: bollywood.when(
              data: (movies) => MediaSectionRow(
                title: 'Bollywood Blockbusters',
                items: MediaItem.fromMovies(movies),
                badge: 'Hindi',
              ),
              loading: () =>
                  const MediaSectionRow(title: 'Bollywood Blockbusters', items: [], isLoading: true),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
          SliverToBoxAdapter(
            child: action.when(
              data: (movies) => MediaSectionRow(
                title: 'Hollywood Action Hits',
                items: MediaItem.fromMovies(movies),
              ),
              loading: () =>
                  const MediaSectionRow(title: 'Hollywood Action Hits', items: [], isLoading: true),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

// =========================================================================
// Series tab: Top 10 Global Series, Pakistani Dramas, Netflix Originals,
// Turkish Dramas, Amazon Prime Video, K-Dramas, HBO Max, Hotstar.
// =========================================================================

class _SeriesFeed extends ConsumerWidget {
  const _SeriesFeed();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hero = ref.watch(seriesHeroProvider);
    final top10 = ref.watch(top10SeriesTodayProvider);
    final pakistani = ref.watch(pakistaniDramasProvider);
    final netflix = ref.watch(netflixOriginalsProvider);
    final turkish = ref.watch(turkishDramasProvider);
    final prime = ref.watch(primeVideoProvider);
    final kdrama = ref.watch(kDramaProvider);
    final hboMax = ref.watch(hboMaxProvider);
    final hotstar = ref.watch(disneyHotstarProvider);

    return RefreshIndicator(
      color: AppColors.crimson,
      backgroundColor: AppColors.charcoal,
      onRefresh: () async {
        ref.invalidate(seriesHeroProvider);
        ref.invalidate(top10SeriesTodayProvider);
        ref.invalidate(pakistaniDramasProvider);
        ref.invalidate(netflixOriginalsProvider);
        ref.invalidate(turkishDramasProvider);
        ref.invalidate(primeVideoProvider);
        ref.invalidate(kDramaProvider);
        ref.invalidate(hboMaxProvider);
        ref.invalidate(disneyHotstarProvider);
      },
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: hero.when(
              data: (items) => MediaHeroCarousel(items: items),
              loading: () => const SizedBox(
                height: 460,
                child: Center(child: CircularProgressIndicator(color: AppColors.crimson)),
              ),
              error: (e, _) => _ErrorBanner(message: e.toString()),
            ),
          ),
          SliverToBoxAdapter(
            child: top10.when(
              data: (shows) =>
                  Top10Row(title: 'Top 10 Global Series', items: MediaItem.fromTvShows(shows)),
              loading: () => const Top10Row(title: 'Top 10 Global Series', items: [], isLoading: true),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
          SliverToBoxAdapter(
            child: pakistani.when(
              data: (shows) => MediaSectionRow(
                title: 'Pakistani Dramas',
                items: MediaItem.fromTvShows(shows),
                badge: 'Urdu',
              ),
              loading: () => const MediaSectionRow(title: 'Pakistani Dramas', items: [], isLoading: true),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
          SliverToBoxAdapter(
            child: netflix.when(
              data: (shows) => MediaSectionRow(
                title: 'Netflix Originals',
                items: MediaItem.fromTvShows(shows),
                badge: 'N',
                badgeColor: Colors.red.shade900,
              ),
              loading: () => const MediaSectionRow(title: 'Netflix Originals', items: [], isLoading: true),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
          SliverToBoxAdapter(
            child: turkish.when(
              data: (shows) => MediaSectionRow(
                title: 'Turkish Dramas',
                items: MediaItem.fromTvShows(shows),
              ),
              loading: () => const MediaSectionRow(title: 'Turkish Dramas', items: [], isLoading: true),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
          SliverToBoxAdapter(
            child: prime.when(
              data: (shows) => MediaSectionRow(
                title: 'Amazon Prime Video',
                items: MediaItem.fromTvShows(shows),
                badge: 'Prime',
                badgeColor: const Color(0xFF00A8E1),
              ),
              loading: () =>
                  const MediaSectionRow(title: 'Amazon Prime Video', items: [], isLoading: true),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
          SliverToBoxAdapter(
            child: kdrama.when(
              data: (shows) => MediaSectionRow(title: 'K-Dramas', items: MediaItem.fromTvShows(shows)),
              loading: () => const MediaSectionRow(title: 'K-Dramas', items: [], isLoading: true),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
          SliverToBoxAdapter(
            child: hboMax.when(
              data: (shows) => MediaSectionRow(title: 'HBO Max', items: MediaItem.fromTvShows(shows)),
              loading: () => const MediaSectionRow(title: 'HBO Max', items: [], isLoading: true),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
          SliverToBoxAdapter(
            child: hotstar.when(
              data: (shows) => MediaSectionRow(title: 'Hotstar', items: MediaItem.fromTvShows(shows)),
              loading: () => const MediaSectionRow(title: 'Hotstar', items: [], isLoading: true),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

// =========================================================================
// Anime tab: Trending Anime This Season, Top Anime Movies.
// =========================================================================

class _AnimeFeed extends ConsumerWidget {
  const _AnimeFeed();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hero = ref.watch(animeHeroProvider);
    final trendingAnime = ref.watch(trendingAnimeProvider);
    final animeMovies = ref.watch(animeMoviesProvider);

    return RefreshIndicator(
      color: AppColors.crimson,
      backgroundColor: AppColors.charcoal,
      onRefresh: () async {
        ref.invalidate(animeHeroProvider);
        ref.invalidate(trendingAnimeProvider);
        ref.invalidate(animeMoviesProvider);
      },
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: hero.when(
              data: (items) => MediaHeroCarousel(items: items),
              loading: () => const SizedBox(
                height: 460,
                child: Center(child: CircularProgressIndicator(color: AppColors.crimson)),
              ),
              error: (e, _) => _ErrorBanner(message: e.toString()),
            ),
          ),
          SliverToBoxAdapter(
            child: trendingAnime.when(
              data: (shows) => MediaSectionRow(
                title: 'Trending Anime This Season',
                items: MediaItem.fromTvShows(shows),
                badge: 'Viral',
                badgeColor: Colors.deepPurple,
              ),
              loading: () =>
                  const MediaSectionRow(title: 'Trending Anime This Season', items: [], isLoading: true),
              error: (e, _) => _ErrorBanner(message: e.toString()),
            ),
          ),
          SliverToBoxAdapter(
            child: animeMovies.when(
              data: (movies) =>
                  MediaSectionRow(title: 'Top Anime Movies', items: MediaItem.fromMovies(movies)),
              loading: () => const MediaSectionRow(title: 'Top Anime Movies', items: [], isLoading: true),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Text(
        'Could not load content.\n$message',
        style: const TextStyle(color: AppColors.textSecondary),
      ),
    );
  }
}
