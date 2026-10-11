import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/study_rooms/presentation/bloc/live_room_cubit.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Modal dialogs for setting and verifying micro-goals during live focus sessions.
abstract final class LiveStudyRoomGoalDialogs {
  /// Displays dialog allowing scholars to edit their current session micro-goal.
  static void showGoalEditDialog({
    required BuildContext context,
    required String? currentGoal,
  }) {
    final controller = TextEditingController(text: currentGoal ?? '');
    final colors = context.colors;
    final typography = context.typography;

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
              Text('🎯', style: context.typography.body.regular.copyWith(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                'Set Micro-Goal',
                style: typography.subhead.bold.copyWith(
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Define what you intend to finish during this silent focus session.',
                  style: typography.caption.regular.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  maxLines: 5,
                  minLines: 1,
                  style: typography.body.regular.copyWith(
                    color: colors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g. Review 15 flashcards',
                    hintStyle: typography.caption.regular.copyWith(
                      color: colors.textMuted,
                    ),
                    filled: true,
                    fillColor: colors.primary.withAlpha(20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colors.primary.withAlpha(50)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    'Review 15 flashcards',
                    'Deep Focus 25 mins',
                    'Master 10 concepts',
                    'Complete 1 Quiz',
                  ].map((preset) {
                    return ShrinkableButton(
                      onTap: () {
                        unawaited(HapticFeedback.selectionClick());
                        controller.text = preset;
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primary.withAlpha(15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: colors.primary.withAlpha(40),
                          ),
                        ),
                        child: Text(
                          preset,
                          style: typography.caption.bold.copyWith(
                            fontSize: 10.5,
                            color: colors.primary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
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
            ShrinkableButton(
              onTap: () {
                final goal = controller.text.trim();
                if (goal.isNotEmpty) {
                  context.read<LiveRoomCubit>().updateActiveGoal(goal);
                }
                Navigator.of(dialogCtx).pop();
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
                  'Save Goal',
                  style: typography.caption.bold.copyWith(color: colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Displays micro-goal reflection dialog upon focus completion.
  static void showGoalVerificationDialog({
    required BuildContext context,
    required String goal,
    VoidCallback? onAfterVerification,
  }) {
    final colors = context.colors;
    final typography = context.typography;
    final cubit = context.read<LiveRoomCubit>();

    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogCtx) => AlertDialog(
          backgroundColor: context.isDarkMode
              ? colors.surfaceSecondary
              : colors.surfacePrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Text('🎯', style: context.typography.body.regular.copyWith(fontSize: 22)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Micro-Goal Reflection',
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
                'Focus block completed! Did you finish your micro-goal?',
                style: typography.caption.regular.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.primary.withAlpha(50)),
                ),
                child: Text(
                  '"$goal"',
                  style: typography.body.bold.copyWith(color: colors.primary),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: colors.success.withAlpha(60)),
                ),
                tileColor: colors.success.withAlpha(
                  context.isDarkMode ? 30 : 15,
                ),
                leading: Icon(
                  Icons.check_circle_rounded,
                  color: colors.success,
                ),
                title: Text(
                  'Completed (100%)',
                  style: typography.caption.bold.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                subtitle: Text(
                  'Earn +50 Pod XP & celebrate with peers',
                  style: typography.caption.regular.copyWith(
                    color: colors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                onTap: () {
                  Navigator.of(dialogCtx).pop();
                  cubit.verifyMicroGoal(completed: true, goal: goal);
                  onAfterVerification?.call();
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: colors.warning.withAlpha(60)),
                ),
                tileColor: colors.warning.withAlpha(
                  context.isDarkMode ? 30 : 15,
                ),
                leading: Icon(
                  Icons.timelapse_rounded,
                  color: colors.warning,
                ),
                title: Text(
                  'Partially Finished',
                  style: typography.caption.bold.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                subtitle: Text(
                  'Good momentum! Roll over to next block',
                  style: typography.caption.regular.copyWith(
                    color: colors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                onTap: () {
                  Navigator.of(dialogCtx).pop();
                  cubit.verifyMicroGoal(completed: false, goal: goal);
                  onAfterVerification?.call();
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                cubit.dismissGoalVerification();
                onAfterVerification?.call();
              },
              child: Text(
                'Dismiss',
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
}
