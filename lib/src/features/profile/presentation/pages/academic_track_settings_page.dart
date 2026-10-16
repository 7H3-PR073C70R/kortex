import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/domain/entities/course_track_entity.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_event.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_state.dart';
import 'package:kortex/src/features/auth/presentation/widgets/goal_calibration_slider.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/profile/presentation/widgets/academic_track/academic_track_card.dart';
import 'package:kortex/src/features/profile/presentation/widgets/academic_track/save_track_button.dart';
import 'package:kortex/src/features/profile/presentation/widgets/academic_track/study_pace_shortcut_card.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_app_bar.dart';
import 'package:kortex/src/shared/widgets/app_breadcrumbs.dart';

/// Subpage for calibrating active academic track, target exams, and goals.
@RoutePage()
class AcademicTrackSettingsPage extends StatelessWidget {
  const AcademicTrackSettingsPage({
    this.authBloc,
    this.dashboardBloc,
    super.key,
  });

  final AuthBloc? authBloc;
  final DashboardBloc? dashboardBloc;

  @override
  Widget build(BuildContext context) {
    final effectiveAuthBloc = authBloc ??
        (locator.isRegistered<AuthBloc>() ? locator<AuthBloc>() : null);
    final effectiveDashboardBloc = dashboardBloc ??
        (locator.isRegistered<DashboardBloc>()
            ? locator<DashboardBloc>()
            : null);

    if (effectiveAuthBloc != null) {
      return BlocProvider<AuthBloc>.value(
        value: effectiveAuthBloc,
        child: _AcademicTrackSettingsView(dashboardBloc: effectiveDashboardBloc),
      );
    }
    return _AcademicTrackSettingsView(dashboardBloc: effectiveDashboardBloc);
  }
}

class _AcademicTrackSettingsView extends HookWidget {
  const _AcademicTrackSettingsView({this.dashboardBloc});

  final DashboardBloc? dashboardBloc;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    final currentProfile = context.read<AuthBloc>().state.userProfile;
    final selectedTrack = useState<String>(
      currentProfile?.targetTrack.isNotEmpty == true
          ? currentProfile!.targetTrack
          : 'WAEC',
    );
    final dailyTarget = useState<int>(
      currentProfile?.dailyCardTarget ?? 20,
    );
    final retentionBenchmark = useState<double>(
      currentProfile?.retentionBenchmark ?? 0.85,
    );

    useEffect(() {
      context.read<AuthBloc>().add(const AuthProfileFetchRequested());
      return null;
    }, const []);

    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state.userProfile != null) {
          selectedTrack.value = state.userProfile!.targetTrack;
          dailyTarget.value = state.userProfile!.dailyCardTarget;
          retentionBenchmark.value = state.userProfile!.retentionBenchmark;
        }
      },
      builder: (context, state) {
        const tracks = CourseTrackEntity.defaultTracks;
        final activeTrack = tracks.firstWhere(
          (t) => t.id == selectedTrack.value,
          orElse: () => tracks.first,
        );

        return Scaffold(
          backgroundColor: colors.backgroundPrimary,
          appBar: AppAdaptiveAppBar(
            backgroundColor: colors.backgroundPrimary,
            titleText: 'Academic Track & Goals',
            breadcrumbs: [
              AppBreadcrumbItem(
                label: 'Profile & Settings',
                onTap: () => context.router.maybePop(),
              ),
              const AppBreadcrumbItem(label: 'Academic Track & Goals'),
            ],
          ),
          body: SafeArea(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Calibrate your academic focus, exam countdown, and '
                      'daily memory retention targets.',
                      style: typography.caption.regular.copyWith(
                        color: colors.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // 1. Target Exam & Curriculum Hero Card
                    Padding(
                      padding: const EdgeInsets.only(left: 6, bottom: 8),
                      child: Text(
                        'TARGET EXAM & CURRICULUM',
                        style: typography.caption.bold.copyWith(
                          color: colors.textSecondary.withAlpha(170),
                          fontSize: 11,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    AcademicTrackCard(
                      track: activeTrack,
                      selectedTrack: selectedTrack,
                    ),
                    const SizedBox(height: 24),

                    // 2. Daily Goal & Retention Benchmark
                    Padding(
                      padding: const EdgeInsets.only(left: 6, bottom: 8),
                      child: Text(
                        'DAILY REVIEW & RETENTION GOAL',
                        style: typography.caption.bold.copyWith(
                          color: colors.textSecondary.withAlpha(170),
                          fontSize: 11,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    GoalCalibrationSlider(
                      dailyTarget: dailyTarget.value,
                      retentionBenchmark: retentionBenchmark.value,
                      onTargetChanged: (val) {
                        AppFeedback.selection();
                        dailyTarget.value = val;
                      },
                      onRetentionChanged: (val) {
                        AppFeedback.selection();
                        retentionBenchmark.value = val;
                      },
                    ),
                    const SizedBox(height: 20),

                    // 3. Advanced FSRS & Reminder Tuning Entry
                    Padding(
                      padding: const EdgeInsets.only(left: 6, bottom: 8),
                      child: Text(
                        'ADVANCED ALGORITHM & REMINDERS',
                        style: typography.caption.bold.copyWith(
                          color: colors.textSecondary.withAlpha(170),
                          fontSize: 11,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const StudyPaceShortcutCard(),
                    const SizedBox(height: 28),

                    // 4. Save Changes Button
                    SaveTrackButton(
                      selectedTrack: selectedTrack.value,
                      dailyTarget: dailyTarget.value,
                      retentionBenchmark: retentionBenchmark.value,
                      currentTrack: currentProfile?.targetTrack ?? '',
                      dashboardBloc: dashboardBloc,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
