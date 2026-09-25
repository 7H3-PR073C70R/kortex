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
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Representation of a quick sort / filter option in the community feed.
class QuickSortItem {
  const QuickSortItem(this.key, this.label, this.icon);

  final String key;
  final String label;
  final IconData icon;
}

const List<QuickSortItem> kQuickSorts = [
  QuickSortItem('knowledge_gap', 'Knowledge Gap', Icons.auto_awesome_rounded),
  QuickSortItem('following', 'Following Topics', Icons.stars_rounded),
  QuickSortItem('trending', 'Trending', Icons.local_fire_department_rounded),
  QuickSortItem('latest', 'Latest', Icons.schedule_rounded),
  QuickSortItem('topToday', 'Top Today', Icons.military_tech_rounded),
  QuickSortItem('questions', 'Questions', Icons.help_outline_rounded),
  QuickSortItem('solved', 'Solved', Icons.check_circle_outline_rounded),
  QuickSortItem('myPosts', 'My Posts', Icons.person_outline_rounded),
  QuickSortItem('saved', 'Saved', Icons.bookmark_outline_rounded),
];

String getSortLabel(String filter) {
  switch (filter.toLowerCase()) {
    case 'knowledge_gap':
    case 'knowledgegap':
      return 'Knowledge Gap';
    case 'following':
      return 'Following Topics';
    case 'trending':
      return 'Trending';
    case 'latest':
      return 'Latest';
    case 'toptoday':
    case 'top_today':
      return 'Top Today';
    case 'questions':
      return 'Questions';
    case 'solved':
      return 'Solved';
    case 'myposts':
    case 'my_posts':
      return 'My Posts';
    case 'saved':
    case 'bookmarks':
      return 'Saved';
    default:
      return filter.isNotEmpty
          ? '${filter[0].toUpperCase()}${filter.substring(1)}'
          : 'Filter';
  }
}

IconData getSortIcon(String filter) {
  switch (filter.toLowerCase()) {
    case 'knowledge_gap':
    case 'knowledgegap':
      return Icons.auto_awesome_rounded;
    case 'following':
      return Icons.stars_rounded;
    case 'trending':
      return Icons.local_fire_department_rounded;
    case 'latest':
      return Icons.schedule_rounded;
    case 'toptoday':
    case 'top_today':
      return Icons.military_tech_rounded;
    case 'questions':
      return Icons.help_outline_rounded;
    case 'solved':
      return Icons.check_circle_outline_rounded;
    case 'myposts':
    case 'my_posts':
      return Icons.person_outline_rounded;
    case 'saved':
    case 'bookmarks':
      return Icons.bookmark_outline_rounded;
    default:
      return Icons.tune_rounded;
  }
}

IconData getTrackIcon(String track) {
  switch (track.toLowerCase()) {
    case 'waec':
      return Icons.school_rounded;
    case 'jamb':
      return Icons.menu_book_rounded;
    case 'mathematics':
      return Icons.calculate_rounded;
    case 'physics':
      return Icons.bolt_rounded;
    case 'chemistry':
      return Icons.science_rounded;
    case 'computer science':
      return Icons.terminal_rounded;
    case 'medicine':
      return Icons.health_and_safety_rounded;
    case 'sat':
      return Icons.edit_note_rounded;
    case 'all':
      return Icons.public_rounded;
    default:
      return Icons.auto_stories_rounded;
  }
}

List<String> getAvailableTracks(String? userTrack) {
  final base = <String>[
    'WAEC',
    'JAMB',
    'Mathematics',
    'Physics',
    'Chemistry',
    'Computer Science',
    'Medicine',
    'SAT',
  ];
  if (userTrack != null &&
      userTrack.trim().isNotEmpty &&
      userTrack != 'General' &&
      !base.contains(userTrack.trim())) {
    base.insert(0, userTrack.trim());
  }
  return base;
}

void showCommunityFilterSheet({
  required BuildContext context,
  required List<String> availableTracks,
  required String effectiveTrack,
}) {
  final bloc = context.read<CommunityHubBloc>();
  unawaited(
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor:
          context.colors.black.withAlpha(context.isDarkMode ? 170 : 110),
      builder: (sheetContext) => BlocProvider.value(
        value: bloc,
        child: CommunityFilterBottomSheet(
          availableTracks: availableTracks,
          effectiveTrack: effectiveTrack,
        ),
      ),
    ),
  );
}

/// Bottom sheet allowing users to filter discussions by academic track and sort order.
class CommunityFilterBottomSheet extends HookWidget {
  const CommunityFilterBottomSheet({
    required this.availableTracks,
    required this.effectiveTrack,
    super.key,
  });

  final List<String> availableTracks;
  final String effectiveTrack;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;
    final bloc = context.read<CommunityHubBloc>();

    final currentSelectedTrack = bloc.state.selectedTrack;
    final currentSelectedSort = bloc.state.selectedForumFilter;

    final tempTrack = useState<String>(currentSelectedTrack);
    final tempSort = useState<String>(currentSelectedSort);

    final isDefault = tempTrack.value == 'All' && tempSort.value == 'trending';

    final activeFilterCount = (tempTrack.value != 'All' ? 1 : 0) +
        (tempSort.value != 'trending' ? 1 : 0);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(
            color: isDark
                ? colors.surfaceBorder.withAlpha(50)
                : colors.surfaceBorder.withAlpha(30),
            width: 1.2,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.black.withAlpha(isDark ? 80 : 30),
            blurRadius: 28,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag Indicator Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                width: 36,
                height: 4.5,
                decoration: BoxDecoration(
                  color: isDark
                      ? colors.surfaceBorder.withAlpha(80)
                      : colors.surfaceBorder.withAlpha(60),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),

            // Sheet Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.primary.withAlpha(isDark ? 40 : 25),
                    ),
                    child: Icon(
                      Icons.tune_rounded,
                      size: 19,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Filter & Sort',
                          style: typography.body.bold.copyWith(
                            color: colors.textPrimary,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          'Customize what appears in your community feed',
                          style: typography.caption.regular.copyWith(
                            color: colors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isDefault)
                    TextButton(
                      onPressed: () {
                        unawaited(HapticFeedback.lightImpact());
                        tempTrack.value = 'All';
                        tempSort.value = 'trending';
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Reset',
                        style: typography.caption.bold.copyWith(
                          color: colors.error,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: colors.textSecondary,
                    ),
                    splashRadius: 18,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Scrollable Options Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section 1: Academic Focus / Track
                    Row(
                      children: [
                        Icon(
                          Icons.school_rounded,
                          size: 16,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          'Academic Track / Focus',
                          style: typography.caption.bold.copyWith(
                            color: colors.textPrimary,
                            fontSize: 13.5,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        CommunityFilterOptionChip(
                          label: 'All Tracks',
                          icon: Icons.public_rounded,
                          isSelected: tempTrack.value == 'All',
                          onTap: () {
                            unawaited(HapticFeedback.selectionClick());
                            tempTrack.value = 'All';
                          },
                        ),
                        ...availableTracks.map((track) {
                          final isSelected = tempTrack.value.toLowerCase() ==
                              track.toLowerCase();
                          final isHomeTrack = track.toLowerCase() ==
                              effectiveTrack.toLowerCase();
                          return CommunityFilterOptionChip(
                            label: track,
                            icon: getTrackIcon(track),
                            isSelected: isSelected,
                            isHighlighted: isHomeTrack && !isSelected,
                            highlightBadge: isHomeTrack,
                            onTap: () {
                              unawaited(HapticFeedback.selectionClick());
                              tempTrack.value = track;
                            },
                          );
                        }),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Section 2: Feed Sort & Content Filter
                    Row(
                      children: [
                        Icon(
                          Icons.sort_rounded,
                          size: 16,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          'Feed Order & Content',
                          style: typography.caption.bold.copyWith(
                            color: colors.textPrimary,
                            fontSize: 13.5,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: kQuickSorts.map((sortItem) {
                        final isSelected = tempSort.value == sortItem.key;
                        return CommunityFilterOptionChip(
                          label: sortItem.label,
                          icon: sortItem.icon,
                          isSelected: isSelected,
                          onTap: () {
                            unawaited(HapticFeedback.selectionClick());
                            tempSort.value = sortItem.key;
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            const Divider(height: 1),

            // Bottom Apply Action Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: PlatformHoverBuilder(
                      builder: (context, isHovered, child) => AnimatedScale(
                        scale: isHovered ? 1.02 : 1.0,
                        duration: AppMotion.snappy,
                        curve: AppMotion.easeOutCubic,
                        child: ShrinkableButton(
                          onTap: () {
                            unawaited(HapticFeedback.mediumImpact());
                            bloc
                              ..add(ChangeTrackFilterEvent(tempTrack.value))
                              ..add(ChangeForumSortFilterEvent(tempSort.value));
                            Navigator.of(context).pop();
                          },
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: colors.primary,
                              borderRadius: AppRadius.radiusPanel,
                              boxShadow: [
                                BoxShadow(
                                  color: colors.primary.withAlpha(isDark ? 80 : 50),
                                  blurRadius: 14,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_rounded,
                                    size: 18,
                                    color: colors.white,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    activeFilterCount > 0
                                        ? 'Apply Filters ($activeFilterCount)'
                                        : 'Apply Filters',
                                    style: typography.body.bold.copyWith(
                                      color: colors.white,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Selectable chip widget for filter options in [CommunityFilterBottomSheet].
class CommunityFilterOptionChip extends StatelessWidget {
  const CommunityFilterOptionChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.isHighlighted = false,
    this.highlightBadge = false,
    super.key,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isHighlighted;
  final bool highlightBadge;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return PlatformHoverBuilder(
      builder: (context, isHovered, child) => AnimatedScale(
        scale: isHovered ? 1.04 : 1.0,
        duration: AppMotion.snappy,
        curve: AppMotion.easeOutCubic,
        child: ShrinkableButton(
          onTap: onTap,
          child: AnimatedContainer(
            duration: AppMotion.snappy,
            curve: AppMotion.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? colors.primary
                  : (isHovered
                      ? colors.primary.withAlpha(isDark ? 30 : 20)
                      : (isDark
                          ? colors.surfaceSecondary
                          : colors.surfaceSecondary.withAlpha(120))),
              borderRadius: AppRadius.radiusPanel,
              border: Border.all(
                color: isSelected
                    ? colors.primary
                    : (isHighlighted
                        ? colors.syllabotAccent.withAlpha(isDark ? 120 : 90)
                        : (isHovered
                            ? colors.primary.withAlpha(isDark ? 70 : 50)
                            : colors.surfaceBorder
                                .withAlpha(isDark ? 40 : 25))),
                width: isSelected ? 1.4 : 1.0,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: colors.primary.withAlpha(isDark ? 55 : 30),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: isSelected ? colors.white : colors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: typography.caption.bold.copyWith(
                    color: isSelected ? colors.white : colors.textPrimary,
                    fontSize: 12.5,
                  ),
                ),
                if (highlightBadge) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? colors.white : colors.syllabotAccent,
                    ),
                  ),
                ],
                if (isSelected) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.check_rounded,
                    size: 13,
                    color: colors.white,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
