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
import 'package:kortex/src/features/ingestion/presentation/widgets/lms_oauth_dialog.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class LmsImportModalSheet extends HookWidget {
  const LmsImportModalSheet({super.key});

  static Future<void> show(BuildContext context) {
    final colors = context.colors;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.transparent,
      builder: (bottomSheetContext) => BlocProvider.value(
        value: context.read<IngestionBloc>(),
        child: const LmsImportModalSheet(),
      ),
    );
  }

  static const List<(String, String)> _institutionPresets = [
    ('canvas.instructure.com', 'Instructure Global Canvas'),
    ('canvas.harvard.edu', 'Harvard University'),
    ('bcourses.berkeley.edu', 'UC Berkeley (bCourses)'),
    ('canvas.ox.ac.uk', 'University of Oxford'),
    ('q.utoronto.ca', 'University of Toronto (Quercus)'),
    ('custom', 'Custom Institution URL...'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final selectedPlatform = useState<String>('google_classroom');
    final connectedAccount = useState<LmsOAuthResult?>(null);
    final selectedInstitution = useState<String>('canvas.instructure.com');
    final customDomainController = useTextEditingController(text: '');
    final isCustomDomain = selectedInstitution.value == 'custom';

    Future<void> launchOAuth() async {
      AppFeedback.light();
      final isCanvas = selectedPlatform.value == 'canvas';
      final domain = isCanvas
          ? (isCustomDomain
              ? customDomainController.text.trim()
              : selectedInstitution.value)
          : null;

      final result = await LmsOAuthDialog.show(
        context,
        platform: selectedPlatform.value,
        canvasDomain: domain,
      );

      if (result != null) {
        connectedAccount.value = result;
        if (context.mounted) {
          context.read<IngestionBloc>().add(
                FetchLmsCoursesEvent(
                  platform: result.platform,
                  authToken: result.accessToken,
                  canvasDomain: result.canvasDomain,
                ),
              );
        }
      }
    }

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
          final isAccountConnected = connectedAccount.value != null;

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
                            l10n.decksImportLmsTitle,
                            style: typography.title3.bold.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                          Text(
                            l10n.decksImportLmsSubtitle,
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
                            connectedAccount.value = null;
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
                            connectedAccount.value = null;
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Connected Account Card
                if (isAccountConnected) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.surfaceTertiary,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colors.success.withAlpha(70),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colors.success.withAlpha(20),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check_circle_rounded,
                            size: 20,
                            color: colors.success,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.lmsConnectedAsStudent(
                                  connectedAccount.value!.accountEmail,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: typography.caption.bold.copyWith(
                                  color: colors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isCanvas
                                    ? (connectedAccount.value!.canvasDomain ??
                                        'Canvas LMS')
                                    : 'Google Classroom SSO',
                                style: typography.caption.regular.copyWith(
                                  color: colors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ShrinkableButton(
                          onTap: () {
                            AppFeedback.light();
                            connectedAccount.value = null;
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: colors.surfaceSecondary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              l10n.lmsDisconnect,
                              style: typography.caption.medium.copyWith(
                                color: colors.error,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  // If Canvas: Institution Dropdown / Presets
                  if (isCanvas) ...[
                    Text(
                      l10n.lmsSelectInstitution,
                      style: typography.caption.bold.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? colors.surfaceTertiary
                            : colors.surfaceSecondary,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colors.surfaceBorder.withAlpha(100),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedInstitution.value,
                          isExpanded: true,
                          dropdownColor: isDark
                              ? colors.surfaceSecondary
                              : colors.surfacePrimary,
                          items: _institutionPresets.map((preset) {
                            return DropdownMenuItem<String>(
                              value: preset.$1,
                              child: Text(
                                preset.$2,
                                style: typography.caption.medium.copyWith(
                                  color: colors.textPrimary,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              selectedInstitution.value = val;
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (isCustomDomain) ...[
                      AppTextField(
                        controller: customDomainController,
                        label: l10n.lmsCustomDomain,
                        hintText: 'e.g. canvas.mycollege.edu',
                        prefixIcon:
                            const Icon(Icons.domain_rounded, size: 20),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],

                  // OAuth 2.0 Single Sign-On Button
                  ShrinkableButton(
                    onTap: state.status == ProcessingStatus.parsingOcr
                        ? null
                        : launchOAuth,
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
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isCanvas
                                ? Icons.view_sidebar_rounded
                                : Icons.class_rounded,
                            color: colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            isCanvas
                                ? l10n.lmsConnectWithCanvas
                                : l10n.lmsConnectWithGoogleClassroom,
                            style: typography.body.bold.copyWith(
                              color: colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // OAuth Security Disclaimer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 13,
                        color: colors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          l10n.lmsOAuthSecureNotice,
                          textAlign: TextAlign.center,
                          style: typography.caption.regular.copyWith(
                            color: colors.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // Loading Indicator while fetching courses
                if (state.status == ProcessingStatus.parsingOcr &&
                    state.lmsCourses.isEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: colors.primary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Loading enrolled courses...',
                            style: typography.caption.medium.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

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
                          final authToken =
                              connectedAccount.value?.accessToken ??
                                  'demo_oauth_token';
                          final domain =
                              connectedAccount.value?.canvasDomain ??
                                  selectedInstitution.value;

                          context.read<IngestionBloc>().add(
                                ImportLmsCourseEvent(
                                  platform: course.platform,
                                  courseId: course.id,
                                  authToken: authToken,
                                  canvasDomain: domain,
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
          color: isSelected ? colors.primary : colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? colors.white : colors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: typography.caption.bold.copyWith(
                color: isSelected ? colors.white : colors.textSecondary,
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
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.white,
                      ),
                    )
                  : Text(
                      'Import',
                      style: typography.caption.bold.copyWith(
                        color: colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
