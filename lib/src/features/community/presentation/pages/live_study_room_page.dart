import 'dart:async';
import 'dart:math' as math;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/data/client/ephemeral_presence_client.dart';
import 'package:kortex/src/features/community/domain/entities/study_room_entity.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';
import 'package:kortex/src/features/community/domain/repositories/ephemeral_room_repository.dart';
import 'package:kortex/src/features/community/domain/services/livekit_audio_service.dart';
import 'package:kortex/src/features/community/presentation/bloc/live_room_cubit.dart';
import 'package:kortex/src/features/community/presentation/widgets/floating_reaction_overlay.dart';
import 'package:kortex/src/features/community/presentation/widgets/focus_session_summary_sheet.dart';
import 'package:kortex/src/features/community/presentation/widgets/in_room_deck_picker_modal.dart';
import 'package:kortex/src/features/community/presentation/widgets/in_room_deck_study_workspace.dart';
import 'package:kortex/src/features/community/presentation/widgets/room_chat_drawer.dart';
import 'package:kortex/src/features/community/presentation/widgets/whiteboard_canvas_widget.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_avatar.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';
import 'package:permission_handler/permission_handler.dart';

@RoutePage()
class LiveStudyRoomPage extends StatelessWidget {
  const LiveStudyRoomPage({
    required this.room,
    super.key,
  });

  final StudyRoomEntity room;

  @override
  Widget build(BuildContext context) {
    final userStorage = locator<UserStorageService>();
    final currentUserId = userStorage.getUserId() ?? 'user_local';
    final currentUserName = userStorage.getUserDisplayName() ?? 'Scholar';
    return BlocProvider<LiveRoomCubit>(
      create: (_) => LiveRoomCubit(
        initialRoom: room,
        repository: locator<CommunityRepository>(),
        ephemeralRepository: locator<EphemeralRoomRepository>(),
        audioService: locator.isRegistered<LiveKitAudioService>()
            ? locator<LiveKitAudioService>()
            : null,
        currentUserId: currentUserId,
        currentUserName: currentUserName,
        currentUserAvatar: userStorage.getUserAvatarUrl() ?? '',
      ),
      child: _LiveStudyRoomView(
        currentUserId: currentUserId,
        currentUserName: currentUserName,
      ),
    );
  }
}

class _LiveStudyRoomView extends StatefulWidget {
  const _LiveStudyRoomView({
    required this.currentUserId,
    required this.currentUserName,
  });

  final String currentUserId;
  final String currentUserName;

  @override
  State<_LiveStudyRoomView> createState() => _LiveStudyRoomViewState();
}

class _LiveStudyRoomViewState extends State<_LiveStudyRoomView>
    with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final Set<String> _announcedHandRaises = {};
  final FloatingReactionController _reactionController =
      FloatingReactionController();
  String? _lastReaction;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final currentGoal = context.read<LiveRoomCubit>().state.activeGoal;
      if (currentGoal == null || currentGoal.trim().isEmpty) {
        _showGoalEditDialog(context, null);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!mounted) return;
    final isAway =
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden;
    unawaited(context.read<LiveRoomCubit>().setLocalAwayState(isAway: isAway));
  }

  void _showGoalVerificationDialog(
    BuildContext context,
    String goal, {
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

  void _handleExit(BuildContext context) {
    final cubit = context.read<LiveRoomCubit>();
    final state = cubit.state;

    final hasStudyActivity =
        state.completedPomodoros > 0 || state.cardsReviewedInSprint > 0;

    if (state.activeGoal != null &&
        state.activeGoal!.trim().isNotEmpty &&
        !state.isGoalAchieved) {
      _showGoalVerificationDialog(
        context,
        state.activeGoal!,
        onAfterVerification: () {
          final updatedState = cubit.state;
          final updatedHasActivity =
              updatedState.completedPomodoros > 0 ||
              updatedState.cardsReviewedInSprint > 0;
          if (updatedHasActivity) {
            _showSummarySheet(context, updatedState);
          } else {
            Navigator.of(context).pop();
          }
        },
      );
      return;
    }

    if (hasStudyActivity) {
      _showSummarySheet(context, state);
    } else {
      Navigator.of(context).pop();
    }
  }

  void _showSummarySheet(BuildContext context, LiveRoomState state) {
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
        onDone: () => Navigator.of(context).pop(),
      ),
    );
  }

  void _showGoalEditDialog(BuildContext context, String? currentGoal) {
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
          content: Column(
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
                children:
                    [
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

  void _showStartCoOpSprintDialog(BuildContext context) {
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
                  side: BorderSide(color: colors.primary.withAlpha(50)),
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

  void _showMicrophonePermissionDialog(
    BuildContext context, {
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
                  await openAppSettings();
                } else {
                  final status = await Permission.microphone.request();
                  if (status.isGranted && context.mounted) {
                    await cubit.toggleMicMute();
                  } else if (status.isPermanentlyDenied && context.mounted) {
                    _showMicrophonePermissionDialog(
                      context,
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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    return BlocConsumer<LiveRoomCubit, LiveRoomState>(
      listener: (context, state) {
        if (state.lastReactionEmoji != null &&
            state.lastReactionEmoji != _lastReaction) {
          _lastReaction = state.lastReactionEmoji;
          _reactionController.spawn(state.lastReactionEmoji!);
        }

        for (final p in state.ephemeralParticipants) {
          if (p.isHandRaised &&
              p.userId != widget.currentUserId &&
              !_announcedHandRaises.contains(p.userId)) {
            _announcedHandRaises.add(p.userId);
            context.showSnackBar(
              message: l10n.handRaisedNotice(p.displayName),
            );
          } else if (!p.isHandRaised) {
            _announcedHandRaises.remove(p.userId);
          }
        }

        if (state.showGoalVerificationModal &&
            state.activeGoal != null &&
            state.activeGoal!.trim().isNotEmpty) {
          _showGoalVerificationDialog(context, state.activeGoal!);
        }

        if (state.microphonePermissionDenied) {
          _showMicrophonePermissionDialog(
            context,
            isPermanentlyDenied: state.isPermanentlyDeniedMic,
          );
        }
      },
      builder: (context, state) {
        final audience = state.ephemeralParticipants
            .where((p) => !p.isHandRaised)
            .toList();

        final hasEphemeral = state.ephemeralParticipants.isNotEmpty;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            _handleExit(context);
          },
          child: FloatingReactionOverlay(
            controller: _reactionController,
            child: Scaffold(
              key: _scaffoldKey,
              backgroundColor: isDark
                  ? colors.backgroundPrimary
                  : colors.surfacePrimary,
              drawer: _RoomControlDrawer(
                state: state,
                currentUserId: widget.currentUserId,
                currentUserName: widget.currentUserName,
                colors: colors,
                typography: typography,
                isDark: isDark,
                l10n: l10n,
                onEditGoal: () =>
                    _showGoalEditDialog(context, state.activeGoal),
                onOpenDeckPicker: () => InRoomDeckPickerModal.show(context),
                onLaunchSprint: () => _showStartCoOpSprintDialog(context),
                onLeaveRoom: () => _handleExit(context),
              ),
              appBar: AppBar(
                backgroundColor: colors.transparent,
                elevation: 0,
                leading: Builder(
                  builder: (drawerCtx) => IconButton(
                    icon: Icon(
                      Icons.tune_rounded,
                      color: colors.textPrimary,
                      size: 22,
                    ),
                    tooltip: 'Room Tools & Audio',
                    onPressed: () => Scaffold.of(drawerCtx).openDrawer(),
                  ),
                ),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.room.title,
                      style: typography.headline.bold.copyWith(
                        color: colors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      state.room.subject,
                      style: typography.caption.regular.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
                actions: [
                  _LivePulseBadge(colors: colors),
                  const SizedBox(width: 6),
                  _PomodoroMiniPill(
                    state: state,
                    colors: colors,
                    typography: typography,
                  ),
                  const SizedBox(width: 4),
                  // Chat trigger with unread badge
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.forum_rounded,
                          color: colors.textPrimary,
                          size: 21,
                        ),
                        tooltip: 'Room Discussion',
                        onPressed: () => RoomChatDrawer.show(
                          context,
                          currentUserId: widget.currentUserId,
                        ),
                      ),
                      if (state.unreadChatCount > 0)
                        Positioned(
                          right: 6,
                          top: 6,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: colors.error,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Center(
                              child: Text(
                                '${state.unreadChatCount}',
                                style: typography.caption.bold.copyWith(
                                  color: colors.white,
                                  fontSize: 9,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.logout_rounded,
                      color: colors.error.withAlpha(220),
                      size: 20,
                    ),
                    tooltip: 'Leave Room',
                    onPressed: () => _handleExit(context),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              body: SafeArea(
                child: Column(
                  children: [
                    if (state.isCoOpSprintActive) ...[
                      const SizedBox(height: 4),
                      _CoOpSprintBanner(
                        state: state,
                        isDark: isDark,
                      ),
                    ],
                    if (state.activeSpeakerIds.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _ActiveSpeakersBanner(
                        speakerIds: state.activeSpeakerIds,
                        participants: state.ephemeralParticipants,
                        isDark: isDark,
                      ),
                    ],
                    const SizedBox(height: 4),

                    // Compact In-Room View Mode Switcher
                    _InRoomModeSwitcherBar(
                      activeMode: state.activeViewMode,
                      onSelectMode: (mode) =>
                          context.read<LiveRoomCubit>().switchViewMode(mode),
                      isDark: isDark,
                      cardsReviewed: state.cardsReviewedInSprint,
                    ),
                    const SizedBox(height: 4),

                    // Main maximized workspace
                    Expanded(
                      child: state.activeViewMode == RoomViewMode.deckStudy
                          ? InRoomDeckStudyWorkspace(roomState: state)
                          : state.activeViewMode == RoomViewMode.whiteboard
                          ? WhiteboardCanvasWidget(
                              strokes: state.whiteboardStrokes,
                              canUndo: state.whiteboardStrokes.any(
                                (s) => s.userId == widget.currentUserId,
                              ),
                              canRedo: state.whiteboardRedoStack.isNotEmpty,
                              isDark: isDark,
                              currentUserId: widget.currentUserId,
                              currentUserName: widget.currentUserName,
                              onStrokeDrawn: (stroke) {
                                context
                                    .read<LiveRoomCubit>()
                                    .addWhiteboardStroke(
                                      stroke,
                                    );
                              },
                              onUndo: () => context
                                  .read<LiveRoomCubit>()
                                  .undoWhiteboardStroke(),
                              onRedo: () => context
                                  .read<LiveRoomCubit>()
                                  .redoWhiteboardStroke(),
                              onClear: () => context
                                  .read<LiveRoomCubit>()
                                  .clearWhiteboard(),
                            )
                          : Column(
                              children: [
                                // Silent Focus Cockpit: Body-doubling flow state
                                Expanded(
                                  flex: 5,
                                  child: _FocusCockpitSection(
                                    participants: state.ephemeralParticipants,
                                    activeSpeakerIds: state.activeSpeakerIds,
                                    fallbackNames: hasEphemeral
                                        ? const []
                                        : state.participants,
                                    colors: colors,
                                    typography: typography,
                                    isDark: isDark,
                                    subject: state.room.subject,
                                    participantCount: hasEphemeral
                                        ? state.ephemeralParticipants.length
                                        : state.participants.length,
                                    activeGoal: state.activeGoal,
                                    isVoicePodEnabled: state.isVoicePodEnabled,
                                    l10n: l10n,
                                  ),
                                ),

                                const SizedBox(height: 2),

                                // Audience / Other Scholars section
                                if (audience.isNotEmpty ||
                                    (!hasEphemeral &&
                                        state.participants.length > 1))
                                  Expanded(
                                    flex: 3,
                                    child: _AudienceSection(
                                      audience: audience,
                                      fallbackNames: hasEphemeral
                                          ? const []
                                          : state.participants.skip(1).toList(),
                                      colors: colors,
                                      typography: typography,
                                      isDark: isDark,
                                      l10n: l10n,
                                    ),
                                  ),
                              ],
                            ),
                    ),

                    // Sleek Bottom Control & Reaction Bar
                    _MinimalInRoomBottomBar(
                      state: state,
                      currentUserId: widget.currentUserId,
                      colors: colors,
                      typography: typography,
                      isDark: isDark,
                      onReact: (emoji) {
                        _lastReaction = emoji;
                        _reactionController.spawn(emoji);
                        context.read<LiveRoomCubit>().triggerMicroReaction(
                          emoji,
                        );
                      },
                      onOpenDrawer: () {
                        _scaffoldKey.currentState?.openDrawer();
                      },
                      onOpenDeckPicker: () {
                        unawaited(InRoomDeckPickerModal.show(context));
                      },
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

// ── Co-Op Sprint Banner ───────────────────────────────────────────────────────

class _CoOpSprintBanner extends StatelessWidget {
  const _CoOpSprintBanner({
    required this.state,
    required this.isDark,
  });

  final LiveRoomState state;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.warning.withAlpha(isDark ? 60 : 35),
            colors.primary.withAlpha(isDark ? 50 : 25),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.warning.withAlpha(isDark ? 120 : 80),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.black.withAlpha(isDark ? 30 : 10),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.warning.withAlpha(isDark ? 60 : 40),
            ),
            child: Icon(
              Icons.bolt_rounded,
              color: colors.warning,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'CO-OP SPRINT',
                      style: typography.caption.bold.copyWith(
                        color: colors.warning,
                        fontSize: 9.5,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: colors.warning.withAlpha(40),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        state.formattedSprintTimer,
                        style: typography.caption.bold.copyWith(
                          color: colors.warning,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  state.coOpSprintDeckTitle ?? '3-Min Focus Sprint',
                  style: typography.caption.bold.copyWith(
                    color: colors.textPrimary,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ShrinkableButton(
            onTap: () {
              unawaited(HapticFeedback.mediumImpact());
              context.read<LiveRoomCubit>().logCardReviewed();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: colors.warning,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_rounded,
                    color: colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '+1 Card',
                    style: typography.caption.bold.copyWith(
                      color: colors.white,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: Icon(
              Icons.close_rounded,
              size: 18,
              color: colors.textSecondary,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => context.read<LiveRoomCubit>().endCoOpSprint(),
          ),
        ],
      ),
    );
  }
}

// ── Ambient Soundscape Bar ────────────────────────────────────────────────────

class _AmbientSoundscapeBar extends StatelessWidget {
  const _AmbientSoundscapeBar({
    required this.state,
    required this.isDark,
  });

  final LiveRoomState state;
  final bool isDark;

  static const _soundtracks = [
    {'name': 'Lo-Fi Beats', 'emoji': '🎧'},
    {'name': 'Gentle Rain', 'emoji': '🌧️'},
    {'name': 'Binaural 40Hz', 'emoji': '🧠'},
    {'name': 'Library Silence', 'emoji': '📚'},
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    final currentSound = state.ambientSoundTrack;
    final isPlaying = state.isAmbientAudioPlaying;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isDark
              ? colors.surfaceSecondary.withAlpha(150)
              : colors.surfacePrimary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPlaying
                ? colors.syllabotAccent.withAlpha(isDark ? 80 : 50)
                : colors.primary.withAlpha(isDark ? 30 : 15),
          ),
        ),
        child: Row(
          children: [
            // Play / Pause toggle
            ShrinkableButton(
              onTap: () {
                unawaited(HapticFeedback.lightImpact());
                context.read<LiveRoomCubit>().toggleAmbientAudio();
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (isPlaying ? colors.syllabotAccent : colors.primary)
                      .withAlpha(isDark ? 50 : 30),
                ),
                child: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 16,
                  color: isPlaying ? colors.syllabotAccent : colors.primary,
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Soundscape Track Selector
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _soundtracks.map((track) {
                    final isSelected = currentSound == track['name'];
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ShrinkableButton(
                        onTap: () {
                          unawaited(HapticFeedback.lightImpact());
                          context.read<LiveRoomCubit>().setAmbientSoundTrack(
                            track['name']!,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isPlaying
                                      ? colors.syllabotAccent
                                      : colors.primary)
                                : colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? colors.transparent
                                  : colors.primary.withAlpha(isDark ? 30 : 20),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                track['emoji']!,
                                style: context.typography.body.regular.copyWith(fontSize: 11),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                track['name']!,
                                style: typography.caption.bold.copyWith(
                                  fontSize: 10.5,
                                  color: isSelected
                                      ? colors.white
                                      : colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            // Volume Button triggering interactive modal
            ShrinkableButton(
              onTap: () {
                unawaited(HapticFeedback.lightImpact());
                _showVolumeModal(context);
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (state.ambientAudioVolume > 0 && isPlaying)
                      ? colors.syllabotAccent.withAlpha(isDark ? 50 : 30)
                      : colors.primary.withAlpha(isDark ? 30 : 15),
                ),
                child: Icon(
                  state.ambientAudioVolume > 0.5
                      ? Icons.volume_up_rounded
                      : (state.ambientAudioVolume > 0
                            ? Icons.volume_down_rounded
                            : Icons.volume_mute_rounded),
                  size: 16,
                  color: isPlaying
                      ? colors.syllabotAccent
                      : colors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showVolumeModal(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final cubit = context.read<LiveRoomCubit>();

    unawaited(
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: colors.transparent,
        builder: (ctx) {
          return BlocProvider.value(
            value: cubit,
            child: BlocBuilder<LiveRoomCubit, LiveRoomState>(
              builder: (context, roomState) {
                final volumePercent = (roomState.ambientAudioVolume * 100)
                    .round();
                return Align(
                  alignment: Alignment.bottomCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 20,
                      ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? colors.surfaceSecondary
                        : colors.surfacePrimary,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    border: Border.all(
                      color: colors.primary.withAlpha(isDark ? 50 : 25),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: colors.textSecondary.withAlpha(80),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  roomState.ambientAudioVolume > 0
                                      ? Icons.volume_up_rounded
                                      : Icons.volume_off_rounded,
                                  color: colors.syllabotAccent,
                                  size: 22,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Ambient Audio Volume',
                                  style: typography.body.bold.copyWith(
                                    color: colors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: colors.syllabotAccent.withAlpha(
                                  isDark ? 45 : 25,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$volumePercent%',
                                style: typography.caption.bold.copyWith(
                                  color: colors.syllabotAccent,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            ShrinkableButton(
                              onTap: () {
                                unawaited(HapticFeedback.lightImpact());
                                cubit.setAmbientVolume(
                                  roomState.ambientAudioVolume == 0 ? 0.5 : 0.0,
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: colors.primary.withAlpha(
                                    isDark ? 40 : 20,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  roomState.ambientAudioVolume == 0
                                      ? Icons.volume_off_rounded
                                      : Icons.volume_mute_rounded,
                                  color: colors.textSecondary,
                                  size: 20,
                                ),
                              ),
                            ),
                            Expanded(
                              child: SliderTheme(
                                data: SliderThemeData(
                                  activeTrackColor: colors.syllabotAccent,
                                  inactiveTrackColor: colors.primary.withAlpha(
                                    isDark ? 50 : 30,
                                  ),
                                  thumbColor: colors.syllabotAccent,
                                  overlayColor: colors.syllabotAccent.withAlpha(
                                    40,
                                  ),
                                  trackHeight: 6,
                                  thumbShape: const RoundSliderThumbShape(),
                                ),
                                child: Slider(
                                  value: roomState.ambientAudioVolume,
                                  onChanged: cubit.setAmbientVolume,
                                ),
                              ),
                            ),
                            ShrinkableButton(
                              onTap: () {
                                unawaited(HapticFeedback.lightImpact());
                                cubit.setAmbientVolume(1);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: colors.primary.withAlpha(
                                    isDark ? 40 : 20,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.volume_up_rounded,
                                  color: colors.syllabotAccent,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Mute',
                              style: typography.caption.regular.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                            Text(
                              'Max',
                              style: typography.caption.regular.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
            ),
          );
        },
      ),
    );
  }
}

// ── Silent Focus Cockpit Section ─────────────────────────────────────────────

class _FocusCockpitSection extends StatelessWidget {
  const _FocusCockpitSection({
    required this.participants,
    required this.activeSpeakerIds,
    required this.fallbackNames,
    required this.colors,
    required this.typography,
    required this.isDark,
    required this.subject,
    required this.participantCount,
    required this.activeGoal,
    required this.isVoicePodEnabled,
    required this.l10n,
  });

  final List<EphemeralParticipant> participants;
  final Set<String> activeSpeakerIds;
  final List<String> fallbackNames;
  final dynamic colors;
  final dynamic typography;
  final bool isDark;
  final String subject;
  final int participantCount;
  final String? activeGoal;
  final bool isVoicePodEnabled;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final cColors = context.colors;
    final cTypography = context.typography;
    final cIsDark = context.isDarkMode;

    final scholars = participants.isNotEmpty
        ? participants
        : fallbackNames
              .take(6)
              .map(
                (n) => EphemeralParticipant(
                  userId: n,
                  displayName: n,
                  avatarUrl: '',
                ),
              )
              .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cColors.primary.withAlpha(cIsDark ? 25 : 12),
            cColors.syllabotAccent.withAlpha(cIsDark ? 15 : 8),
          ],
        ),
      ),
      child: Column(
        children: [
          // Topic label & Silent Body-Doubling Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: cColors.primary.withAlpha(cIsDark ? 50 : 30),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  subject.toUpperCase(),
                  style: cTypography.caption.bold.copyWith(
                    color: cColors.primary,
                    letterSpacing: 1.1,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color:
                      (isVoicePodEnabled
                              ? cColors.warning
                              : cColors.syllabotAccent)
                          .withAlpha(cIsDark ? 40 : 25),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isVoicePodEnabled
                          ? Icons.record_voice_over_rounded
                          : Icons.headphones_rounded,
                      size: 12,
                      color: isVoicePodEnabled
                          ? cColors.warning
                          : cColors.syllabotAccent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isVoicePodEnabled
                          ? 'Voice Pod Active'
                          : 'Silent Flow Cockpit',
                      style: cTypography.caption.bold.copyWith(
                        color: isVoicePodEnabled
                            ? cColors.warning
                            : cColors.syllabotAccent,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),

          // Scholars Grid with Flow Glow rings
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 20,
            runSpacing: 14,
            children: scholars.isEmpty
                ? [
                    _GlowAvatar(
                      name: 'You',
                      colors: cColors,
                      typography: cTypography,
                      size: 60,
                      isGlowing: true,
                      isDark: cIsDark,
                    ),
                  ]
                : scholars
                      .take(6)
                      .map(
                        (p) => _FocusParticipantTile(
                          participant: p,
                          colors: cColors,
                          typography: cTypography,
                          isDark: cIsDark,
                          isSpeaking:
                              isVoicePodEnabled &&
                              (activeSpeakerIds.contains(p.userId) ||
                                  (!p.isMuted && activeSpeakerIds.isEmpty)),
                          isVoicePodEnabled: isVoicePodEnabled,
                        ),
                      )
                      .toList(),
          ),

          const Spacer(),

          // Scholars in room
          Text(
            l10n.inThisRoom(participantCount),
            style: cTypography.caption.regular.copyWith(
              color: cColors.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _FocusParticipantTile extends StatelessWidget {
  const _FocusParticipantTile({
    required this.participant,
    required this.colors,
    required this.typography,
    required this.isDark,
    required this.isSpeaking,
    required this.isVoicePodEnabled,
  });

  final EphemeralParticipant participant;
  final dynamic colors;
  final dynamic typography;
  final bool isDark;
  final bool isSpeaking;
  final bool isVoicePodEnabled;

  @override
  Widget build(BuildContext context) {
    final cColors = context.colors;
    final cTypography = context.typography;
    final cIsDark = context.isDarkMode;

    final String statusLabel;
    final Color statusColor;

    if (participant.isAway) {
      statusLabel = 'Away';
      statusColor = cColors.warning;
    } else if (participant.isAiBuddy) {
      statusLabel = 'AI Buddy';
      statusColor = cColors.syllabotAccent;
    } else if (isSpeaking) {
      statusLabel = 'Speaking';
      statusColor = cColors.recallEasy;
    } else {
      statusLabel = 'Deep Flow';
      statusColor = cColors.primary;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.topRight,
          children: [
            _GlowAvatar(
              name: participant.displayName,
              colors: cColors,
              typography: cTypography,
              size: 56,
              isGlowing: !participant.isAway,
              isDark: cIsDark,
              glowColor: statusColor,
            ),
            if (isVoicePodEnabled &&
                !participant.isMuted &&
                !participant.isAway)
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cColors.recallEasy,
                ),
                child: Icon(
                  Icons.mic_rounded,
                  size: 9,
                  color: cColors.white,
                ),
              ),
            if (participant.isAway)
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cColors.warning,
                ),
                child: Icon(
                  Icons.pause_rounded,
                  size: 9,
                  color: cColors.white,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          participant.displayName.split(' ').first,
          style: cTypography.caption.medium.copyWith(
            color: cColors.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: statusColor.withAlpha(25),
            borderRadius: BorderRadius.circular(6),
            border: participant.isAiBuddy
                ? Border.all(color: statusColor.withAlpha(60), width: 0.8)
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (participant.isAiBuddy) ...[
                Text('🤖 ', style: context.typography.body.regular.copyWith(fontSize: 8)),
              ] else if (participant.isAway) ...[
                Text('⏳ ', style: context.typography.body.regular.copyWith(fontSize: 8)),
              ],
              Text(
                statusLabel,
                style: cTypography.caption.bold.copyWith(
                  color: statusColor,
                  fontSize: 9.5,
                ),
              ),
            ],
          ),
        ),
        if (participant.cardsReviewed > 0) ...[
          const SizedBox(height: 2.5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: cColors.recallGood.withAlpha(25),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bolt_rounded, size: 9, color: cColors.recallGood),
                const SizedBox(width: 2),
                Text(
                  '${participant.cardsReviewed} cards',
                  style: cTypography.caption.bold.copyWith(
                    color: cColors.recallGood,
                    fontSize: 8.5,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (participant.activeGoal != null &&
            participant.activeGoal!.trim().isNotEmpty) ...[
          const SizedBox(height: 2.5),
          Container(
            constraints: const BoxConstraints(maxWidth: 90),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: cColors.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              '🎯 ${participant.activeGoal}',
              style: cTypography.caption.regular.copyWith(
                color: cColors.textSecondary,
                fontSize: 8.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}

// ── Audience section ─────────────────────────────────────────────────────────

class _AudienceSection extends StatelessWidget {
  const _AudienceSection({
    required this.audience,
    required this.fallbackNames,
    required this.colors,
    required this.typography,
    required this.isDark,
    required this.l10n,
  });

  final List<EphemeralParticipant> audience;
  final List<String> fallbackNames;
  final dynamic colors;
  final dynamic typography;
  final bool isDark;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final cColors = context.colors;
    final cTypography = context.typography;

    final listeners = audience.isNotEmpty
        ? audience
        : fallbackNames
              .map(
                (n) => EphemeralParticipant(
                  userId: n,
                  displayName: n,
                  avatarUrl: '',
                ),
              )
              .toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: cColors.primary.withAlpha(20)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.audienceLabel,
            style: cTypography.caption.bold.copyWith(
              color: cColors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 56,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.75,
              ),
              itemCount: math.min(listeners.length, 24),
              itemBuilder: (context, i) {
                final p = listeners[i];
                return Column(
                  children: [
                    Stack(
                      alignment: Alignment.topRight,
                      children: [
                        AppAvatar(
                          customDimension: 36,
                          name: p.displayName,
                          backgroundColor: cColors.primary.withAlpha(40),
                          foregroundColor: cColors.primary,
                        ),
                        if (p.isHandRaised)
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: cColors.warning,
                            ),
                            child: Text(
                              '✋',
                              style: context.typography.body.regular.copyWith(fontSize: 8),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      p.displayName.split(' ').first,
                      style: cTypography.caption.regular.copyWith(
                        color: cColors.textSecondary,
                        fontSize: 9,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Active Speakers Banner ───────────────────────────────────────────────────

class _ActiveSpeakersBanner extends StatelessWidget {
  const _ActiveSpeakersBanner({
    required this.speakerIds,
    required this.participants,
    required this.isDark,
  });

  final Set<String> speakerIds;
  final List<EphemeralParticipant> participants;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    final speakingUsers = participants
        .where((p) => speakerIds.contains(p.userId))
        .toList();
    if (speakingUsers.isEmpty) return const SizedBox.shrink();

    final names = speakingUsers.map((p) => p.displayName).join(', ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: (isDark ? colors.surfaceSecondary : colors.surfacePrimary)
            .withAlpha(220),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.recallEasy.withAlpha(100)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _InRoomEqualizerVisualizer(color: colors.recallEasy),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '$names speaking',
              style: typography.caption.bold.copyWith(
                color: colors.textPrimary,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Glow avatar ───────────────────────────────────────────────────────────────

class _GlowAvatar extends StatefulWidget {
  const _GlowAvatar({
    required this.name,
    required this.colors,
    required this.typography,
    required this.size,
    required this.isGlowing,
    required this.isDark,
    this.glowColor,
  });

  final String name;
  final dynamic colors;
  final dynamic typography;
  final double size;
  final bool isGlowing;
  final bool isDark;
  final Color? glowColor;

  @override
  State<_GlowAvatar> createState() => _GlowAvatarState();
}

class _GlowAvatarState extends State<_GlowAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
      // ignore: discarded_futures — TickerFuture from repeat() is intentionally not awaited per Flutter convention
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.85, end: 1.05).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cColors = context.colors;
    final effectiveGlowColor = widget.glowColor ?? cColors.primary;

    if (!widget.isGlowing) {
      return AppAvatar(
        customDimension: widget.size,
        name: widget.name,
        backgroundColor: effectiveGlowColor.withAlpha(50),
        foregroundColor: effectiveGlowColor,
      );
    }

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        return Container(
          width: widget.size + 16,
          height: widget.size + 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: effectiveGlowColor.withValues(
                alpha: _pulse.value.clamp(0.2, 1),
              ),
              width: 2,
            ),
          ),
          child: child,
        );
      },
      child: AppAvatar(
        customDimension: widget.size,
        name: widget.name,
        backgroundColor: effectiveGlowColor.withAlpha(60),
        foregroundColor: effectiveGlowColor,
        borderColor: effectiveGlowColor.withAlpha(150),
      ),
    );
  }
}

class _InRoomEqualizerVisualizer extends StatefulWidget {
  const _InRoomEqualizerVisualizer({required this.color});

  final Color color;

  @override
  State<_InRoomEqualizerVisualizer> createState() =>
      _InRoomEqualizerVisualizerState();
}

class _InRoomEqualizerVisualizerState extends State<_InRoomEqualizerVisualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
      // ignore: discarded_futures — TickerFuture from repeat() is intentionally not awaited per Flutter convention
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final val = _controller.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildBar(3 + val * 7),
            const SizedBox(width: 2),
            _buildBar(10 - val * 6),
            const SizedBox(width: 2),
            _buildBar(5 + val * 5),
          ],
        );
      },
    );
  }

  Widget _buildBar(double height) {
    return Container(
      width: 2.5,
      height: height.clamp(3, 11),
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

// ── Live pulse badge ──────────────────────────────────────────────────────────

class _LivePulseBadge extends StatefulWidget {
  const _LivePulseBadge({required this.colors});
  final dynamic colors;

  @override
  State<_LivePulseBadge> createState() => _LivePulseBadgeState();
}

class _LivePulseBadgeState extends State<_LivePulseBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
      // ignore: discarded_futures — TickerFuture from repeat() is intentionally not awaited per Flutter convention
    )..repeat(reverse: true);
    _fade = Tween<double>(begin: 0.4, end: 1).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cColors = context.colors;
    final cTypography = context.typography;
    final l10n = context.l10n;
    return AnimatedBuilder(
      animation: _fade,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cColors.error.withValues(alpha: _fade.value),
              ),
            ),
            const SizedBox(width: 5),
            Text(
              l10n.liveIndicator,
              style: cTypography.caption.bold.copyWith(
                color: cColors.error.withValues(alpha: _fade.value),
                letterSpacing: 1.2,
                fontSize: 11,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Pomodoro mini pill ────────────────────────────────────────────────────────

class _PomodoroMiniPill extends StatelessWidget {
  const _PomodoroMiniPill({
    required this.state,
    required this.colors,
    required this.typography,
  });

  final LiveRoomState state;
  final dynamic colors;
  final dynamic typography;

  @override
  Widget build(BuildContext context) {
    final cColors = context.colors;
    final cTypography = context.typography;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cColors.primary.withAlpha(40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 13, color: cColors.primary),
          const SizedBox(width: 4),
          Text(
            state.formattedTimer,
            style: cTypography.caption.bold.copyWith(
              color: cColors.primary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ── In-Room Mode Switcher Bar ──────────────────────────────────────────────────

class _InRoomModeSwitcherBar extends StatelessWidget {
  const _InRoomModeSwitcherBar({
    required this.activeMode,
    required this.onSelectMode,
    required this.isDark,
    required this.cardsReviewed,
  });

  final RoomViewMode activeMode;
  final ValueChanged<RoomViewMode> onSelectMode;
  final bool isDark;
  final int cardsReviewed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(3.5),
      decoration: BoxDecoration(
        color: colors.surfacePrimary.withAlpha(isDark ? 160 : 220),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.primary.withAlpha(isDark ? 50 : 25),
        ),
      ),
      child: Row(
        children: [
          _buildSegment(
            context,
            mode: RoomViewMode.stage,
            icon: Icons.group_rounded,
            label: 'Focus Pod',
            isActive: activeMode == RoomViewMode.stage,
            colors: colors,
            typography: typography,
          ),
          const SizedBox(width: 4),
          _buildSegment(
            context,
            mode: RoomViewMode.deckStudy,
            icon: Icons.style_rounded,
            label: 'Study Deck',
            badge: cardsReviewed > 0 ? '$cardsReviewed' : null,
            isActive: activeMode == RoomViewMode.deckStudy,
            colors: colors,
            typography: typography,
          ),
          const SizedBox(width: 4),
          _buildSegment(
            context,
            mode: RoomViewMode.whiteboard,
            icon: Icons.draw_rounded,
            label: context.l10n.whiteboardTabLabel,
            isActive: activeMode == RoomViewMode.whiteboard,
            colors: colors,
            typography: typography,
          ),
        ],
      ),
    );
  }

  Widget _buildSegment(
    BuildContext context, {
    required RoomViewMode mode,
    required IconData icon,
    required String label,
    required bool isActive,
    required AppThemeColorsExtension colors,
    required TypographyThemeExtension typography,
    String? badge,
  }) {
    return Expanded(
      child: ShrinkableButton(
        onTap: () {
          unawaited(HapticFeedback.selectionClick());
          onSelectMode(mode);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isActive ? colors.primary : colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: colors.black.withAlpha(isDark ? 40 : 15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isActive ? colors.white : colors.textSecondary,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style:
                    (isActive
                            ? typography.caption.bold
                            : typography.caption.medium)
                        .copyWith(
                          color: isActive ? colors.white : colors.textSecondary,
                          fontSize: 11,
                        ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? colors.white.withAlpha(50)
                        : colors.recallEasy.withAlpha(isDark ? 50 : 30),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge,
                    style: typography.caption.bold.copyWith(
                      fontSize: 9,
                      color: isActive ? colors.white : colors.recallEasy,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Minimal In-Room Bottom Bar ───────────────────────────────────────────────

class _MinimalInRoomBottomBar extends StatelessWidget {
  const _MinimalInRoomBottomBar({
    required this.state,
    required this.currentUserId,
    required this.colors,
    required this.typography,
    required this.isDark,
    required this.onReact,
    required this.onOpenDrawer,
    required this.onOpenDeckPicker,
  });

  final LiveRoomState state;
  final String currentUserId;
  final AppThemeColorsExtension colors;
  final TypographyThemeExtension typography;
  final bool isDark;
  final ValueChanged<String> onReact;
  final VoidCallback onOpenDrawer;
  final VoidCallback onOpenDeckPicker;

  static const List<String> _quickEmojis = ['🔥', '👏', '💡', '❤️'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
        border: Border(
          top: BorderSide(color: colors.primary.withAlpha(isDark ? 40 : 20)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drawer trigger button
              ShrinkableButton(
                onTap: onOpenDrawer,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceTertiary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colors.surfaceBorder.withAlpha(isDark ? 80 : 50),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tune_rounded, size: 15, color: colors.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Tools',
                        style: typography.caption.bold.copyWith(
                          color: colors.textPrimary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Deck switch button
              ShrinkableButton(
                onTap: onOpenDeckPicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary.withAlpha(isDark ? 40 : 20),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colors.primary.withAlpha(isDark ? 80 : 40),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_stories_rounded,
                        size: 14,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Decks',
                        style: typography.caption.bold.copyWith(
                          color: colors.primary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Quick reactions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: _quickEmojis.map((emoji) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: ShrinkableButton(
                  onTap: () {
                    unawaited(HapticFeedback.lightImpact());
                    onReact(emoji);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 3,
                      vertical: 2,
                    ),
                    child: Text(
                      emoji,
                      style: context.typography.body.regular.copyWith(fontSize: 17),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ── Room Control Drawer ──────────────────────────────────────────────────────

class _RoomControlDrawer extends StatelessWidget {
  const _RoomControlDrawer({
    required this.state,
    required this.currentUserId,
    required this.currentUserName,
    required this.colors,
    required this.typography,
    required this.isDark,
    required this.l10n,
    required this.onEditGoal,
    required this.onOpenDeckPicker,
    required this.onLaunchSprint,
    required this.onLeaveRoom,
  });

  final LiveRoomState state;
  final String currentUserId;
  final String currentUserName;
  final AppThemeColorsExtension colors;
  final TypographyThemeExtension typography;
  final bool isDark;
  final AppLocalizations l10n;
  final VoidCallback onEditGoal;
  final VoidCallback onOpenDeckPicker;
  final VoidCallback onLaunchSprint;
  final VoidCallback onLeaveRoom;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<LiveRoomCubit>();

    return Drawer(
      backgroundColor: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: colors.surfaceBorder.withAlpha(isDark ? 80 : 50),
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primary.withAlpha(isDark ? 50 : 25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          state.room.subject,
                          style: typography.caption.bold.copyWith(
                            color: colors.primary,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.room.title,
                    style: typography.subhead.bold.copyWith(
                      color: colors.textPrimary,
                      fontSize: 16,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _LivePulseBadge(colors: colors),
                      const SizedBox(width: 8),
                      Text(
                        '${state.ephemeralParticipants.length} active in pod',
                        style: typography.caption.regular.copyWith(
                          color: colors.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: ListView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  // Mode Switcher Section
                  _buildSectionHeader('WORKSPACE MODE', Icons.layers_rounded),
                  const SizedBox(height: 8),
                  _buildModeTile(
                    title: 'Study Deck',
                    subtitle: state.activeDeckTitle ?? 'Active Recall & FSRS',
                    icon: Icons.style_rounded,
                    isSelected: state.activeViewMode == RoomViewMode.deckStudy,
                    onTap: () {
                      cubit.switchViewMode(RoomViewMode.deckStudy);
                      Navigator.of(context).pop();
                    },
                  ),
                  const SizedBox(height: 6),
                  _buildModeTile(
                    title: 'Focus Cockpit',
                    subtitle: 'Presence & Body-Doubling',
                    icon: Icons.group_rounded,
                    isSelected: state.activeViewMode == RoomViewMode.stage,
                    onTap: () {
                      cubit.switchViewMode(RoomViewMode.stage);
                      Navigator.of(context).pop();
                    },
                  ),
                  const SizedBox(height: 6),
                  _buildModeTile(
                    title: 'Shared Whiteboard',
                    subtitle: 'Collaborative live drawing',
                    icon: Icons.draw_rounded,
                    isSelected: state.activeViewMode == RoomViewMode.whiteboard,
                    onTap: () {
                      cubit.switchViewMode(RoomViewMode.whiteboard);
                      Navigator.of(context).pop();
                    },
                  ),

                  const SizedBox(height: 18),

                  // Study Deck Quick Picker
                  _buildSectionHeader('STUDY DECK', Icons.auto_stories_rounded),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.surfaceTertiary,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: colors.surfaceBorder.withAlpha(isDark ? 60 : 40),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.activeDeckTitle ?? 'No deck chosen',
                          style: typography.body.bold.copyWith(
                            color: colors.textPrimary,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${state.cardsReviewedInSprint} cards reviewed in this session',
                          style: typography.caption.regular.copyWith(
                            color: colors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ShrinkableButton(
                          onTap: () {
                            Navigator.of(context).pop();
                            onOpenDeckPicker();
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: colors.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                state.activeDeckId != null
                                    ? 'Switch Deck'
                                    : 'Select Deck',
                                style: typography.caption.bold.copyWith(
                                  color: colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Micro-Goal Section
                  _buildSectionHeader('MICRO-GOAL', Icons.flag_rounded),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.surfaceTertiary,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: colors.surfaceBorder.withAlpha(isDark ? 60 : 40),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.activeGoal ?? 'No micro-goal set yet',
                          style: typography.body.bold.copyWith(
                            color: state.activeGoal != null
                                ? colors.textPrimary
                                : colors.textSecondary,
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ShrinkableButton(
                          onTap: () {
                            Navigator.of(context).pop();
                            onEditGoal();
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: colors.primary.withAlpha(isDark ? 50 : 25),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: colors.primary.withAlpha(
                                  isDark ? 90 : 50,
                                ),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                state.activeGoal != null
                                    ? 'Edit Goal'
                                    : 'Set Goal',
                                style: typography.caption.bold.copyWith(
                                  color: colors.primary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Ambient Audio & Binaural Soundscapes
                  _buildSectionHeader(
                    'AMBIENT SOUNDSCAPE',
                    Icons.headphones_rounded,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.surfaceTertiary,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: colors.surfaceBorder.withAlpha(isDark ? 60 : 40),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              state.ambientSoundTrack,
                              style: typography.caption.bold.copyWith(
                                color: colors.textPrimary,
                                fontSize: 12,
                              ),
                            ),
                            ShrinkableButton(
                              onTap: cubit.toggleAmbientAudio,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: state.isAmbientAudioPlaying
                                      ? colors.syllabotAccent
                                      : colors.primary.withAlpha(40),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  state.isAmbientAudioPlaying
                                      ? 'Playing'
                                      : 'Paused',
                                  style: typography.caption.bold.copyWith(
                                    color: colors.white,
                                    fontSize: 10.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _AmbientSoundscapeBar._soundtracks.map((
                            track,
                          ) {
                            final isSel =
                                state.ambientSoundTrack == track['name'];
                            return ShrinkableButton(
                              onTap: () =>
                                  cubit.setAmbientSoundTrack(track['name']!),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isSel
                                      ? colors.syllabotAccent
                                      : colors.surfacePrimary,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSel
                                        ? colors.transparent
                                        : colors.surfaceBorder,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      track['emoji']!,
                                      style: context.typography.body.regular.copyWith(fontSize: 11),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      track['name']!,
                                      style: typography.caption.medium.copyWith(
                                        fontSize: 10.5,
                                        color: isSel
                                            ? colors.white
                                            : colors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 10),
                        // Volume Slider
                        Row(
                          children: [
                            Icon(
                              Icons.volume_down_rounded,
                              size: 14,
                              color: colors.textSecondary,
                            ),
                            Expanded(
                              child: Slider(
                                value: state.ambientAudioVolume,
                                onChanged: cubit.setAmbientVolume,
                                activeColor: colors.syllabotAccent,
                              ),
                            ),
                            Icon(
                              Icons.volume_up_rounded,
                              size: 14,
                              color: colors.textSecondary,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Voice Pod & Audio Presence
                  _buildSectionHeader('VOICE POD', Icons.mic_rounded),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ShrinkableButton(
                          onTap: () {
                            if (state.isVoicePodEnabled) {
                              unawaited(cubit.toggleMicMute());
                            } else {
                              cubit.toggleVoicePod();
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: state.isVoicePodEnabled && !state.isMuted
                                  ? colors.recallEasy.withAlpha(
                                      isDark ? 50 : 30,
                                    )
                                  : colors.surfaceTertiary,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: state.isVoicePodEnabled && !state.isMuted
                                    ? colors.recallEasy
                                    : colors.surfaceBorder,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  !state.isVoicePodEnabled
                                      ? Icons.mic_off_rounded
                                      : (state.isMuted
                                            ? Icons.mic_off_rounded
                                            : Icons.mic_rounded),
                                  size: 16,
                                  color:
                                      state.isVoicePodEnabled && !state.isMuted
                                      ? colors.recallEasy
                                      : colors.textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  !state.isVoicePodEnabled
                                      ? 'Join Voice'
                                      : (state.isMuted ? 'Unmute' : 'Muted'),
                                  style: typography.caption.bold.copyWith(
                                    color:
                                        state.isVoicePodEnabled &&
                                            !state.isMuted
                                        ? colors.recallEasy
                                        : colors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ShrinkableButton(
                          onTap: cubit.toggleHandRaise,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: state.isHandRaised
                                  ? colors.warning.withAlpha(isDark ? 50 : 30)
                                  : colors.surfaceTertiary,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: state.isHandRaised
                                    ? colors.warning
                                    : colors.surfaceBorder,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.front_hand_rounded,
                                  size: 16,
                                  color: state.isHandRaised
                                      ? colors.warning
                                      : colors.textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  state.isHandRaised ? 'Hand Up' : 'Raise Hand',
                                  style: typography.caption.bold.copyWith(
                                    color: state.isHandRaised
                                        ? colors.warning
                                        : colors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Co-Op Focus Sprint
                  _buildSectionHeader('CO-OP STUDY SPRINT', Icons.bolt_rounded),
                  const SizedBox(height: 8),
                  ShrinkableButton(
                    onTap: () {
                      Navigator.of(context).pop();
                      onLaunchSprint();
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colors.warning.withAlpha(isDark ? 50 : 30),
                            colors.primary.withAlpha(isDark ? 40 : 20),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: colors.warning.withAlpha(isDark ? 90 : 60),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.flash_on_rounded,
                            color: colors.warning,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Launch Co-Op Sprint',
                                  style: typography.caption.bold.copyWith(
                                    color: colors.textPrimary,
                                    fontSize: 12.5,
                                  ),
                                ),
                                Text(
                                  '3-minute synchronized rapid review battle',
                                  style: typography.caption.regular.copyWith(
                                    color: colors.textSecondary,
                                    fontSize: 10.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: colors.textSecondary,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Leave Room Button
                  ShrinkableButton(
                    onTap: () {
                      Navigator.of(context).pop();
                      onLeaveRoom();
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: colors.error.withAlpha(isDark ? 35 : 20),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: colors.error.withAlpha(isDark ? 80 : 45),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.logout_rounded,
                            size: 17,
                            color: colors.error,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Leave Room',
                            style: typography.caption.bold.copyWith(
                              color: colors.error,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 13, color: colors.primary),
        const SizedBox(width: 5),
        Text(
          title,
          style: typography.caption.bold.copyWith(
            color: colors.primary,
            fontSize: 10,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _buildModeTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ShrinkableButton(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.primary.withAlpha(isDark ? 50 : 25)
              : colors.surfaceTertiary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? colors.primary
                : colors.surfaceBorder.withAlpha(isDark ? 60 : 40),
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? colors.primary : colors.textSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: typography.caption.bold.copyWith(
                      color: isSelected ? colors.primary : colors.textPrimary,
                      fontSize: 12.5,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: typography.caption.regular.copyWith(
                      color: colors.textSecondary,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, size: 16, color: colors.primary),
          ],
        ),
      ),
    );
  }
}
