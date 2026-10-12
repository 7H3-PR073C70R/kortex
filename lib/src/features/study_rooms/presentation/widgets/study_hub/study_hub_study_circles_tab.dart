import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_event.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_hub_bloc.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_state.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/study_circle_card.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/study_circle_detail_sheet.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/study_hub/study_circles_explainer_banner.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/study_hub/study_hub_constants.dart';

/// Tab displaying peer study pods with search, multi-track filters, and join triggers.
class StudyHubStudyCirclesTab extends StatefulWidget {
  const StudyHubStudyCirclesTab({
    required this.state,
    required this.targetTrack,
    this.hasSelectedDeck = false,
    super.key,
  });

  final CommunityState state;
  final String? targetTrack;
  final bool hasSelectedDeck;

  @override
  State<StudyHubStudyCirclesTab> createState() =>
      _StudyHubStudyCirclesTabState();
}

class _StudyHubStudyCirclesTabState extends State<StudyHubStudyCirclesTab> {
  String _selectedFilter = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= StudyHubConstants.desktopBreakpoint;
    final isGrid = !widget.hasSelectedDeck &&
        (screenWidth >= StudyHubConstants.gridBreakpoint);
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 80;
    final userTrack = widget.targetTrack?.trim();

    final filteredCircles = widget.state.studyCircles.where((circle) {
      if (_selectedFilter != 'All') {
        final filter = _selectedFilter.toLowerCase();
        final track = circle.track.toLowerCase();
        final name = circle.name.toLowerCase();
        if (!track.contains(filter) && !name.contains(filter)) {
          return false;
        }
      }

      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final name = circle.name.toLowerCase();
        final track = circle.track.toLowerCase();
        return name.contains(q) || track.contains(q);
      }

      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: () async {
        context.read<CommunityHubBloc>().add(const LoadCommunityHubEvent());
      },
      color: colors.primary,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: widget.hasSelectedDeck
                ? 520
                : (isDesktop ? 1400 : 860),
          ),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Study Circles Onboarding Explainer Banner
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: StudyCirclesExplainerBanner(),
                ),
              ),

              // Study Circles Section Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: Row(
                    children: [
                      Icon(
                        Icons.diversity_3_rounded,
                        size: 20,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Peer Study Pods',
                        style: typography.subhead.bold.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${filteredCircles.length} ${filteredCircles.length == 1 ? 'Pod' : 'Pods'}',
                        style: typography.caption.medium.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Search Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark
                          ? colors.surfaceSecondary
                          : colors.surfacePrimary,
                      borderRadius: AppRadius.radiusBadge,
                      border: Border.all(
                        color: colors.surfaceBorder.withAlpha(isDark ? 50 : 35),
                      ),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                      style: typography.caption.medium.copyWith(
                        color: colors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search study pods, tracks, goals...',
                        hintStyle: typography.caption.regular.copyWith(
                          color: colors.textSecondary,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          size: 18,
                          color: colors.textSecondary,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ),
              ),

              // Multi-Track Filter Chips Bar
              SliverToBoxAdapter(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Row(
                    children: [
                      _buildPodFilterChip(
                        label: '🌐 All Tracks',
                        isSelected: _selectedFilter == 'All',
                        onTap: () {
                          unawaited(HapticFeedback.selectionClick());
                          setState(() {
                            _selectedFilter = 'All';
                          });
                        },
                      ),
                      if (userTrack != null && userTrack.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        _buildPodFilterChip(
                          label: '🎯 My Track ($userTrack)',
                          isSelected: _selectedFilter.toLowerCase() ==
                              userTrack.toLowerCase(),
                          onTap: () {
                            unawaited(HapticFeedback.selectionClick());
                            setState(() {
                              _selectedFilter = userTrack;
                            });
                          },
                        ),
                      ],
                      const SizedBox(width: 6),
                      _buildPodFilterChip(
                        label: '📚 WAEC',
                        isSelected: _selectedFilter == 'WAEC',
                        onTap: () => setState(() => _selectedFilter = 'WAEC'),
                      ),
                      const SizedBox(width: 6),
                      _buildPodFilterChip(
                        label: '🇳🇬 JAMB',
                        isSelected: _selectedFilter == 'JAMB',
                        onTap: () => setState(() => _selectedFilter = 'JAMB'),
                      ),
                      const SizedBox(width: 6),
                      _buildPodFilterChip(
                        label: '🇳🇬 NECO',
                        isSelected: _selectedFilter == 'NECO',
                        onTap: () => setState(() => _selectedFilter = 'NECO'),
                      ),
                      const SizedBox(width: 6),
                      _buildPodFilterChip(
                        label: '🇳🇬 JUPEB',
                        isSelected: _selectedFilter == 'JUPEB',
                        onTap: () => setState(() => _selectedFilter = 'JUPEB'),
                      ),
                      const SizedBox(width: 6),
                      _buildPodFilterChip(
                        label: '🎓 SAT',
                        isSelected: _selectedFilter == 'SAT',
                        onTap: () => setState(() => _selectedFilter = 'SAT'),
                      ),
                      const SizedBox(width: 6),
                      _buildPodFilterChip(
                        label: '🧬 STEM',
                        isSelected: _selectedFilter == 'STEM',
                        onTap: () => setState(() => _selectedFilter = 'STEM'),
                      ),
                      const SizedBox(width: 6),
                      _buildPodFilterChip(
                        label: '🏛️ University',
                        isSelected: _selectedFilter == 'University',
                        onTap: () =>
                            setState(() => _selectedFilter = 'University'),
                      ),
                      const SizedBox(width: 6),
                      _buildPodFilterChip(
                        label: '📖 General',
                        isSelected: _selectedFilter == 'General',
                        onTap: () =>
                            setState(() => _selectedFilter = 'General'),
                      ),
                    ],
                  ),
                ),
              ),

              if (filteredCircles.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 48,
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.groups_outlined,
                            size: 44,
                            color: colors.textSecondary.withAlpha(120),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _selectedFilter == 'All' && _searchQuery.isEmpty
                                ? 'No study circles available yet.'
                                : 'No study pods match your search/filter.',
                            style: typography.caption.regular.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (isGrid)
                // 2-column grid layout for tablet / desktop viewports
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: isDesktop ? 650 : 540,
                      mainAxisExtent: 295,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final circle = filteredCircles[index];
                        return StudyCircleCard(
                          circle: circle,
                          margin: EdgeInsets.zero,
                          onTapDetails: () {
                            unawaited(
                              StudyCircleDetailSheet.show(context, circle),
                            );
                          },
                          onJoinTap: () {
                            context.read<CommunityHubBloc>().add(
                              JoinStudyCircleEvent(circle.id),
                            );
                          },
                        )
                            .animate(
                              delay: (index < 6 ? index * 45 : 0).ms,
                            )
                            .fadeIn(duration: 200.ms)
                            .slideY(
                              begin: 0.04,
                              end: 0,
                              curve: Curves.easeOutCubic,
                            );
                      },
                      childCount: filteredCircles.length,
                    ),
                  ),
                )
              else
                // Single-column list layout for narrow mobile viewports
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final circle = filteredCircles[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: StudyCircleCard(
                            circle: circle,
                            onTapDetails: () {
                              unawaited(
                                StudyCircleDetailSheet.show(context, circle),
                              );
                            },
                            onJoinTap: () {
                              context.read<CommunityHubBloc>().add(
                                JoinStudyCircleEvent(circle.id),
                              );
                            },
                          ),
                        )
                            .animate(
                              delay: (index < 6 ? index * 45 : 0).ms,
                            )
                            .fadeIn(duration: 200.ms)
                            .slideY(
                              begin: 0.04,
                              end: 0,
                              curve: Curves.easeOutCubic,
                            );
                      },
                      childCount: filteredCircles.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPodFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.snappy,
        curve: AppMotion.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.primary.withAlpha(isDark ? 60 : 35)
              : colors.surfacePrimary,
          borderRadius: AppRadius.radiusBadge,
          border: Border.all(
            color: isSelected
                ? colors.primary
                : colors.surfaceBorder.withAlpha(isDark ? 50 : 35),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: typography.caption.medium.copyWith(
            color: isSelected ? colors.primary : colors.textSecondary,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
