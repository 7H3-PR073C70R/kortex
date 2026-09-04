import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/shared/widgets/shimmer_placeholder.dart';

/// Shimmer skeleton that precisely mirrors the layout and card shapes
/// of the Community & Study Hub tabs (Live Rooms, Forum, Deck Market, Leaderboard).
class CommunityHubShimmer extends StatelessWidget {
  const CommunityHubShimmer({
    this.tabIndex = 0,
    super.key,
  });

  final int tabIndex;

  @override
  Widget build(BuildContext context) {
    switch (tabIndex) {
      case 0:
        return const _LiveRoomsShimmer();
      case 1:
        return const _TrackForumShimmer();
      case 2:
        return const _DeckMarketShimmer();
      case 3:
        return const _LeaderboardShimmer();
      default:
        return const _LiveRoomsShimmer();
    }
  }
}

class _LiveRoomsShimmer extends StatelessWidget {
  const _LiveRoomsShimmer();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colors.primary.withAlpha(isDark ? 30 : 20),
            ),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Category badge + Live indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ShimmerPlaceholder(width: 72, height: 24, borderRadius: 8),
                  ShimmerPlaceholder(width: 86, height: 18, borderRadius: 6),
                ],
              ),
              SizedBox(height: 14),

              // Title & Subject
              ShimmerPlaceholder(
                width: 240,
                height: 20,
                borderRadius: 6,
              ),
              SizedBox(height: 8),
              ShimmerPlaceholder(
                width: 140,
                height: 14,
                borderRadius: 4,
              ),
              SizedBox(height: 18),

              // Bottom Row: Active peers count + Join Focus Room button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ShimmerPlaceholder(width: 100, height: 16, borderRadius: 4),
                  ShimmerPlaceholder(width: 130, height: 38, borderRadius: 12),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TrackForumShimmer extends StatelessWidget {
  const _TrackForumShimmer();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colors.primary.withAlpha(isDark ? 30 : 20),
            ),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Track chip + Author
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ShimmerPlaceholder(width: 68, height: 22, borderRadius: 8),
                  ShimmerPlaceholder(width: 90, height: 14, borderRadius: 4),
                ],
              ),
              SizedBox(height: 14),

              // Title
              ShimmerPlaceholder(
                width: 220,
                height: 20,
                borderRadius: 6,
              ),
              SizedBox(height: 8),

              // Content lines
              ShimmerPlaceholder(
                width: double.infinity,
                height: 14,
                borderRadius: 4,
              ),
              SizedBox(height: 6),
              ShimmerPlaceholder(
                width: 200,
                height: 14,
                borderRadius: 4,
              ),
              SizedBox(height: 16),

              // Footer: Upvotes and Replies chips
              Row(
                children: [
                  ShimmerPlaceholder(width: 54, height: 28, borderRadius: 8),
                  SizedBox(width: 12),
                  ShimmerPlaceholder(width: 54, height: 28, borderRadius: 8),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DeckMarketShimmer extends StatelessWidget {
  const _DeckMarketShimmer();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colors.primary.withAlpha(isDark ? 30 : 20),
            ),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category tag + Rating
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ShimmerPlaceholder(width: 80, height: 22, borderRadius: 8),
                  ShimmerPlaceholder(width: 48, height: 16, borderRadius: 4),
                ],
              ),
              SizedBox(height: 12),

              // Title
              ShimmerPlaceholder(
                width: 210,
                height: 20,
                borderRadius: 6,
              ),
              SizedBox(height: 8),

              // Description line
              ShimmerPlaceholder(
                width: double.infinity,
                height: 14,
                borderRadius: 4,
              ),
              SizedBox(height: 16),

              // Bottom Row: Cards & Downloads info + Clone button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ShimmerPlaceholder(width: 120, height: 16, borderRadius: 4),
                  ShimmerPlaceholder(width: 110, height: 36, borderRadius: 12),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LeaderboardShimmer extends StatelessWidget {
  const _LeaderboardShimmer();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Podium (Top 3) skeleton
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: colors.primary.withAlpha(isDark ? 40 : 25),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Rank 2
                Column(
                  children: [
                    ShimmerPlaceholder(
                      width: 50,
                      height: 50,
                      borderRadius: 25,
                    ),
                    SizedBox(height: 8),
                    ShimmerPlaceholder(
                      width: 56,
                      height: 14,
                      borderRadius: 4,
                    ),
                    SizedBox(height: 6),
                    ShimmerPlaceholder(
                      width: 64,
                      height: 60,
                      borderRadius: 12,
                    ),
                  ],
                ),
                // Rank 1
                Column(
                  children: [
                    ShimmerPlaceholder(
                      width: 60,
                      height: 60,
                      borderRadius: 30,
                    ),
                    SizedBox(height: 8),
                    ShimmerPlaceholder(
                      width: 64,
                      height: 14,
                      borderRadius: 4,
                    ),
                    SizedBox(height: 6),
                    ShimmerPlaceholder(
                      width: 72,
                      height: 85,
                      borderRadius: 12,
                    ),
                  ],
                ),
                // Rank 3
                Column(
                  children: [
                    ShimmerPlaceholder(
                      width: 46,
                      height: 46,
                      borderRadius: 23,
                    ),
                    SizedBox(height: 8),
                    ShimmerPlaceholder(
                      width: 52,
                      height: 14,
                      borderRadius: 4,
                    ),
                    SizedBox(height: 6),
                    ShimmerPlaceholder(
                      width: 60,
                      height: 48,
                      borderRadius: 12,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Ranking Rows
          ...List.generate(4, (index) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colors.primary.withAlpha(isDark ? 25 : 15),
                ),
              ),
              child: const Row(
                children: [
                  ShimmerPlaceholder(width: 24, height: 18, borderRadius: 4),
                  SizedBox(width: 14),
                  ShimmerPlaceholder(width: 38, height: 38, borderRadius: 19),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerPlaceholder(
                          width: 120,
                          height: 16,
                          borderRadius: 4,
                        ),
                        SizedBox(height: 6),
                        ShimmerPlaceholder(
                          width: 70,
                          height: 12,
                          borderRadius: 3,
                        ),
                      ],
                    ),
                  ),
                  ShimmerPlaceholder(width: 60, height: 22, borderRadius: 8),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
