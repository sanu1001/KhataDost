import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../theme/app_theme.dart';

/// Shared skeleton bodies — wrap in (or already wrapped by) [Skeletonizer].
///
/// Usage on any list page:
///   if (state.isLoading) return const SkeletonTileList();
///
/// [SkeletonTileList] ships its own Skeletonizer so call-sites stay 1-line.
class SkeletonTileList extends StatelessWidget {
  const SkeletonTileList({
    super.key,
    this.count = 7,
    this.hasLeading = true,
    this.hasTrailing = true,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 16),
  });

  final int count;
  final bool hasLeading;
  final bool hasTrailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      effect: const ShimmerEffect(
        baseColor: AppColors.surfaceVariant,
        highlightColor: AppColors.cardBg,
      ),
      child: ListView.separated(
        padding: padding,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, __) => SkeletonTile(
          hasLeading: hasLeading,
          hasTrailing: hasTrailing,
        ),
      ),
    );
  }
}

/// One fake row shaped like the app's standard card tile.
class SkeletonTile extends StatelessWidget {
  const SkeletonTile({
    super.key,
    this.hasLeading = true,
    this.hasTrailing = true,
  });

  final bool hasLeading;
  final bool hasTrailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          if (hasLeading) ...[
            const Bone.circle(size: 44),
            const SizedBox(width: 12),
          ],
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Bone.text(words: 2, fontSize: 14),
                SizedBox(height: 6),
                Bone.text(words: 3, fontSize: 11),
              ],
            ),
          ),
          if (hasTrailing) ...[
            const SizedBox(width: 12),
            const Bone.text(words: 1, fontSize: 14),
          ],
        ],
      ),
    );
  }
}

/// Skeleton for the dashboard-style hero stat card.
class SkeletonStatCard extends StatelessWidget {
  const SkeletonStatCard({super.key, this.height = 110});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      effect: const ShimmerEffect(
        baseColor: AppColors.surfaceVariant,
        highlightColor: AppColors.cardBg,
      ),
      child: Container(
        height: height,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.divider),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Bone.text(words: 2, fontSize: 12),
            SizedBox(height: 10),
            Bone.text(words: 1, fontSize: 26),
          ],
        ),
      ),
    );
  }
}
