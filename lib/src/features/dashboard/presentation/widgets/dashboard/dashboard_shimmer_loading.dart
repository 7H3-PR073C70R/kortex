import 'package:flutter/material.dart';
import 'package:kortex/src/shared/widgets/shimmer_placeholder.dart';

class DashboardShimmerLoading extends StatelessWidget {
  const DashboardShimmerLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: [
        // 1. Header Profile Skeleton
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                ShimmerPlaceholder(
                  height: 46,
                  width: 46,
                  borderRadius: 23,
                ),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerPlaceholder(
                      height: 18,
                      width: 120,
                      borderRadius: 6,
                    ),
                    SizedBox(height: 6),
                    ShimmerPlaceholder(
                      height: 12,
                      width: 80,
                      borderRadius: 4,
                    ),
                  ],
                ),
              ],
            ),
            Row(
              children: [
                ShimmerPlaceholder(
                  height: 32,
                  width: 56,
                  borderRadius: 16,
                ),
                SizedBox(width: 8),
                ShimmerPlaceholder(
                  height: 38,
                  width: 38,
                  borderRadius: 19,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),

        // 2. Exam Countdown Banner Skeleton
        const ShimmerPlaceholder(height: 72, borderRadius: 18),
        const SizedBox(height: 20),

        // 3. Next Best Action Skeleton
        const ShimmerPlaceholder(height: 130, borderRadius: 22),
        const SizedBox(height: 20),

        // 4. Hero Deck Skeleton
        const ShimmerPlaceholder(height: 180, borderRadius: 22),
        const SizedBox(height: 20),

        // 5. Curated Courses Skeleton
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ShimmerPlaceholder(height: 18, width: 140, borderRadius: 6),
            ShimmerPlaceholder(height: 14, width: 60, borderRadius: 6),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 155,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 2,
            separatorBuilder: (_, index) => const SizedBox(width: 14),
            itemBuilder: (_, index) => const ShimmerPlaceholder(
              width: 220,
              height: 155,
              borderRadius: 18,
            ),
          ),
        ),
        const SizedBox(height: 20),

        // 6. Quick Actions Speed Dial Skeleton
        const ShimmerPlaceholder(height: 48, borderRadius: 22),
        const SizedBox(height: 20),

        // 7. Pod Pulse / Study Circle Skeleton
        const ShimmerPlaceholder(height: 168, borderRadius: 18),
        const SizedBox(height: 20),

        // 8. CBT Readiness Gauge Skeleton — matches widget height of ~200px
        const ShimmerPlaceholder(height: 200, borderRadius: 18),
        const SizedBox(height: 20),

        // 9. Retention Heatmap + Study Matrix Skeleton — full widget height
        const ShimmerPlaceholder(height: 260, borderRadius: 18),
      ],
    );
  }
}
