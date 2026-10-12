import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/cbt_practice_config_modal_sheet.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class CourseModuleCbtPaperCard extends StatelessWidget {
  const CourseModuleCbtPaperCard({
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.icon,
    required this.accentColor,
    required this.courseId,
    required this.courseCode,
    required this.courseTitle,
    required this.questions,
    required this.isTimed,
    required this.isDark,
    super.key,
  });

  final String title;
  final String subtitle;
  final String badgeText;
  final IconData icon;
  final Color accentColor;
  final String courseId;
  final String courseCode;
  final String courseTitle;
  final List<PastQuestionEntity> questions;
  final bool isTimed;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return ShrinkableButton(
      onTap: () {
        AppFeedback.light();
        unawaited(
          CbtPracticeConfigModalSheet.show(
            context,
            title: title,
            courseId: courseId,
            courseCode: courseCode,
            courseTitle: courseTitle,
            allQuestions: questions,
            isMockExam: isTimed,
          ),
        );
      },
      child: PlatformHoverBuilder(
        builder: (context, isHovered, child) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.panel),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: AnimatedContainer(
                duration: AppMotion.snappy,
                curve: AppMotion.easeOutCubic,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? (isHovered
                          ? colors.surfaceSecondary.withAlpha(180)
                          : colors.surfaceSecondary.withAlpha(140))
                      : (isHovered
                          ? colors.surfacePrimary
                          : colors.surfacePrimary.withAlpha(200)),
                  borderRadius: BorderRadius.circular(AppRadius.panel),
                  border: Border.all(
                    color: isHovered
                        ? accentColor.withAlpha(isDark ? 140 : 110)
                        : (isDark
                            ? colors.surfaceBorderHighlight.withAlpha(60)
                            : colors.surfaceBorder.withAlpha(120)),
                  ),
                  boxShadow: isHovered
                      ? [
                          BoxShadow(
                            color: colors.black.withAlpha(isDark ? 35 : 15),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: accentColor.withAlpha(isDark ? 40 : 25),
                        borderRadius: BorderRadius.circular(AppRadius.card),
                      ),
                      child: Icon(icon, size: 20, color: accentColor),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: typography.caption.bold.copyWith(
                                    color: colors.textPrimary,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: accentColor.withAlpha(25),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.micro,
                                  ),
                                ),
                                child: Text(
                                  badgeText,
                                  style: typography.caption.bold.copyWith(
                                    color: accentColor,
                                    fontSize: 9.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            style: typography.footnote.regular.copyWith(
                              color: colors.textSecondary,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.play_circle_outline_rounded,
                      size: 22,
                      color: accentColor,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
