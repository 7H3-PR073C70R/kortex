import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/domain/entities/course_track_entity.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_event.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_state.dart';
import 'package:kortex/src/features/auth/presentation/widgets/goal_calibration_slider.dart';
import 'package:kortex/src/features/dashboard/data/data_sources/dashboard_remote_data_source.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:kortex/src/features/decks/data/data_sources/decks_remote_data_source.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_event.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_dialog.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Subpage for calibrating active academic track, target exams, and goals.
class AcademicTrackSettingsPage extends HookWidget {
  const AcademicTrackSettingsPage({super.key});

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'school':
        return Icons.school_rounded;
      case 'timer':
        return Icons.timer_outlined;
      case 'calculate':
        return Icons.calculate_outlined;
      case 'biotech':
        return Icons.biotech_outlined;
      case 'medical_services':
        return Icons.medical_services_outlined;
      case 'gavel':
        return Icons.gavel_rounded;
      case 'engineering':
        return Icons.engineering_outlined;
      case 'trending_up':
        return Icons.trending_up_rounded;
      case 'menu_book':
        return Icons.menu_book_rounded;
      case 'terminal':
        return Icons.terminal_rounded;
      case 'record_voice_over':
        return Icons.record_voice_over_outlined;
      case 'translate':
        return Icons.translate_rounded;
      default:
        return Icons.auto_stories_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

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
          appBar: AppBar(
            backgroundColor: colors.backgroundPrimary,
            elevation: 0,
            scrolledUnderElevation: 0,
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
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Calibrate your academic focus, exam countdown, and '
                    'FSRS daily retention targets.',
                    style: typography.caption.regular.copyWith(
                      color: colors.textSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 1. Academic Focus Track Header & Interactive Selector Card
                  Text(
                    'Target Exam & Curriculum',
                    style: typography.body.bold.copyWith(
                      color: colors.textPrimary,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildInteractiveTrackCard(
                    context,
                    activeTrack,
                    selectedTrack,
                    colors,
                    typography,
                    isDark,
                  ),
                  const SizedBox(height: 24),

                  // 2. Daily Goal & Retention Benchmark
                  Text(
                    'Daily Review & Retention Goal',
                    style: typography.body.bold.copyWith(
                      color: colors.textPrimary,
                      fontSize: 14.5,
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

                  // 3. Save Changes Button
                  ShrinkableButton(
                    onTap: () {
                      AppFeedback.medium();
                      final currentTrack = currentProfile?.targetTrack ?? '';
                      final isTrackChanging = currentTrack.isNotEmpty &&
                          currentTrack.toUpperCase() !=
                              selectedTrack.value.toUpperCase();

                      if (isTrackChanging) {
                        unawaited(
                          AppDialog.show<void>(
                            context: context,
                            title: 'Switch Academic Track?',
                            description:
                                'Switching from "$currentTrack" to "${selectedTrack.value}" is destructive.\n\n'
                                'To keep your database clean and aligned with your new curriculum, all curated courses, study decks, flashcards, and uploaded documents associated with your previous track will be permanently deleted.',
                            primaryActionText: 'Switch & Reset Workspace',
                            isDestructive: true,
                            onPrimaryAction: () async {
                              AppFeedback.heavy();
                              // 1. Wipe previous track's curated courses
                              if (locator.isRegistered<DashboardRemoteDataSource>()) {
                                await locator<DashboardRemoteDataSource>()
                                    .deleteAllCuratedCourses();
                              }
                              // 2. Wipe previous track's study decks & flashcards
                              if (locator.isRegistered<DecksRemoteDataSource>()) {
                                await locator<DecksRemoteDataSource>()
                                    .deleteAllDecks();
                              }
                              // 3. Refresh DecksBloc
                              if (locator.isRegistered<DecksBloc>()) {
                                locator<DecksBloc>().add(const DecksRefreshed());
                              }
                              // 4. Update Profile in AuthBloc
                              if (context.mounted) {
                                context.read<AuthBloc>().add(
                                  AuthUpdateCourseTrackRequested(
                                    track: selectedTrack.value,
                                    dailyTarget: dailyTarget.value,
                                    retentionBenchmark: retentionBenchmark.value,
                                  ),
                                );
                                // 5. Refresh Dashboard Feed
                                if (locator.isRegistered<DashboardBloc>()) {
                                  locator<DashboardBloc>().add(const DashboardRefreshed());
                                }
                                context.showSnackBar(
                                  message:
                                      'Switched track to ${selectedTrack.value}. Previous track data cleared.',
                                );
                                Navigator.of(context).pop();
                              }
                            },
                            secondaryActionText: 'Cancel',
                          ),
                        );
                      } else {
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
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colors.primary,
                            colors.syllabotAccent,
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
                            color: colors.white,
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

  /// Single interactive Track card with tap-to-switch workflow
  Widget _buildInteractiveTrackCard(
    BuildContext context,
    CourseTrackEntity track,
    ValueNotifier<String> selectedTrack,
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
    bool isDark,
  ) {
    return ShrinkableButton(
      onTap: () => _openTrackSelectorSheet(
        context,
        selectedTrack,
        colors,
        typography,
        isDark,
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surfaceSecondary,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colors.primary.withAlpha(isDark ? 100 : 70),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.primary.withAlpha(isDark ? 30 : 15),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colors.primary,
                        colors.syllabotAccent,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getIconData(track.iconName),
                    color: colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              track.name,
                              style: typography.body.bold.copyWith(
                                color: colors.textPrimary,
                                fontSize: 15.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colors.primary.withAlpha(40),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              '~${track.examCountdownDays}d exam',
                              style: typography.caption.bold.copyWith(
                                color: colors.primary,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tap to change track (11 available)',
                        style: typography.caption.regular.copyWith(
                          color: colors.syllabotAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceTertiary,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: colors.surfaceBorder.withAlpha(80),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Change',
                        style: typography.caption.bold.copyWith(
                          color: colors.primary,
                          fontSize: 11.5,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: colors.primary,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              track.description,
              style: typography.caption.regular.copyWith(
                color: colors.textSecondary,
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Full searchable bottom sheet to select from all 11 tracks
  void _openTrackSelectorSheet(
    BuildContext context,
    ValueNotifier<String> selectedTrack,
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
    bool isDark,
  ) {
    AppFeedback.selection();
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: colors.transparent,
        builder: (ctx) {
          const tracks = CourseTrackEntity.defaultTracks;
          return Container(
            height: MediaQuery.of(ctx).size.height * 0.72,
            decoration: BoxDecoration(
              color: colors.surfacePrimary,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              border: Border.all(
                color: colors.surfaceBorder.withAlpha(80),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                // Handle bar
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.surfaceBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select Academic Track',
                        style: typography.title3.bold.copyWith(
                          color: colors.textPrimary,
                          fontSize: 17,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: colors.textSecondary,
                          size: 20,
                        ),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  color: colors.surfaceBorder.withAlpha(60),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    itemCount: tracks.length,
                    itemBuilder: (context, index) {
                      final track = tracks[index];
                      final isSelected = selectedTrack.value == track.id;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ShrinkableButton(
                          onTap: () {
                            AppFeedback.light();
                            selectedTrack.value = track.id;
                            Navigator.of(ctx).pop();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? colors.primary.withAlpha(isDark ? 40 : 20)
                                  : colors.surfaceSecondary,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? colors.primary
                                    : colors.surfaceBorder.withAlpha(60),
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: colors.primary.withAlpha(30),
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  child: Icon(
                                    _getIconData(track.iconName),
                                    color: colors.primary,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              track.name,
                                              style: typography.body.bold
                                                  .copyWith(
                                                    color: colors.textPrimary,
                                                    fontSize: 13.5,
                                                  ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 5,
                                              vertical: 1.5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: colors.surfaceTertiary,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '~${track.examCountdownDays}d',
                                              style: typography.caption.bold
                                                  .copyWith(
                                                    color: colors.textSecondary,
                                                    fontSize: 9.5,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        track.description,
                                        style: typography.caption.regular
                                            .copyWith(
                                              color: colors.textSecondary,
                                              fontSize: 11,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: colors.primary,
                                    size: 20,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
