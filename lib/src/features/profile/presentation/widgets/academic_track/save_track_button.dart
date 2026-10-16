import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_event.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_dialog.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Primary Save Changes button for AcademicTrackSettingsPage with track-switch confirmation.
class SaveTrackButton extends StatelessWidget {
  const SaveTrackButton({
    required this.selectedTrack,
    required this.dailyTarget,
    required this.retentionBenchmark,
    required this.currentTrack,
    this.dashboardBloc,
    super.key,
  });

  final String selectedTrack;
  final int dailyTarget;
  final double retentionBenchmark;
  final String currentTrack;
  final DashboardBloc? dashboardBloc;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    return PlatformHoverBuilder(
      builder: (context, isHovered, child) {
        return AnimatedScale(
          scale: isHovered ? 1.01 : 1.0,
          duration: AppMotion.snappy,
          curve: Curves.easeOutCubic,
          child: child,
        );
      },
      child: ShrinkableButton(
        onTap: () {
          AppFeedback.medium();
          final isTrackChanging = currentTrack.isNotEmpty &&
              currentTrack.toUpperCase() != selectedTrack.toUpperCase();

          if (isTrackChanging) {
            unawaited(
              AppDialog.show<void>(
                context: context,
                title: 'Switch Academic Track?',
                description:
                    'Switching your primary focus to "$selectedTrack".\n\n'
                    'Your historical study logs, flashcard decks, and day streak will be fully preserved.',
                primaryActionText: 'Switch Track',
                onPrimaryAction: () async {
                  AppFeedback.medium();
                  if (context.mounted) {
                    context.read<AuthBloc>().add(
                          AuthUpdateCourseTrackRequested(
                            track: selectedTrack,
                            dailyTarget: dailyTarget,
                            retentionBenchmark: retentionBenchmark,
                          ),
                        );
                    dashboardBloc?.add(const DashboardRefreshed());
                    context.showSnackBar(
                      message:
                          'Switched academic track to $selectedTrack. Study history preserved!',
                      type: SnackBarType.success,
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
                    track: selectedTrack,
                    dailyTarget: dailyTarget,
                    retentionBenchmark: retentionBenchmark,
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
            color: colors.primary,
            borderRadius: AppRadius.radiusPanel,
            boxShadow: [
              BoxShadow(
                color: colors.black.withAlpha(isDark ? 60 : 25),
                blurRadius: 10,
                offset: const Offset(0, 3),
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
    );
  }
}
