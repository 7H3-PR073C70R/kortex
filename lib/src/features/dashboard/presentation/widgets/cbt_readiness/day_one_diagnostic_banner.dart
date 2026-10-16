import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/analytics_service.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/core/utils/app_logger.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/quiz/domain/repositories/past_questions_repository.dart';
import 'package:kortex/src/features/quiz/domain/services/day_one_diagnostic_service.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_session_state.dart';
import 'package:kortex/src/shared/widgets/app_logo_loader.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Executive Day-One Diagnostic Banner displayed when a student's CBT readiness
/// is pending calibration or when zero activity is recorded on their primary exam track.
class DayOneDiagnosticBanner extends StatefulWidget {
  const DayOneDiagnosticBanner({
    this.targetTrack,
    this.registeredSubjectNames = const [],
    this.dayOneDiagnosticService,
    this.pastQuestionsRepository,
    this.analyticsService,
    this.onStartDiagnostic,
    this.onDismiss,
    super.key,
  });

  final String? targetTrack;
  final List<String> registeredSubjectNames;
  final DayOneDiagnosticService? dayOneDiagnosticService;
  final PastQuestionsRepository? pastQuestionsRepository;
  final AnalyticsService? analyticsService;
  final Future<void> Function()? onStartDiagnostic;
  final VoidCallback? onDismiss;

  @override
  State<DayOneDiagnosticBanner> createState() => _DayOneDiagnosticBannerState();
}

class _DayOneDiagnosticBannerState extends State<DayOneDiagnosticBanner> {
  bool _isLoading = false;

  Future<void> _handleStartDiagnostic() async {
    if (_isLoading) return;
    AppFeedback.selection();

    if (widget.onStartDiagnostic != null) {
      setState(() => _isLoading = true);
      try {
        await widget.onStartDiagnostic!();
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final service = widget.dayOneDiagnosticService ??
          DayOneDiagnosticService(
            pastQuestionsRepository: widget.pastQuestionsRepository,
          );

      final trackName = (widget.targetTrack != null && widget.targetTrack!.trim().isNotEmpty)
          ? widget.targetTrack!.trim()
          : 'Standardized CBT';

      final questions = await service.generateDiagnosticQuestions(
        trackOrExamName: trackName,
        registeredSubjectNames: widget.registeredSubjectNames,
      );

      try {
        final analytics = widget.analyticsService ??
            (locator.isRegistered<AnalyticsService>()
                ? locator<AnalyticsService>()
                : null);
        if (analytics != null) {
          unawaited(
            analytics.logCbtDiagnosticStarted(
              trackOrExamName: trackName,
              questionCount: questions.length,
            ),
          );
        }
      } on Object catch (e, st) {
        AppLogger.recordNonFatal(e, st);
      }

      if (!mounted) return;

      final trackSlug = trackName.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '_');

      await context.router.push(
        QuizWorkspaceRoute(
          deckId: 'day_one_diagnostic_$trackSlug',
          deckTitle: '$trackName Day-One Diagnostic',
          subject: trackName,
          durationMinutes: 10,
          assessmentMode: AssessmentMode.examSimulationMode,
          initialQuestions: questions,
        ),
      );
    } on Object catch (e, st) {
      AppLogger.recordNonFatal(e, st);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final effectiveTrack = (widget.targetTrack != null && widget.targetTrack!.trim().isNotEmpty)
        ? widget.targetTrack!.trim()
        : 'CBT Track';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.primary.withAlpha(isDark ? 45 : 22),
            colors.syllabotAccent.withAlpha(isDark ? 30 : 15),
            (isDark ? colors.surfaceSecondary : colors.surfacePrimary).withAlpha(240),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.panel),
        border: Border.all(
          color: colors.primary.withAlpha(isDark ? 100 : 70),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withAlpha(isDark ? 30 : 12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Badge & Dismiss
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.primary.withAlpha(35),
                  borderRadius: BorderRadius.circular(AppRadius.badge),
                  border: Border.all(
                    color: colors.primary.withAlpha(120),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 13,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'DAY-ONE DIAGNOSTIC',
                      style: typography.caption.bold.copyWith(
                        color: colors.primary,
                        fontSize: 10.5,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (widget.onDismiss != null)
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: colors.textSecondary,
                  ),
                  tooltip: 'Dismiss',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: widget.onDismiss,
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Title & Description
          Text(
            'Calibrate Your $effectiveTrack Readiness',
            style: typography.title3.bold.copyWith(
              color: colors.textPrimary,
              fontSize: 17,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Complete this streamlined 15-question baseline exam to unlock your personalized projected score, subject mastery breakdown, and psychometric pacing.',
            style: typography.footnote.regular.copyWith(
              color: colors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),

          // Metadata Pills Row
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildMetaPill(
                icon: Icons.timer_outlined,
                label: '10 Mins',
                colors: colors,
                typography: typography,
              ),
              _buildMetaPill(
                icon: Icons.format_list_numbered_rounded,
                label: '15 Questions',
                colors: colors,
                typography: typography,
              ),
              _buildMetaPill(
                icon: Icons.analytics_outlined,
                label: 'Instant Projected Score',
                colors: colors,
                typography: typography,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Primary CTA Button
          ShrinkableButton(
            onTap: _isLoading ? null : _handleStartDiagnostic,
            child: Container(
              width: double.infinity,
              height: 46,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colors.primary,
                    colors.primary.withAlpha(220),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppRadius.card),
                boxShadow: [
                  BoxShadow(
                    color: colors.primary.withAlpha(isDark ? 90 : 60),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: _isLoading
                  ? AppLogoLoader(
                      size: 20,
                      color: colors.white,
                      showMessage: false,
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.play_arrow_rounded,
                          size: 20,
                          color: colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Start 10-Minute Diagnostic',
                          style: typography.callout.bold.copyWith(
                            color: colors.white,
                            fontSize: 14.5,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaPill({
    required IconData icon,
    required String label,
    required AppThemeColorsExtension colors,
    required TypographyThemeExtension typography,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: colors.surfacePrimary.withAlpha(160),
        borderRadius: BorderRadius.circular(AppRadius.badge),
        border: Border.all(
          color: colors.surfaceBorder.withAlpha(100),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: colors.textSecondary,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: typography.caption.semiBold.copyWith(
              color: colors.textSecondary,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}
