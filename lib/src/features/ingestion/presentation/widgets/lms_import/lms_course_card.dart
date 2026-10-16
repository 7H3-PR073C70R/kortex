import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/ingestion/domain/entities/lms_course_entity.dart';
import 'package:kortex/src/shared/widgets/app_logo_loader.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Interactive card presenting an available LMS course with import / Pro lock triggers.
class LmsCourseCard extends StatelessWidget {
  const LmsCourseCard({
    required this.course,
    required this.isImporting,
    required this.onImport,
    this.isLocked = false,
    super.key,
  });

  final LmsCourse course;
  final bool isImporting;
  final bool isLocked;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return PlatformHoverBuilder(
      builder: (context, isHovered, child) {
        return AnimatedContainer(
          duration: AppMotion.snappy,
          curve: AppMotion.easeOutCubic,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? colors.surfaceTertiary : colors.surfaceSecondary,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: isHovered
                  ? colors.primary.withAlpha(isDark ? 120 : 80)
                  : colors.primary.withAlpha(isDark ? 50 : 25),
            ),
            boxShadow: isHovered
                ? [
                    BoxShadow(
                      color: colors.black.withAlpha(isDark ? 30 : 10),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(AppRadius.card - 4),
                ),
                child: Icon(
                  course.platform == 'canvas'
                      ? Icons.view_sidebar_rounded
                      : Icons.class_rounded,
                  color: colors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: typography.body.bold.copyWith(
                        color: colors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${course.section} • ${course.platform == 'canvas' ? 'Canvas' : 'Classroom'}',
                      style: typography.caption.regular.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PlatformHoverBuilder(
                builder: (context, isBtnHovered, child) {
                  return AnimatedScale(
                    scale: isBtnHovered ? 1.05 : 1.0,
                    duration: AppMotion.snappy,
                    curve: AppMotion.easeOutCubic,
                    child: ShrinkableButton(
                      onTap: isImporting ? null : onImport,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isLocked
                              ? colors.primary.withAlpha(220)
                              : colors.primary,
                          borderRadius: BorderRadius.circular(
                            AppRadius.card - 4,
                          ),
                        ),
                        child: isImporting
                            ? AppLogoLoader(
                                size: 16,
                                color: colors.white,
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isLocked) ...[
                                    const Icon(
                                      Icons.lock_rounded,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  Text(
                                    isLocked ? 'PRO' : 'Import',
                                    style: typography.caption.bold.copyWith(
                                      color: colors.white,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
