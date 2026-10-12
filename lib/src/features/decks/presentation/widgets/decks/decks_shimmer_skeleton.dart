import 'package:flutter/material.dart';
import 'package:kortex/src/shared/widgets/shimmer_placeholder.dart';

/// Responsive shimmer skeleton for the decks page loading state.
class DecksShimmerSkeleton extends StatelessWidget {
  const DecksShimmerSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
      children: [
        // 1. Header Shimmer
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerPlaceholder(width: 140, height: 26, borderRadius: 8),
                SizedBox(height: 6),
                ShimmerPlaceholder(width: 220, height: 14, borderRadius: 6),
              ],
            ),
            ShimmerPlaceholder(width: 40, height: 40, borderRadius: 20),
          ],
        ),
        const SizedBox(height: 20),

        // 2. Today Hero Shimmer
        const ShimmerPlaceholder(
          width: double.infinity,
          height: 132,
          borderRadius: 16,
        ),
        const SizedBox(height: 16),

        // 3. Search Bar Shimmer
        const ShimmerPlaceholder(
          width: double.infinity,
          height: 48,
          borderRadius: 16,
        ),
        const SizedBox(height: 16),

        // 4. Filter Category Pills Shimmer
        const SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: NeverScrollableScrollPhysics(),
          child: Row(
            children: [
              ShimmerPlaceholder(width: 80, height: 32, borderRadius: 16),
              SizedBox(width: 8),
              ShimmerPlaceholder(width: 95, height: 32, borderRadius: 16),
              SizedBox(width: 8),
              ShimmerPlaceholder(width: 85, height: 32, borderRadius: 16),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 5. Responsive Deck Card Skeletons (matches loaded grid breakpoints)
        LayoutBuilder(
          builder: (context, gridConstraints) {
            final columnCount = switch (gridConstraints.maxWidth) {
              >= 1400 => 4,
              >= 900 => 3,
              >= 640 => 2,
              _ => 1,
            };

            if (columnCount > 1) {
              final itemWidth =
                  (gridConstraints.maxWidth - (14 * (columnCount - 1))) /
                  columnCount;
              final skeletonCount = columnCount * 2;
              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  for (var i = 0; i < skeletonCount; i++)
                    SizedBox(
                      width: itemWidth,
                      child: const ShimmerPlaceholder(
                        width: double.infinity,
                        height: 120,
                        borderRadius: 20,
                      ),
                    ),
                ],
              );
            }

            return const Column(
              children: [
                Padding(
                  padding: EdgeInsets.only(bottom: 14),
                  child: ShimmerPlaceholder(
                    width: double.infinity,
                    height: 120,
                    borderRadius: 20,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(bottom: 14),
                  child: ShimmerPlaceholder(
                    width: double.infinity,
                    height: 120,
                    borderRadius: 20,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(bottom: 14),
                  child: ShimmerPlaceholder(
                    width: double.infinity,
                    height: 120,
                    borderRadius: 20,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
