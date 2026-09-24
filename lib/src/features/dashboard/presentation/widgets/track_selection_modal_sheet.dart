import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/domain/entities/course_track_entity.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_event.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Modal bottom sheet allowing users to select or switch their academic track
/// in a clean, intuitive, and friction-free way right from the Dashboard.
class TrackSelectionModalSheet extends StatefulWidget {
  const TrackSelectionModalSheet({
    this.currentTrackId,
    super.key,
  });

  final String? currentTrackId;

  static Future<void> show(
    BuildContext context, {
    String? currentTrackId,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.transparent,
      builder: (sheetContext) => Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: TrackSelectionModalSheet(
            currentTrackId: currentTrackId,
          ),
        ),
      ),
    );
  }

  @override
  State<TrackSelectionModalSheet> createState() =>
      _TrackSelectionModalSheetState();
}

class _TrackSelectionModalSheetState extends State<TrackSelectionModalSheet> {
  late final TextEditingController _searchController;
  late final ScrollController _scrollController;
  String _searchQuery = '';
  String? _selectedTrackId;

  @override
  void initState() {
    super.initState();
    _selectedTrackId = widget.currentTrackId;
    _searchController = TextEditingController();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  IconData _resolveIcon(String iconName) {
    switch (iconName) {
      case 'school':
        return Icons.school_rounded;
      case 'assignment_turned_in':
        return Icons.assignment_turned_in_rounded;
      case 'timer':
        return Icons.timer_rounded;
      case 'history_edu':
        return Icons.history_edu_rounded;
      case 'workspace_premium':
        return Icons.workspace_premium_rounded;
      case 'psychology':
        return Icons.psychology_rounded;
      case 'menu_book':
        return Icons.menu_book_rounded;
      case 'cast_for_education':
        return Icons.cast_for_education_rounded;
      default:
        return Icons.school_rounded;
    }
  }

  void _selectTrack(CourseTrackEntity track) {
    unawaited(HapticFeedback.mediumImpact());
    setState(() {
      _selectedTrackId = track.id;
    });

    (context.read<AuthBloc?>() ?? locator<AuthBloc>()).add(
      AuthUpdateCourseTrackRequested(
        track: track.id,
        dailyTarget: track.defaultDailyTarget,
      ),
    );

    if (locator.isRegistered<DashboardBloc>()) {
      locator<DashboardBloc>().add(
        const DashboardRefreshed(),
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Academic track switched to ${track.name}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    const allTracks = CourseTrackEntity.defaultTracks;
    final filteredTracks = _searchQuery.isEmpty
        ? allTracks
        : allTracks.where((t) {
            final q = _searchQuery.toLowerCase();
            return t.name.toLowerCase().contains(q) ||
                t.description.toLowerCase().contains(q) ||
                t.id.toLowerCase().contains(q);
          }).toList();

    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: colors.surfacePrimary,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.panel),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.black.withAlpha(isDark ? 80 : 30),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.textMuted.withAlpha(isDark ? 80 : 50),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header Row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colors.primary.withAlpha(isDark ? 50 : 25),
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                    child: Icon(
                      Icons.track_changes_rounded,
                      color: colors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Academic Track',
                          style: typography.headline.bold.copyWith(
                            color: colors.textPrimary,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Choose your target curriculum or educational level',
                          style: typography.footnote.regular.copyWith(
                            color: colors.textSecondary,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close_rounded,
                      color: colors.textMuted,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Container(
                decoration: BoxDecoration(
                  color: colors.surfaceSecondary.withAlpha(isDark ? 160 : 200),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(
                    color: colors.surfaceBorder.withAlpha(isDark ? 60 : 120),
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  style: typography.body.regular.copyWith(
                    color: colors.textPrimary,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search tracks (e.g. WAEC, JAMB, B.Sc)...',
                    hintStyle: typography.body.regular.copyWith(
                      color: colors.textMuted,
                      fontSize: 13.5,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: colors.textMuted,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            color: colors.textMuted,
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ),

            const Divider(height: 1),

            // Track list with Scrollbar
            Expanded(
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                child: filteredTracks.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                size: 44,
                                color: colors.textMuted,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No matching academic tracks found',
                                style: typography.body.medium.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: filteredTracks.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final track = filteredTracks[index];
                          final isSelected = track.id == _selectedTrackId;

                          return PlatformHoverBuilder(
                            builder: (context, isHovered, child) {
                              return ShrinkableButton(
                                onTap: () => _selectTrack(track),
                                child: AnimatedContainer(
                                  duration: AppMotion.snappy,
                                  curve: AppMotion.easeOutCubic,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? colors.primary.withAlpha(
                                            isDark ? 45 : 20,
                                          )
                                        : isHovered
                                            ? colors.surfaceSecondary
                                            : colors.surfaceSecondary
                                                .withAlpha(isDark ? 100 : 180),
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.card,
                                    ),
                                    border: Border.all(
                                      color: isSelected
                                          ? colors.primary
                                          : isHovered
                                              ? colors.primary.withAlpha(100)
                                              : colors.surfaceBorder.withAlpha(
                                                  isDark ? 50 : 100,
                                                ),
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 42,
                                        height: 42,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? colors.primary
                                              : colors.surfacePrimary,
                                          borderRadius: BorderRadius.circular(
                                            AppRadius.badge,
                                          ),
                                          border: Border.all(
                                            color: isSelected
                                                ? colors.primary
                                                : colors.surfaceBorder
                                                    .withAlpha(80),
                                          ),
                                        ),
                                        child: Icon(
                                          _resolveIcon(track.iconName),
                                          color: isSelected
                                              ? colors.white
                                              : colors.primary,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    track.name,
                                                    style: typography
                                                        .callout.bold
                                                        .copyWith(
                                                      color: colors.textPrimary,
                                                      fontSize: 14.5,
                                                    ),
                                                  ),
                                                ),
                                                if (isSelected) ...[
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                      horizontal: 7,
                                                      vertical: 2,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: colors.primary,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                        AppRadius.badge,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      'ACTIVE',
                                                      style: typography
                                                          .caption.bold
                                                          .copyWith(
                                                        color: colors.white,
                                                        fontSize: 9.5,
                                                        letterSpacing: 0.4,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              track.description,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: typography.footnote.regular
                                                  .copyWith(
                                                color: colors.textSecondary,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(
                                        isSelected
                                            ? Icons.check_circle_rounded
                                            : Icons.radio_button_unchecked_rounded,
                                        color: isSelected
                                            ? colors.primary
                                            : colors.textMuted.withAlpha(120),
                                        size: 22,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
