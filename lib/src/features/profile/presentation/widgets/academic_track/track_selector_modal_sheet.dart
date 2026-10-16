import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/auth/domain/entities/course_track_entity.dart';
import 'package:kortex/src/features/profile/presentation/widgets/academic_track/track_icon_helper.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_sheet.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Full searchable bottom sheet to select from all available academic tracks.
Future<void> showTrackSelectorModalSheet({
  required BuildContext context,
  required ValueNotifier<String> selectedTrack,
}) {
  AppFeedback.selection();
  final colors = context.colors;
  final typography = context.typography;
  final isDark = context.isDarkMode;

  return AppAdaptiveSheet.showModal<void>(
    context: context,
    maxWidth: 600,
    builder: (ctx) {
      final isDesktop = AppAdaptiveSheet.isDesktopOrWeb(ctx);
      const tracks = CourseTrackEntity.defaultTracks;
      final searchQuery = ValueNotifier<String>('');

      return Align(
        alignment: isDesktop ? Alignment.center : Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Container(
            height: isDesktop ? 600 : MediaQuery.of(ctx).size.height * 0.72,
            decoration: BoxDecoration(
              color: colors.surfacePrimary,
              borderRadius: isDesktop
                  ? BorderRadius.circular(AppRadius.dialog)
                  : const BorderRadius.vertical(
                      top: Radius.circular(AppRadius.dialog),
                    ),
              border: Border.all(
                color: colors.surfaceBorder.withAlpha(80),
              ),
              boxShadow: isDesktop
                  ? [
                      BoxShadow(
                        color: colors.black.withAlpha(isDark ? 80 : 30),
                        blurRadius: 32,
                        offset: const Offset(0, 12),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              children: [
                if (!isDesktop) ...[
                  const SizedBox(height: 10),
                  // Handle bar
                  Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.surfaceBorder,
                      borderRadius: AppRadius.radiusMicro,
                    ),
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select Academic Track',
                        style: typography.title3.bold.copyWith(
                          color: colors.textPrimary,
                          fontSize: 17,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: colors.textSecondary,
                          size: 20,
                        ),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: TextField(
                    onChanged: (q) => searchQuery.value = q,
                    decoration: InputDecoration(
                      hintText: 'Search exam track, university, or department...',
                      hintStyle: typography.caption.regular.copyWith(
                        color: colors.textSecondary,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: colors.textSecondary,
                        size: 18,
                      ),
                      filled: true,
                      fillColor: colors.surfaceSecondary,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.radiusCard,
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                Divider(
                  height: 1,
                  color: colors.surfaceBorder.withAlpha(60),
                ),
                Expanded(
                  child: ValueListenableBuilder<String>(
                    valueListenable: searchQuery,
                    builder: (context, query, _) {
                      final filteredTracks = query.trim().isEmpty
                          ? tracks
                          : tracks.where((t) {
                              final q = query.toLowerCase();
                              return t.name.toLowerCase().contains(q) ||
                                  t.description.toLowerCase().contains(q) ||
                                  t.id.toLowerCase().contains(q);
                            }).toList();

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        itemCount: filteredTracks.length,
                        itemBuilder: (context, index) {
                          final track = filteredTracks[index];
                          final isSelected = selectedTrack.value == track.id;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: PlatformHoverBuilder(
                              builder: (context, isHovered, child) {
                                return AnimatedContainer(
                                  duration: AppMotion.snappy,
                                  curve: Curves.easeOutCubic,
                                  transform: isHovered
                                      ? Matrix4.translationValues(4, 0, 0)
                                      : Matrix4.identity(),
                                  child: child,
                                );
                              },
                              child: ShrinkableButton(
                                onTap: () {
                                  AppFeedback.light();
                                  selectedTrack.value = track.id;
                                  Navigator.of(ctx).pop();
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? colors.primary.withAlpha(
                                            isDark ? 40 : 20,
                                          )
                                        : colors.surfaceSecondary,
                                    borderRadius: AppRadius.radiusCard,
                                    border: Border.all(
                                      color: isSelected
                                          ? colors.primary
                                          : colors.surfaceBorder.withAlpha(60),
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: colors.primary.withAlpha(30),
                                          borderRadius: AppRadius.radiusBadge,
                                        ),
                                        child: Icon(
                                          getTrackIconData(track.iconName),
                                          color: colors.primary,
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
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
                                                    style: typography.body.bold
                                                        .copyWith(
                                                          color: colors
                                                              .textPrimary,
                                                          fontSize: 13.5,
                                                        ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 5,
                                                        vertical: 1.5,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        colors.surfaceTertiary,
                                                    borderRadius:
                                                        AppRadius.radiusMicro,
                                                  ),
                                                  child: Text(
                                                    '~${track.examCountdownDays}d',
                                                    style: typography
                                                        .caption
                                                        .bold
                                                        .copyWith(
                                                          color: colors
                                                              .textSecondary,
                                                          fontSize: 9.5,
                                                        ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              track.description,
                                              style: typography.caption.regular
                                                  .copyWith(
                                                    color: colors.textSecondary,
                                                    fontSize: 11,
                                                  ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        Icon(
                                          Icons.check_circle_rounded,
                                          color: colors.primary,
                                          size: 20,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
