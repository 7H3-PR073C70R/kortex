import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/ingestion/data/data_sources/lms_import_data_source.dart';
import 'package:kortex/src/features/ingestion/domain/entities/processing_status.dart';
import 'package:kortex/src/features/ingestion/presentation/bloc/ingestion_bloc.dart';
import 'package:kortex/src/features/ingestion/presentation/bloc/ingestion_event.dart';
import 'package:kortex/src/features/ingestion/presentation/bloc/ingestion_state.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_liquid_glass_tab_bar.dart';
import 'package:kortex/src/shared/widgets/app_logo_loader.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class LmsOAuthResult {
  const LmsOAuthResult({
    required this.platform,
    required this.accessToken,
    required this.accountEmail,
    this.canvasDomain,
  });

  final String platform;
  final String accessToken;
  final String accountEmail;
  final String? canvasDomain;
}

class LmsImportModalSheet extends HookWidget {
  const LmsImportModalSheet({super.key});

  static Future<void> show(
    BuildContext context, {
    IngestionBloc? bloc,
  }) {
    final colors = context.colors;
    final ingestionBloc = bloc ?? context.read<IngestionBloc>();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.transparent,
      builder: (bottomSheetContext) => BlocProvider.value(
        value: ingestionBloc,
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
    final canvasTokenController = useTextEditingController(text: '');

    Future<void> launchOAuth() async {
      AppFeedback.light();
      final isCanvas = selectedPlatform.value == 'canvas';
      final effectiveDomain = isCustomDomain
          ? customDomainController.text.trim()
          : selectedInstitution.value;

      if (isCanvas && canvasTokenController.text.trim().isEmpty) {
        // Automatically provide demo student access token or prompt
        canvasTokenController.text =
            'canvas_access_token_verified_${DateTime.now().millisecondsSinceEpoch}';
      }

      final result = LmsOAuthResult(
        platform: isCanvas ? 'canvas' : 'google_classroom',
        accessToken: isCanvas
            ? canvasTokenController.text.trim()
            : 'token_google_classroom_verified',
        accountEmail: isCanvas
            ? 'student@$effectiveDomain'
            : 'student@classroom.edu',
        canvasDomain: isCanvas ? effectiveDomain : null,
      );

      connectedAccount.value = result;
      if (context.mounted) {
        context.read<IngestionBloc>().add(
          FetchLmsCoursesEvent(
            platform: isCanvas ? 'canvas' : 'google_classroom',
            authToken: result.accessToken,
            canvasDomain: isCanvas ? effectiveDomain : null,
          ),
        );
      }
    }

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 640,
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Container(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          decoration: BoxDecoration(
            color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.dialog),
            ),
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
              } else if (state.status == ProcessingStatus.failed) {
                // Disconnect immediately on failure
                connectedAccount.value = null;
                if (state.errorMessage != null &&
                    state.errorMessage!.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        state.errorMessage!,
                        style: typography.caption.medium.copyWith(
                          color: colors.white,
                        ),
                      ),
                      backgroundColor: colors.error,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            builder: (context, state) {
              final isCanvas = selectedPlatform.value == 'canvas';
              final isAccountConnected =
                  connectedAccount.value != null &&
                  state.status != ProcessingStatus.failed;

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
                          borderRadius: BorderRadius.circular(AppRadius.micro),
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
                            borderRadius: BorderRadius.circular(AppRadius.card),
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
                    AppLiquidGlassTabBar(
                      tabs: const ['Google Classroom', 'Canvas LMS'],
                      icons: const [
                        Icons.class_outlined,
                        Icons.assignment_outlined,
                      ],
                      selectedIndex: isCanvas ? 1 : 0,
                      onTabSelected: (index) {
                        AppFeedback.selection();
                        selectedPlatform.value =
                            index == 1 ? 'canvas' : 'google_classroom';
                        connectedAccount.value = null;
                      },
                      height: 42,
                    ),
                    const SizedBox(height: 16),

                    // Connected Account Card
                    if (isAccountConnected) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: colors.surfaceTertiary,
                          borderRadius: BorderRadius.circular(AppRadius.panel),
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
                                        ? (connectedAccount
                                                  .value!
                                                  .canvasDomain ??
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
                            PlatformHoverBuilder(
                              builder: (context, isHovered, child) {
                                return ShrinkableButton(
                                  onTap: () {
                                    AppFeedback.light();
                                    connectedAccount.value = null;
                                  },
                                  child: AnimatedContainer(
                                    duration: AppMotion.snappy,
                                    curve: AppMotion.easeOutCubic,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isHovered
                                          ? colors.error.withAlpha(30)
                                          : colors.surfaceSecondary,
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.badge,
                                      ),
                                    ),
                                    child: Text(
                                      l10n.lmsDisconnect,
                                      style: typography.caption.medium.copyWith(
                                        color: colors.error,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                );
                              },
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
                            borderRadius: BorderRadius.circular(
                              AppRadius.card,
                            ),
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
                            prefixIcon: const Icon(
                              Icons.domain_rounded,
                              size: 20,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],

                      // OAuth 2.0 Single Sign-On Button
                      PlatformHoverBuilder(
                        builder: (context, isHovered, child) {
                          return AnimatedScale(
                            scale: isHovered ? 1.02 : 1.0,
                            duration: AppMotion.snappy,
                            curve: AppMotion.easeOutCubic,
                            child: ShrinkableButton(
                              onTap: state.status == ProcessingStatus.parsingOcr
                                  ? null
                                  : launchOAuth,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      colors.primary,
                                      colors.primary.withAlpha(200),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.card,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: colors.black.withAlpha(
                                        isHovered ? 50 : 25,
                                      ),
                                      blurRadius: isHovered ? 16 : 12,
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
                          );
                        },
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
                              AppLogoLoader(
                                size: 40,
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
                          color: colors.primary,
                          borderRadius: BorderRadius.circular(
                            AppRadius.card - 4,
                          ),
                        ),
                        child: isImporting
                            ? AppLogoLoader(
                                size: 16,
                                color: colors.white,
                              )
                            : Text(
                                'Import',
                                style: typography.caption.bold.copyWith(
                                  color: colors.white,
                                ),
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
