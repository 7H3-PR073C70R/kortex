import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/features/auth/domain/entities/course_track_entity.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_event.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_state.dart';
import 'package:kortex/src/features/auth/presentation/widgets/goal_calibration_slider.dart';
import 'package:kortex/src/features/auth/presentation/widgets/track_selector_card.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Subpage for calibrating active academic track, target exams, and goals.
class AcademicTrackSettingsPage extends HookWidget {
  const AcademicTrackSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final selectedTrack = useState<String>('WAEC');
    final dailyTarget = useState<int>(20);
    final retentionBenchmark = useState<double>(0.85);

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
        return Scaffold(
          backgroundColor: colors.backgroundPrimary,
          appBar: AppBar(
            backgroundColor: colors.backgroundPrimary,
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: colors.textPrimary,
                size: 18,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              'Academic Track & Goals',
              style: typography.title3.bold.copyWith(
                color: colors.textPrimary,
                fontSize: 18,
              ),
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select your target academic exam to tailor AI flashcards '
                    'and study syllabi.',
                    style: typography.caption.regular.copyWith(
                      color: colors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Track Cards
                  ...CourseTrackEntity.defaultTracks.map((track) {
                    final isSelected = selectedTrack.value == track.id;
                    return TrackSelectorCard(
                      track: track,
                      isSelected: isSelected,
                      onTap: () {
                        AppFeedback.selection();
                        selectedTrack.value = track.id;
                      },
                    );
                  }),
                  const SizedBox(height: 20),

                  // Daily Goal & Retention Benchmark
                  Text(
                    'Daily Review & Retention Goal',
                    style: typography.body.bold.copyWith(
                      color: colors.textPrimary,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 28),

                  // Save Changes
                  ShrinkableButton(
                    onTap: () {
                      AppFeedback.medium();
                      context.read<AuthBloc>().add(
                            AuthUpdateCourseTrackRequested(
                              track: selectedTrack.value,
                              dailyTarget: dailyTarget.value,
                              retentionBenchmark: retentionBenchmark.value,
                            ),
                          );

                      context.showSnackBar(
                        message: l10n.profileSavedSuccessNotice,
                        type: SnackBarType.success,
                      );
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colors.primary,
                            colors.primary.withAlpha(220),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: colors.primary.withAlpha(isDark ? 80 : 40),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          l10n.saveChangesButton,
                          style: typography.body.bold.copyWith(
                            color: Colors.white,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
