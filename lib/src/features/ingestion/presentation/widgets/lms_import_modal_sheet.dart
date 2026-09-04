import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/features/ingestion/data/data_sources/lms_import_data_source.dart';
import 'package:kortex/src/features/ingestion/domain/entities/processing_status.dart';
import 'package:kortex/src/features/ingestion/presentation/bloc/ingestion_bloc.dart';
import 'package:kortex/src/features/ingestion/presentation/bloc/ingestion_event.dart';
import 'package:kortex/src/features/ingestion/presentation/bloc/ingestion_state.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class LmsImportModalSheet extends HookWidget {
  const LmsImportModalSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => BlocProvider.value(
        value: context.read<IngestionBloc>(),
        child: const LmsImportModalSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final selectedPlatform = useState<String>('google_classroom');
    final tokenController = useTextEditingController(text: 'demo_token');
    final domainController =
        useTextEditingController(text: 'canvas.instructure.com');

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: colors.surfaceBorder.withAlpha(80),
        ),
      ),
      child: BlocConsumer<IngestionBloc, IngestionState>(
        listener: (context, state) {
          if (state.status == ProcessingStatus.completed &&
              state.snippets.isNotEmpty &&
              state.currentDocument?.fileType == 'lms') {
            Navigator.of(context).pop();
          }
        },
        builder: (context, state) {
          final isCanvas = selectedPlatform.value == 'canvas';

          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.surfaceBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colors.primary.withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.school_rounded,
                        color: colors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Import from LMS',
                            style: typography.title3.bold.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                          Text(
                            'Sync courses, syllabi, & assignments into flashcards',
                            style: typography.caption.medium.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Platform Selector Toggle
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark
                        ? colors.surfaceTertiary
                        : colors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _PlatformTab(
                          label: 'Google Classroom',
                          icon: Icons.class_outlined,
                          isSelected: !isCanvas,
                          onTap: () {
                            AppFeedback.selection();
                            selectedPlatform.value = 'google_classroom';
                          },
                        ),
                      ),
                      Expanded(
                        child: _PlatformTab(
                          label: 'Canvas LMS',
                          icon: Icons.assignment_outlined,
                          isSelected: isCanvas,
                          onTap: () {
                            AppFeedback.selection();
                            selectedPlatform.value = 'canvas';
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (isCanvas) ...[
                  AppTextField(
                    controller: domainController,
                    label: 'Canvas Domain',
                    hintText: 'e.g. canvas.instructure.com',
                    prefixIcon: const Icon(Icons.domain_rounded, size: 20),
                  ),
                  const SizedBox(height: 12),
                ],

                AppTextField(
                  controller: tokenController,
                  label: isCanvas ? 'Canvas API Token' : 'Google OAuth Token',
                  hintText: 'Enter API access token',
                  prefixIcon: const Icon(Icons.key_rounded, size: 20),
                ),
                const SizedBox(height: 16),

                ShrinkableButton(
                  onTap: state.status == ProcessingStatus.parsingOcr
                      ? null
                      : () {
                          AppFeedback.light();
                          context.read<IngestionBloc>().add(
                                FetchLmsCoursesEvent(
                                  platform: selectedPlatform.value,
                                  authToken: tokenController.text.trim(),
                                  canvasDomain: domainController.text.trim(),
                                ),
                              );
                        },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colors.primary,
                          colors.primary.withAlpha(200),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: colors.primary.withAlpha(60),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: state.status == ProcessingStatus.parsingOcr &&
                              state.lmsCourses.isEmpty
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Fetch Enrolled Courses',
                              style: typography.body.bold.copyWith(
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Loaded Courses List
                if (state.lmsCourses.isNotEmpty) ...[
                  Text(
                    'Available Courses (${state.lmsCourses.length})',
                    style: typography.callout.bold.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: state.lmsCourses.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final course = state.lmsCourses[index];
                      return _LmsCourseCard(
                        course: course,
                        isImporting:
                            state.status == ProcessingStatus.parsingOcr &&
                                state.selectedCourse?.id == course.id,
                        onImport: () {
                          AppFeedback.medium();
                          context.read<IngestionBloc>().add(
                                ImportLmsCourseEvent(
                                  platform: course.platform,
                                  courseId: course.id,
                                  authToken: tokenController.text.trim(),
                                  canvasDomain: domainController.text.trim(),
                                ),
                              );
                        },
                      );
                    },
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PlatformTab extends StatelessWidget {
  const _PlatformTab({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? colors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : colors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: typography.caption.bold.copyWith(
                color: isSelected ? Colors.white : colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LmsCourseCard extends StatelessWidget {
  const _LmsCourseCard({
    required this.course,
    required this.isImporting,
    required this.onImport,
  });

  final LmsCourse course;
  final bool isImporting;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceTertiary : colors.surfaceSecondary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colors.primary.withAlpha(isDark ? 50 : 25),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
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
          ShrinkableButton(
            onTap: isImporting ? null : onImport,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: isImporting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Import',
                      style: typography.caption.bold.copyWith(
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
