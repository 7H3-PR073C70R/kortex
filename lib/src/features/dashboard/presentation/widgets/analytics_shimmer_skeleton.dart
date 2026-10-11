import 'package:flutter/material.dart';
import 'package:kortex/src/shared/widgets/shimmer_placeholder.dart';

/// Shimmer Skeleton Loader matching Analytics Page layout.
class AnalyticsShimmerSkeleton extends StatelessWidget {
  const AnalyticsShimmerSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 60),
      children: const [
        // Tab bar shimmer
        ShimmerPlaceholder(height: 42, borderRadius: 21),
        SizedBox(height: 18),

        // 2x2 KPI Cards Shimmer
        Row(
          children: [
            Expanded(child: ShimmerPlaceholder(height: 120, borderRadius: 18)),
            SizedBox(width: 12),
            Expanded(child: ShimmerPlaceholder(height: 120, borderRadius: 18)),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: ShimmerPlaceholder(height: 120, borderRadius: 18)),
            SizedBox(width: 12),
            Expanded(child: ShimmerPlaceholder(height: 120, borderRadius: 18)),
          ],
        ),
        SizedBox(height: 20),

        // Chart Shimmer
        ShimmerPlaceholder(height: 260, borderRadius: 22),
        SizedBox(height: 20),

        // Velocity Chart Shimmer
        ShimmerPlaceholder(height: 180, borderRadius: 22),
        SizedBox(height: 20),

        // Heatmap Shimmer
        ShimmerPlaceholder(height: 200, borderRadius: 22),
      ],
    );
  }
}
