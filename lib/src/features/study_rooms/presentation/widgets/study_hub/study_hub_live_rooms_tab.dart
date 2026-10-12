import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_event.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_hub_bloc.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_state.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/live_focus_room_card.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/study_hub/live_rooms_empty_card.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/study_hub/study_hub_constants.dart';

/// Tab displaying live interactive focus rooms with search, track filtering, and responsive grid layouts.
class StudyHubLiveRoomsTab extends StatefulWidget {
  const StudyHubLiveRoomsTab({
    required this.state,
    required this.targetTrack,
    this.hasSelectedDeck = false,
    super.key,
  });

  final CommunityState state;
  final String? targetTrack;
  final bool hasSelectedDeck;

  @override
  State<StudyHubLiveRoomsTab> createState() => _StudyHubLiveRoomsTabState();
}

class _StudyHubLiveRoomsTabState extends State<StudyHubLiveRoomsTab> {
  late String _selectedFilter;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedFilter = 'All';
  }

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
    final isGrid = screenWidth >= StudyHubConstants.gridBreakpoint;
    final isDesktop = screenWidth >= StudyHubConstants.desktopBreakpoint;
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 80;

    final userTrack = widget.targetTrack?.trim();

    final filteredRooms = widget.state.studyRooms.where((room) {
      if (_selectedFilter != 'All') {
        final filter = _selectedFilter.toLowerCase();
        final title = room.title.toLowerCase();
        final subject = room.subject.toLowerCase();
        final category = room.category.toLowerCase();
        if (!title.contains(filter) &&
            !subject.contains(filter) &&
            !category.contains(filter)) {
          return false;
        }
      }

      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final title = room.title.toLowerCase();
        final subject = room.subject.toLowerCase();
        final category = room.category.toLowerCase();
        final goal = (room.activeGoal ?? '').toLowerCase();
        final ambient = room.ambientSoundTrack.toLowerCase();
        return title.contains(q) ||
            subject.contains(q) ||
            category.contains(q) ||
            goal.contains(q) ||
            ambient.contains(q);
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
              // Live Pomodoro Rooms Section Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.error,
                        ),
                      )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .fadeIn(duration: 800.ms)
                          .scaleXY(begin: 0.85, end: 1, duration: 800.ms),
                      const SizedBox(width: 8),
                      Text(
                        'Live Focus Rooms',
                        style: typography.subhead.bold.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${filteredRooms.length} active',
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
                        hintText: 'Search live focus rooms, topics, goals...',
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
                      _buildFilterChip(
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
                        _buildFilterChip(
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
                      _buildFilterChip(
                        label: '📚 WAEC',
                        isSelected: _selectedFilter == 'WAEC',
                        onTap: () => setState(() => _selectedFilter = 'WAEC'),
                      ),
                      const SizedBox(width: 6),
                      _buildFilterChip(
                        label: '🇳🇬 JAMB',
                        isSelected: _selectedFilter == 'JAMB',
                        onTap: () => setState(() => _selectedFilter = 'JAMB'),
                      ),
                      const SizedBox(width: 6),
                      _buildFilterChip(
                        label: '🇳🇬 NECO',
                        isSelected: _selectedFilter == 'NECO',
                        onTap: () => setState(() => _selectedFilter = 'NECO'),
                      ),
                      const SizedBox(width: 6),
                      _buildFilterChip(
                        label: '🇳🇬 JUPEB',
                        isSelected: _selectedFilter == 'JUPEB',
                        onTap: () => setState(() => _selectedFilter = 'JUPEB'),
                      ),
                      const SizedBox(width: 6),
                      _buildFilterChip(
                        label: '🎓 SAT',
                        isSelected: _selectedFilter == 'SAT',
                        onTap: () => setState(() => _selectedFilter = 'SAT'),
                      ),
                      const SizedBox(width: 6),
                      _buildFilterChip(
                        label: '🧬 STEM',
                        isSelected: _selectedFilter == 'STEM',
                        onTap: () => setState(() => _selectedFilter = 'STEM'),
                      ),
                      const SizedBox(width: 6),
                      _buildFilterChip(
                        label: '🏛️ University',
                        isSelected: _selectedFilter == 'University',
                        onTap: () =>
                            setState(() => _selectedFilter = 'University'),
                      ),
                      const SizedBox(width: 6),
                      _buildFilterChip(
                        label: '📖 General',
                        isSelected: _selectedFilter == 'General',
                        onTap: () =>
                            setState(() => _selectedFilter = 'General'),
                      ),
                    ],
                  ),
                ),
              ),

              if (filteredRooms.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 48),
                    child: LiveRoomsEmptyCard(
                      selectedFilter: _selectedFilter,
                      userTrack: userTrack,
                      onClearFilter: () => setState(() => _selectedFilter = 'All'),
                    ),
                  ),
                )
              else if (isGrid)
                // 2-column grid layout for tablet / landscape / desktop
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 440,
                      mainAxisExtent: 184,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final room = filteredRooms[index];
                        return LiveFocusRoomCard(
                          room: room,
                          onJoinTap: () {
                            unawaited(
                              context.router.push(
                                LiveStudyRoomRoute(room: room),
                              ),
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
                      childCount: filteredRooms.length,
                    ),
                  ),
                )
              else
                // Single-column list for compact / portrait phone
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final room = filteredRooms[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: LiveFocusRoomCard(
                            room: room,
                            onJoinTap: () {
                              unawaited(
                                context.router.push(
                                  LiveStudyRoomRoute(room: room),
                                ),
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
                      childCount: filteredRooms.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip({
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
