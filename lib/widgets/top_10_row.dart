import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../data/models/media_item.dart';
import 'media_nav.dart';

/// Netflix-style horizontal "Top 10" row: each poster sits beside (and
/// slightly overlapped by) a large stroked-outline rank number, 1 through
/// however many items are passed (capped at 10).
class Top10Row extends StatelessWidget {
  final String title;
  final List<MediaItem> items;
  final bool isLoading;

  const Top10Row({
    super.key,
    required this.title,
    required this.items,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!isLoading && items.isEmpty) return const SizedBox.shrink();
    final ranked = items.take(10).toList();

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
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(left: 44, right: 20),
                  itemCount: ranked.length,
                  itemBuilder: (context, index) => _RankedPosterCard(
                    rank: index + 1,
                    item: ranked[index],
                  ),
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
      itemBuilder: (_, __) => Container(
        width: 140,
        decoration: BoxDecoration(
          color: AppColors.charcoalElevated,
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}

class _RankedPosterCard extends StatelessWidget {
  final int rank;
  final MediaItem item;
  const _RankedPosterCard({required this.rank, required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => openMediaDetails(context, item),
      child: SizedBox(
        width: 168,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomLeft,
          children: [
            // Large stroked-outline rank number, layered behind/beside the poster.
            Positioned(
              left: -30,
              bottom: 6,
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: 128,
                  fontWeight: FontWeight.w900,
                  height: 0.8,
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 3
                    ..color = AppColors.textMuted.withOpacity(0.6),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 38),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: CachedNetworkImage(
                      imageUrl: item.fullPosterUrl,
                      height: 180,
                      width: 130,
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
                  SizedBox(
                    width: 130,
                    child: Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
