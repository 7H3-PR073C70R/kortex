import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/study_activity_tracker.dart';
import 'package:kortex/src/features/study_rooms/presentation/bloc/live_room_cubit.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/focus_session_summary_sheet.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/live_study_room_goal_dialogs.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';
import 'package:permission_handler/permission_handler.dart';

export 'package:kortex/src/features/study_rooms/presentation/widgets/live_study_room_goal_dialogs.dart';

/// Static dialog and bottom sheet handlers for LiveStudyRoom.
abstract final class LiveStudyRoomDialogs {
  /// Shows modal sheet summarizing completed Pomodoros, cards reviewed, and goals.
  static void showSummarySheet({
    required BuildContext context,
    required LiveRoomState state,
    StudyActivityTracker? activityTracker,
    VoidCallback? onDone,
  }) {
    final totalFocusSeconds =
        state.completedPomodoros * state.room.pomodoroDurationMinutes * 60;
    if (totalFocusSeconds >= 15 && activityTracker != null) {
      unawaited(
        activityTracker.recordActivityCompletion(
          durationSeconds: totalFocusSeconds,
          activityType: 'live_room',
          metadata: {
            'roomTitle': state.room.title,
            'subject': state.room.subject,
          },
        ),
      );
    }
    unawaited(
      FocusSessionSummarySheet.show(
        context,
        roomTitle: state.room.title,
        subject: state.room.subject,
        completedPomodoros: state.completedPomodoros,
        pomodoroDurationMinutes: state.room.pomodoroDurationMinutes,
        cardsReviewed: state.cardsReviewedInSprint,
        activeGoal: state.activeGoal,
        isGoalAchieved: state.isGoalAchieved,
        onDone: onDone ?? () => Navigator.of(context).pop(),
      ),
    );
  }

  /// Displays dialog allowing scholars to edit their current session micro-goal.
  static void showGoalEditDialog({
    required BuildContext context,
    required String? currentGoal,
  }) =>
      LiveStudyRoomGoalDialogs.showGoalEditDialog(
        context: context,
        currentGoal: currentGoal,
      );

  /// Displays dialog allowing the room host/participant to launch a Co-Op study sprint.
  static void showStartCoOpSprintDialog({required BuildContext context}) {
    final colors = context.colors;
    final typography = context.typography;
    final cubit = context.read<LiveRoomCubit>();

    unawaited(
      showDialog<void>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          backgroundColor: context.isDarkMode
              ? colors.surfaceSecondary
              : colors.surfacePrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Text('⚡', style: context.typography.body.regular.copyWith(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                'Launch Co-Op Sprint',
                style: typography.subhead.bold.copyWith(
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rally everyone in this room for a synchronized 3-minute study sprint! All members review concurrently and earn Pod XP.',
                style: typography.caption.regular.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: colors.warning.withAlpha(50)),
                ),
                tileColor: colors.primary.withAlpha(
                  context.isDarkMode ? 30 : 15,
                ),
                leading: Icon(
                  Icons.flash_on_rounded,
                  color: colors.warning,
                ),
                title: Text(
                  '10-Card Sprint (3 min)',
                  style: typography.caption.bold.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                subtitle: Text(
                  'Fast-paced rapid recall challenge',
                  style: typography.caption.regular.copyWith(
                    color: colors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                onTap: () {
                  Navigator.of(dialogCtx).pop();
                  cubit.startCoOpSprint(deckTitle: 'Rapid Flashcard Sprint');
                },
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: colors.syllabotAccent.withAlpha(50)),
                ),
                tileColor: colors.syllabotAccent.withAlpha(
                  context.isDarkMode ? 30 : 15,
                ),
                leading: Icon(Icons.quiz_rounded, color: colors.latexHighlight),
                title: Text(
                  'Past Questions Battle (5 min)',
                  style: typography.caption.bold.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                subtitle: Text(
                  'Review 15 CBT past questions together',
                  style: typography.caption.regular.copyWith(
                    color: colors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                onTap: () {
                  Navigator.of(dialogCtx).pop();
                  cubit.startCoOpSprint(
                    deckTitle: 'CBT Past Questions Sprint',
                    targetCards: 15,
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text(
                'Cancel',
                style: typography.body.medium.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Displays microphone permission explanation and action dialog.
  static void showMicrophonePermissionDialog({
    required BuildContext context,
    required bool isPermanentlyDenied,
  }) {
    final colors = context.colors;
    final typography = context.typography;
    final cubit = context.read<LiveRoomCubit>();

    unawaited(
      showDialog<void>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          backgroundColor: context.isDarkMode
              ? colors.surfaceSecondary
              : colors.surfacePrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.error.withAlpha(context.isDarkMode ? 40 : 25),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.mic_off_rounded,
                  color: colors.error,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Microphone Access',
                  style: typography.subhead.bold.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isPermanentlyDenied
                    ? 'Microphone access is disabled in device settings. To speak and collaborate with your study pod, please enable Microphone permission in Settings.'
                    : 'Kortex needs microphone permission so your study pod can hear you when speaking.',
                style: typography.body.regular.copyWith(
                  color: colors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.primary.withAlpha(context.isDarkMode ? 25 : 15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: colors.primary.withAlpha(40),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 16,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your microphone is only streamed when unmuted in live pods.',
                        style: typography.caption.regular.copyWith(
                          color: colors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                cubit.dismissMicPermissionPrompt();
              },
              child: Text(
                'Stay Muted',
                style: typography.caption.medium.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
            ShrinkableButton(
              onTap: () async {
                Navigator.of(dialogCtx).pop();
                cubit.dismissMicPermissionPrompt();
                if (isPermanentlyDenied) {
                  await cubit.openAppSettingsForMic();
                } else {
                  final status = await Permission.microphone.request();
                  if (status.isGranted && context.mounted) {
                    await cubit.toggleMicMute();
                  } else if (status.isPermanentlyDenied && context.mounted) {
                    showMicrophonePermissionDialog(
                      context: context,
                      isPermanentlyDenied: true,
                    );
                  }
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isPermanentlyDenied ? 'Open Settings' : 'Grant Permission',
                  style: typography.caption.bold.copyWith(color: colors.white),
                ),
              ),
            ),
          ],
        ),
      ).then((_) => cubit.dismissMicPermissionPrompt()),
    );
  }

  /// Displays micro-goal reflection dialog upon focus completion.
  static void showGoalVerificationDialog({
    required BuildContext context,
    required String goal,
    VoidCallback? onAfterVerification,
  }) =>
      LiveStudyRoomGoalDialogs.showGoalVerificationDialog(
        context: context,
        goal: goal,
        onAfterVerification: onAfterVerification,
      );

  /// Displays host concluded study session notice.
  static void showRoomEndedByHostDialog({
    required BuildContext context,
    required VoidCallback onConfirm,
  }) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogCtx) => AlertDialog(
          backgroundColor:
              isDark ? colors.surfaceSecondary : colors.surfacePrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.flag_rounded, color: colors.primary, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Study Session Concluded',
                  style: typography.subhead.bold.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'The host has concluded this live focus session for everyone. Great work studying today!',
            style: typography.caption.regular.copyWith(
              color: colors.textSecondary,
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                onConfirm();
              },
              child: const Text('View Session Summary'),
            ),
          ],
        ),
      ),
    );
  }

  /// Displays confirmation dialog when exiting or ending the study room.
  static void showExitConfirmationDialog({
    required BuildContext context,
    required bool isHost,
    required VoidCallback onLeaveOnly,
    required Future<void> Function() onEndForEveryone,
  }) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    unawaited(
      showDialog<void>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          backgroundColor:
              isDark ? colors.surfaceSecondary : colors.surfacePrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                isHost
                    ? Icons.power_settings_new_rounded
                    : Icons.directions_run_rounded,
                color: colors.error,
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isHost ? 'End Study Room Session?' : 'Leave Study Room?',
                  style: typography.subhead.bold.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            isHost
                ? 'You are the host of this study room. Ending the room will conclude the session for all participants. Would you like to end the session for everyone or leave?'
                : 'Are you sure you want to leave this study session? Your active presence and progress will be saved.',
            style: typography.caption.regular.copyWith(
              color: colors.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text(
                'Cancel',
                style: typography.body.regular.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
            if (isHost)
              TextButton(
                onPressed: () {
                  Navigator.of(dialogCtx).pop();
                  onLeaveOnly();
                },
                child: Text(
                  'Leave Only',
                  style: typography.body.regular.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                Navigator.of(dialogCtx).pop();
                await onEndForEveryone();
              },
              child: Text(isHost ? 'End for Everyone' : 'Leave Room'),
            ),
          ],
        ),
      ),
    );
  }
}
