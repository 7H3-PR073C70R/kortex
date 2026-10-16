import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/ingestion/domain/entities/lms_course_entity.dart';
import 'package:kortex/src/features/ingestion/presentation/widgets/lms_import/lms_course_card.dart';
import 'package:kortex/src/features/monetization/domain/services/subscription_guard.dart';

/// List section displaying loaded courses with Pro entitlement awareness and import handlers.
class LmsCoursesListSection extends StatelessWidget {
  const LmsCoursesListSection({
    required this.courses,
    required this.isParsingOcr,
    required this.onImportCourse,
    this.selectedCourseId,
    this.subscriptionGuard,
    super.key,
  });

  final List<LmsCourse> courses;
  final bool isParsingOcr;
  final String? selectedCourseId;
  final void Function(LmsCourse course, {required bool isLocked})
      onImportCourse;
  final SubscriptionGuard? subscriptionGuard;

  SubscriptionGuard _resolveGuard() {
    if (subscriptionGuard != null) return subscriptionGuard!;
    return locator.isRegistered<SubscriptionGuard>()
        ? locator<SubscriptionGuard>()
        : SubscriptionGuard();
  }

  @override
  Widget build(BuildContext context) {
    if (courses.isEmpty) return const SizedBox.shrink();

    final colors = context.colors;
    final typography = context.typography;
    final guard = _resolveGuard();
    final isPro = guard.isPro;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Available Courses (${courses.length})',
              style: typography.callout.bold.copyWith(
                color: colors.textPrimary,
              ),
            ),
            if (!isPro)
              Text(
                'Free Tier: 1 Course',
                style: typography.caption.medium.copyWith(
                  color: colors.primary,
                  fontSize: 11,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: courses.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final course = courses[index];
            final isLocked = !isPro && index > 0;
            final isImporting =
                isParsingOcr && selectedCourseId == course.id;

            return LmsCourseCard(
              course: course,
              isLocked: isLocked,
              isImporting: isImporting,
              onImport: () => onImportCourse(course, isLocked: isLocked),
            );
          },
        ),
      ],
    );
  }
}
