import 'dart:async';
import 'dart:ui';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

@RoutePage()
class CourseModulePage extends StatelessWidget {
  const CourseModulePage({
    @PathParam('courseId') required this.courseId,
    required this.courseCode,
    required this.courseTitle,
    super.key,
  });

  final String courseId;
  final String courseCode;
  final String courseTitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final pastPapers = [
      '2024 Final Examination (Paper 1)',
      '2023 Mid-Semester Diagnostic Test',
      '2022 Supplementary Problem Set',
    ];

    return Scaffold(
      backgroundColor: isDark
          ? colors.backgroundPrimary
          : colors.surfacePrimary,
      appBar: AppBar(
        backgroundColor: colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colors.textPrimary),
          onPressed: () => context.router.pop(),
        ),
        title: Text(
          courseCode,
          style: typography.title3.bold.copyWith(color: colors.textPrimary),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Course Header
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: isDark
                          ? colors.surfaceSecondary.withAlpha(160)
                          : colors.surfacePrimary.withAlpha(210),
                      border: Border.all(
                        color: isDark
                            ? colors.surfaceBorderHighlight.withAlpha(70)
                            : colors.surfaceBorder.withAlpha(140),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          courseTitle,
                          style: typography.title3.bold.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          courseCode,
                          style: typography.footnote.regular.copyWith(
                            color: colors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Text(
                l10n.courseModulePastPapersTitle,
                style: typography.callout.bold.copyWith(
                  color: colors.textPrimary,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 12),

              ...pastPapers.map((paper) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ShrinkableButton(
                    onTap: () {
                      unawaited(HapticFeedback.lightImpact());
                      unawaited(
                        context.router.push(
                          SyllabotChatRoute(
                            initialPrompt:
                                'Explain step-by-step solutions for '
                                '$paper in $courseCode.',
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? colors.surfaceSecondary.withAlpha(140)
                            : colors.surfacePrimary.withAlpha(200),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? colors.surfaceBorderHighlight.withAlpha(60)
                              : colors.surfaceBorder.withAlpha(120),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.description_outlined,
                            size: 22,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  paper,
                                  style: typography.caption.bold.copyWith(
                                    color: colors.textPrimary,
                                    fontSize: 13.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  l10n.courseModuleVerifiedSubtitle,
                                  style: typography.footnote.regular.copyWith(
                                    color: colors.textSecondary,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: colors.textMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
