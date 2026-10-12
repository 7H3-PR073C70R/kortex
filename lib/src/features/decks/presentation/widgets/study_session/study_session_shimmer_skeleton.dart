import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/shared/widgets/shimmer_placeholder.dart';

/// Shimmer loading skeleton displayed while a flashcard study session loads.
class StudySessionShimmerSkeleton extends StatelessWidget {
  const StudySessionShimmerSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: Column(
        children: [
          // Progress Top Bar Skeleton
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ShimmerPlaceholder(height: 36, width: 36, borderRadius: 18),
              ShimmerPlaceholder(height: 16, width: 80, borderRadius: 8),
              ShimmerPlaceholder(height: 36, width: 36, borderRadius: 18),
            ],
          ),
          const SizedBox(height: 20),

          // Main Flashcard Skeleton
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark
                    ? colors.surfaceSecondary.withAlpha(160)
                    : colors.surfacePrimary.withAlpha(220),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: colors.surfaceBorder.withAlpha(100),
                ),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ShimmerPlaceholder(
                        height: 22,
                        width: 100,
                        borderRadius: 8,
                      ),
                      ShimmerPlaceholder(
                        height: 16,
                        width: 70,
                        borderRadius: 6,
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      ShimmerPlaceholder(
                        height: 22,
                        width: 260,
                        borderRadius: 8,
                      ),
                      SizedBox(height: 12),
                      ShimmerPlaceholder(
                        height: 18,
                        width: 200,
                        borderRadius: 8,
                      ),
                      SizedBox(height: 24),
                      ShimmerPlaceholder(
                        height: 60,
                        width: 240,
                        borderRadius: 14,
                      ),
                    ],
                  ),
                  ShimmerPlaceholder(
                    height: 14,
                    width: 180,
                    borderRadius: 6,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Bottom Bar Skeleton
          const ShimmerPlaceholder(
            height: 52,
            width: double.infinity,
            borderRadius: 16,
          ),
        ],
      ),
    );
  }
}
