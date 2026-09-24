import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';

class LeaderboardShimmerView extends StatelessWidget {
  const LeaderboardShimmerView({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;
    
    final baseColor = isDark ? colors.surfaceSecondary : colors.gray.withAlpha(20);
    final highlightColor = isDark ? colors.surfaceElevated : colors.white;

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero Banner Shimmer
              Container(
                height: 100,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: baseColor,
                  borderRadius: AppRadius.radiusPanel,
                ),
              ),
              
              // Podium Shimmer
              Container(
                height: 180,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: baseColor,
                  borderRadius: AppRadius.radiusPanel,
                ),
              ),
              
              // Rank Cards Shimmer
              for (var i = 0; i < 5; i++)
                Container(
                  height: 72,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: AppRadius.radiusCard,
                  ),
                ),
            ],
          ).animate(onPlay: (controller) => controller.repeat()).shimmer(
                duration: const Duration(milliseconds: 1200),
                color: highlightColor.withAlpha(isDark ? 50 : 100),
              ),
        ),
      ),
    );
  }
}
