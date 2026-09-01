import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/auth/domain/entities/course_track_entity.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_event.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_state.dart';
import 'package:kortex/src/features/auth/presentation/widgets/goal_calibration_slider.dart';
import 'package:kortex/src/features/auth/presentation/widgets/track_selector_card.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

@RoutePage()
class UserProfilePage extends HookWidget {
  const UserProfilePage({super.key});

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
        if (!state.isAuthenticated) {
          unawaited(context.router.replace(const LoginRoute()));
        } else if (state.userProfile != null) {
          selectedTrack.value = state.userProfile!.targetTrack;
          dailyTarget.value = state.userProfile!.dailyCardTarget;
          retentionBenchmark.value = state.userProfile!.retentionBenchmark;
        }
      },
      builder: (context, state) {
        final profile = state.userProfile;

        return Scaffold(
          backgroundColor:
              isDark ? colors.backgroundPrimary : colors.surfacePrimary,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(
              l10n.userProfileTitle,
              style: typography.title3.bold.copyWith(
                color: colors.textPrimary,
              ),
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User Avatar & Greeting Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark
                          ? colors.surfaceSecondary
                          : colors.surfacePrimary,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: colors.primary.withAlpha(isDark ? 40 : 20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(isDark ? 40 : 10),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: colors.primary.withAlpha(50),
                          child: Text(
                            (profile?.displayName?.isNotEmpty ?? false)
                                ? profile!.displayName![0].toUpperCase()
                                : 'K',
                            style: typography.title2.bold.copyWith(
                              color: colors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile?.displayName ??
                                    profile?.email ??
                                    'Kortexify Scholar',
                                style: typography.title3.bold.copyWith(
                                  color: colors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                profile?.email ?? '',
                                style: typography.footnote.regular.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Stats Row: Level & Streak
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark
                                ? colors.surfaceSecondary
                                : colors.surfacePrimary,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: colors.primary.withAlpha(30),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Rank Level',
                                style: typography.caption.medium.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Level ${profile?.level ?? 1}',
                                style: typography.title2.bold.copyWith(
                                  color: colors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark
                                ? colors.surfaceSecondary
                                : colors.surfacePrimary,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.orangeAccent.withAlpha(50),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Daily Streak',
                                style: typography.caption.medium.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${profile?.streakDays ?? 0} Days 🔥',
                                style: typography.title2.bold.copyWith(
                                  color: Colors.orangeAccent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Track Selection Header
                  Text(
                    l10n.editTrackAndGoals,
                    style: typography.headline.bold.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),

                  ...CourseTrackEntity.defaultTracks.map((track) {
                    final isSelected = selectedTrack.value == track.id;
                    return TrackSelectorCard(
                      track: track,
                      isSelected: isSelected,
                      onTap: () {
                        selectedTrack.value = track.id;
                      },
                    );
                  }),
                  const SizedBox(height: 16),

                  // Goal Slider
                  GoalCalibrationSlider(
                    dailyTarget: dailyTarget.value,
                    retentionBenchmark: retentionBenchmark.value,
                    onTargetChanged: (val) => dailyTarget.value = val,
                    onRetentionChanged: (val) =>
                        retentionBenchmark.value = val,
                  ),
                  const SizedBox(height: 24),

                  // Save Changes Button
                  ShrinkableButton(
                    onTap: () {
                      context.read<AuthBloc>().add(
                            AuthUpdateCourseTrackRequested(
                              track: selectedTrack.value,
                              dailyTarget: dailyTarget.value,
                              retentionBenchmark: retentionBenchmark.value,
                            ),
                          );

                      context.showSnackBar(
                        message: l10n.profileSavedSuccessNotice,
                      );
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
                      ),
                      child: Center(
                        child: Text(
                          l10n.saveChangesButton,
                          style: typography.body.bold.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Sign Out Button
                  Center(
                    child: TextButton.icon(
                      onPressed: () {
                        unawaited(
                          showDialog<void>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: isDark
                                  ? colors.surfaceSecondary
                                  : colors.surfacePrimary,
                              title: Text(
                                l10n.signOutButton,
                                style: typography.title3.bold.copyWith(
                                  color: colors.textPrimary,
                                ),
                              ),
                              content: Text(
                                l10n.signOutConfirmation,
                                style: typography.footnote.regular.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(),
                                  child: Text(l10n.cancelAction),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(ctx).pop();
                                    context
                                        .read<AuthBloc>()
                                        .add(const AuthSignOutRequested());
                                  },
                                  child: Text(
                                    l10n.signOutButton,
                                    style: TextStyle(color: colors.error),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      icon: Icon(
                        Icons.logout_rounded,
                        color: colors.error,
                        size: 18,
                      ),
                      label: Text(
                        l10n.signOutButton,
                        style: typography.footnote.bold.copyWith(
                          color: colors.error,
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
