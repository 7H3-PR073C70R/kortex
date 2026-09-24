import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_event.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_hub_bloc.dart';
import 'package:kortex/src/features/community/presentation/widgets/community_filter_bottom_sheet.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Standard top header for the Community Hub displaying title and active filter indicator.
class CommunityStandardHeader extends StatelessWidget {
  const CommunityStandardHeader({
    required this.title,
    required this.selectedTrack,
    required this.selectedForumFilter,
    required this.hasActiveFilters,
    required this.activeFilterCount,
    required this.availableTracks,
    required this.effectiveTrack,
    super.key,
  });

  final String title;
  final String selectedTrack;
  final String selectedForumFilter;
  final bool hasActiveFilters;
  final int activeFilterCount;
  final List<String> availableTracks;
  final String effectiveTrack;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Row(
      key: const ValueKey('standard_header'),
      children: [
        Text(
          title,
          style: typography.title2.bold.copyWith(
            color: colors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        if (hasActiveFilters) ...[
          const SizedBox(width: 8),
          PlatformHoverBuilder(
            builder: (context, isHovered, child) => AnimatedScale(
              scale: isHovered ? 1.05 : 1.0,
              duration: AppMotion.snappy,
              curve: AppMotion.easeOutCubic,
              child: child,
            ),
            child: ShrinkableButton(
              onTap: () {
                unawaited(HapticFeedback.lightImpact());
                showCommunityFilterSheet(
                  context: context,
                  availableTracks: availableTracks,
                  effectiveTrack: effectiveTrack,
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.primary.withAlpha(isDark ? 45 : 25),
                  borderRadius: AppRadius.radiusBadge,
                  border: Border.all(
                    color: colors.primary.withAlpha(isDark ? 90 : 50),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      selectedTrack != 'All'
                          ? Icons.school_rounded
                          : getSortIcon(selectedForumFilter),
                      size: 13,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      selectedTrack != 'All'
                          ? selectedTrack
                          : getSortLabel(selectedForumFilter),
                      style: typography.caption.bold.copyWith(
                        color: colors.primary,
                        fontSize: 11.5,
                      ),
                    ),
                    if (activeFilterCount > 1) ...[
                      const SizedBox(width: 3),
                      Text(
                        '+${activeFilterCount - 1}',
                        style: typography.caption.bold.copyWith(
                          color: colors.primary,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Expanded search header for the Community Hub allowing live discussion search and filter shortcut.
class CommunitySearchHeader extends StatelessWidget {
  const CommunitySearchHeader({
    required this.searchController,
    required this.searchQuery,
    required this.debounceTimer,
    required this.isSearchExpanded,
    required this.availableTracks,
    required this.effectiveTrack,
    required this.hasActiveFilters,
    required this.activeFilterCount,
    super.key,
  });

  final TextEditingController searchController;
  final ValueNotifier<String> searchQuery;
  final ObjectRef<Timer?> debounceTimer;
  final ValueNotifier<bool> isSearchExpanded;
  final List<String> availableTracks;
  final String effectiveTrack;
  final bool hasActiveFilters;
  final int activeFilterCount;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Row(
      key: const ValueKey('search_header'),
      children: [
        Expanded(
          child: Container(
            height: 38,
            decoration: BoxDecoration(
              color: isDark
                  ? colors.surfaceSecondary
                  : colors.surfaceSecondary.withAlpha(160),
              borderRadius: AppRadius.radiusSheet,
              border: Border.all(
                color: colors.primary.withAlpha(isDark ? 90 : 60),
                width: 1.2,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: colors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: searchController,
                    autofocus: true,
                    style: typography.subhead.medium.copyWith(
                      color: colors.textPrimary,
                      fontSize: 13.5,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search discussions, topics, tags...',
                      hintStyle: typography.footnote.regular.copyWith(
                        color: colors.textSecondary.withAlpha(160),
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                      errorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (val) {
                      searchQuery.value = val;
                      debounceTimer.value?.cancel();
                      debounceTimer.value =
                          Timer(const Duration(milliseconds: 350), () {
                        context.read<CommunityHubBloc>().add(
                              SearchForumPostsEvent(val.trim()),
                            );
                      });
                    },
                  ),
                ),
                if (searchQuery.value.isNotEmpty)
                  ShrinkableButton(
                    onTap: () {
                      unawaited(HapticFeedback.selectionClick());
                      searchController.clear();
                      searchQuery.value = '';
                      context.read<CommunityHubBloc>().add(
                            const SearchForumPostsEvent(''),
                          );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.close_rounded,
                        size: 15,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ShrinkableButton(
                  onTap: () {
                    unawaited(HapticFeedback.lightImpact());
                    showCommunityFilterSheet(
                      context: context,
                      availableTracks: availableTracks,
                      effectiveTrack: effectiveTrack,
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          Icons.tune_rounded,
                          size: 16,
                          color: hasActiveFilters
                              ? colors.primary
                              : colors.textSecondary,
                        ),
                        if (hasActiveFilters && activeFilterCount > 0)
                          Positioned(
                            top: -2,
                            right: -2,
                            child: Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: colors.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        ShrinkableButton(
          onTap: () {
            unawaited(HapticFeedback.lightImpact());
            searchController.clear();
            searchQuery.value = '';
            context.read<CommunityHubBloc>().add(
                  const SearchForumPostsEvent(''),
                );
            isSearchExpanded.value = false;
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Text(
              'Cancel',
              style: typography.subhead.bold.copyWith(
                color: colors.primary,
                fontSize: 13.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
