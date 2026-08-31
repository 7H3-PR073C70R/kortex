import 'dart:ui';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';

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
    final isDark = context.isDarkMode;

    final pastPapers = [
      '2024 Past Examination (With Step-by-Step Solutions)',
      '2023 Midterm Assessment & Marking Guide',
      '2022 Comprehensive Theory & Objective Paper',
      '2021 High-Yield Diagnostic Problem Set',
    ];

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF090D16)
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Semantics(
          button: true,
          label: 'Back to Dashboard',
          child: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: colors.textPrimary),
            onPressed: () => context.router.pop(),
          ),
        ),
        title: Text(
          courseCode,
          style: typography.title3.bold.copyWith(color: colors.textPrimary),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          physics: const BouncingScrollPhysics(),
          children: [
            // Course Banner
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark
                        ? colors.surfaceSecondary.withAlpha(190)
                        : colors.surfacePrimary.withAlpha(230),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: colors.primary.withAlpha(isDark ? 90 : 60),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primary.withAlpha(isDark ? 60 : 30),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          courseCode,
                          style: typography.caption.bold.copyWith(
                            color: colors.primary,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        courseTitle,
                        style: typography.title3.bold.copyWith(
                          color: colors.textPrimary,
                          fontSize: 17,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'Past Papers & Problem Sets',
              style: typography.title3.bold.copyWith(
                color: colors.textPrimary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),

            ...pastPapers.map((paper) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
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
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.primary.withAlpha(isDark ? 50 : 25),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.description_rounded,
                        color: colors.primary,
                        size: 20,
                      ),
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
                            'Verified OCR · Step-by-Step AI Solutions',
                            style: typography.footnote.regular.copyWith(
                              color: colors.textMuted,
                              fontSize: 11,
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
              );
            }),
          ],
        ),
      ),
    );
  }
}
