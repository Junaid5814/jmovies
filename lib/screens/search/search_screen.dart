import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/movie_providers.dart';
import '../../widgets/genre_chip.dart';
import '../../widgets/media_nav.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;

  static const _debounceDelay = Duration(milliseconds: 400);

  static const _filters = [
    (filter: SearchFilter.all, label: 'All'),
    (filter: SearchFilter.movies, label: 'Movies'),
    (filter: SearchFilter.tvSeries, label: 'TV Series'),
    (filter: SearchFilter.anime, label: 'Anime'),
    (filter: SearchFilter.dramas, label: 'Dramas'),
  ];

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, () {
      ref.read(searchQueryProvider.notifier).state = value.trim();
    });
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(filteredSearchResultsProvider);
    final activeFilter = ref.watch(searchFilterProvider);
    final hasQuery = ref.watch(searchQueryProvider).isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.pureBlack,
      appBar: AppBar(
        leading: const BackButton(color: Colors.white),
        title: Text('Search', style: Theme.of(context).textTheme.headlineMedium),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search movies, series, anime…',
                hintStyle: const TextStyle(color: AppColors.textMuted),
                prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.charcoalElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: _onQueryChanged,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final entry = _filters[index];
                return GenreChip(
                  label: entry.label,
                  selected: activeFilter == entry.filter,
                  onTap: () => ref.read(searchFilterProvider.notifier).state = entry.filter,
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: !hasQuery
                ? const Center(
                    child: Text('Start typing to search',
                        style: TextStyle(color: AppColors.textMuted)),
                  )
                : resultsAsync.when(
                    data: (items) {
                      if (items.isEmpty) {
                        return const Center(
                          child: Text('No results for this filter',
                              style: TextStyle(color: AppColors.textMuted)),
                        );
                      }
                      return GridView.builder(
                        padding: const EdgeInsets.all(20),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.6,
                        ),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return GestureDetector(
                            onTap: () => openMediaDetails(context, item),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: item.fullPosterUrl.isEmpty
                                  ? Container(
                                      color: AppColors.charcoalElevated,
                                      child: Icon(
                                        item.isTv ? Icons.tv_rounded : Icons.movie_outlined,
                                        color: AppColors.textMuted,
                                      ),
                                    )
                                  : CachedNetworkImage(
                                      imageUrl: item.fullPosterUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) =>
                                          Container(color: AppColors.charcoalElevated),
                                    ),
                            ),
                          );
                        },
                      );
                    },
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: AppColors.crimson),
                    ),
                    error: (e, _) => const Center(
                      child: Text('Search failed', style: TextStyle(color: AppColors.textSecondary)),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
