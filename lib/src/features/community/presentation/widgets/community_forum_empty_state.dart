import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Clean and engaging empty state display when no discussions match the current query or filter.
class CommunityForumEmptyState extends StatelessWidget {
  const CommunityForumEmptyState({
    required this.searchQuery,
    required this.selectedTrack,
    required this.effectiveTrack,
    required this.onClearSearch,
    required this.onStartDiscussion,
    required this.onExploreAll,
    super.key,
  });

  final String searchQuery;
  final String selectedTrack;
  final String effectiveTrack;
  final VoidCallback onClearSearch;
  final VoidCallback onStartDiscussion;
  final VoidCallback onExploreAll;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final isSearching = searchQuery.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 48,
      ),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.primary.withAlpha(isDark ? 30 : 15),
              ),
              child: Icon(
                isSearching
                    ? Icons.search_off_rounded
                    : Icons.forum_outlined,
                size: 40,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              isSearching
                  ? 'No Matching Discussions'
                  : 'No Discussions Yet',
              style: typography.headline.bold.copyWith(
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isSearching
                  ? 'No threads found for "$searchQuery". Try searching a different keyword or topic tag.'
                  : (selectedTrack == 'All'
                      ? 'No discussions have been posted in the community yet. Be the first to start a conversation!'
                      : 'Be the first scholar in $selectedTrack to ask a question or start a discussion.'),
              textAlign: TextAlign.center,
              style: typography.footnote.regular.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            if (isSearching)
              ShrinkableButton(
                onTap: onClearSearch,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary.withAlpha(isDark ? 40 : 25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: colors.primary.withAlpha(80),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.refresh_rounded,
                        size: 16,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Clear Search',
                        style: typography.caption.bold.copyWith(
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ShrinkableButton(
                    onTap: onStartDiscussion,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: colors.black.withAlpha(
                              isDark ? 50 : 20,
                            ),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add_rounded,
                            size: 18,
                            color: colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Start a Discussion',
                            style: typography.caption.bold.copyWith(
                              color: colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (selectedTrack != 'All') ...[
                    const SizedBox(height: 12),
                    ShrinkableButton(
                      onTap: () {
                        unawaited(HapticFeedback.selectionClick());
                        onExploreAll();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? colors.surfaceSecondary
                              : colors.surfaceSecondary.withAlpha(120),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: colors.surfaceBorder.withAlpha(
                              isDark ? 40 : 25,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.public_rounded,
                              size: 15,
                              color: colors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Explore All Community Discussions',
                              style: typography.caption.medium.copyWith(
                                color: colors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}
