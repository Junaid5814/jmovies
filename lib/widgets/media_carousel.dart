import 'package:carousel_slider/carousel_slider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../core/theme/app_theme.dart';
import '../data/models/media_item.dart';
import 'media_nav.dart';

class MediaHeroCarousel extends StatefulWidget {
  final List<MediaItem> items;
  const MediaHeroCarousel({super.key, required this.items});

  @override
  State<MediaHeroCarousel> createState() => _MediaHeroCarouselState();
}

class _MediaHeroCarouselState extends State<MediaHeroCarousel> {
  final CarouselSliderController _controller = CarouselSliderController();
  int _current = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    final slides = widget.items.take(6).toList();

    return Column(
      children: [
        CarouselSlider(
          carouselController: _controller,
          items: slides.map((item) {
            return GestureDetector(
              onTap: () => openMediaDetails(context, item),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: CachedNetworkImage(
                      imageUrl: item.fullBackdropUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: AppColors.charcoalElevated),
                      errorWidget: (_, __, ___) => Container(color: AppColors.charcoalElevated),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black87],
                          stops: [0.4, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.isTv)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.crimson,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('SERIES',
                                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                          ),
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.displayLarge,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, color: AppColors.gold, size: 18),
                            const SizedBox(width: 4),
                            Text(item.voteAverage.toStringAsFixed(1),
                                style: const TextStyle(color: Colors.white)),
                            const SizedBox(width: 12),
                            Text(item.year, style: const TextStyle(color: Colors.white70)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          options: CarouselOptions(
            height: 460,
            viewportFraction: 0.88,
            autoPlay: true,
            autoPlayInterval: const Duration(seconds: 6),
            enlargeCenterPage: true,
            onPageChanged: (index, _) => setState(() => _current = index),
          ),
        ),
        const SizedBox(height: 12),
        AnimatedSmoothIndicator(
          activeIndex: _current,
          count: slides.length,
          effect: const ExpandingDotsEffect(
            dotColor: AppColors.textMuted,
            activeDotColor: AppColors.crimson,
            dotHeight: 6,
            dotWidth: 6,
          ),
        ),
      ],
    );
  }
}

class MediaCarousel extends StatelessWidget {
  final String title;
  final List<MediaItem> items;
  final bool isLoading;

  const MediaCarousel({
    super.key,
    required this.title,
    required this.items,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!isLoading && items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Text(title, style: Theme.of(context).textTheme.headlineMedium),
        ),
        SizedBox(
          height: 220,
          child: isLoading
              ? _buildShimmerRow()
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (context, index) => _PosterCard(item: items[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildShimmerRow() {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(width: 14),
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: AppColors.charcoalElevated,
        highlightColor: AppColors.surfaceCard,
        child: Container(
          width: 140,
          decoration: BoxDecoration(
            color: AppColors.charcoalElevated,
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

class _PosterCard extends StatelessWidget {
  final MediaItem item;
  const _PosterCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => openMediaDetails(context, item),
      child: SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: CachedNetworkImage(
                imageUrl: item.fullPosterUrl,
                height: 180,
                width: 140,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: AppColors.charcoalElevated),
                errorWidget: (_, __, ___) => Container(
                  color: AppColors.charcoalElevated,
                  child: Icon(item.isTv ? Icons.tv_rounded : Icons.movie_outlined,
                      color: AppColors.textMuted),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
