import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../core/theme/app_theme.dart';
import '../data/models/media_item.dart';
import 'media_nav.dart';

/// Standard horizontal section row: category title, poster cards with an
/// optional corner badge (e.g. 'Hindi', 'Urdu', 'N', 'Viral'), a rating
/// pill, and the release/air year.
class MediaSectionRow extends StatelessWidget {
  final String title;
  final List<MediaItem> items;
  final bool isLoading;
  final String? badge;
  final Color? badgeColor;

  const MediaSectionRow({
    super.key,
    required this.title,
    required this.items,
    this.isLoading = false,
    this.badge,
    this.badgeColor,
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
          height: 248,
          child: isLoading
              ? _buildShimmerRow()
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (context, index) => _BadgedPosterCard(
                    item: items[index],
                    badge: badge,
                    badgeColor: badgeColor ?? AppColors.crimson,
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

class _BadgedPosterCard extends StatelessWidget {
  final MediaItem item;
  final String? badge;
  final Color badgeColor;

  const _BadgedPosterCard({
    required this.item,
    required this.badge,
    required this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => openMediaDetails(context, item),
      child: SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
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
                if (badge != null)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badge!,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded, color: AppColors.gold, size: 12),
                        const SizedBox(width: 2),
                        Text(item.formattedRating,
                            style: const TextStyle(color: Colors.white, fontSize: 10)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              item.year,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
