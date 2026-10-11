import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/study_activity_tracker.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';
import 'package:kortex/src/features/monetization/domain/services/subscription_guard.dart';
import 'package:kortex/src/features/study_rooms/domain/entities/study_room_entity.dart';
import 'package:kortex/src/features/study_rooms/domain/repositories/ephemeral_room_repository.dart';
import 'package:kortex/src/features/study_rooms/domain/services/livekit_audio_service.dart';
import 'package:kortex/src/features/study_rooms/presentation/bloc/live_room_cubit.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/floating_reaction_overlay.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/in_room_deck_picker_modal.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/in_room_deck_study_workspace.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/live_study_room_banners.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/live_study_room_controls.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/live_study_room_dialogs.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/live_study_room_participants.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/whiteboard_canvas_widget.dart';
import 'package:kortex/src/l10n/l10n.dart';

@RoutePage()
class LiveStudyRoomPage extends StatelessWidget {
  const LiveStudyRoomPage({
    required this.room,
    this.userStorageService,
    this.communityRepository,
    this.ephemeralRoomRepository,
    this.liveKitAudioService,
    this.studyActivityTracker,
    this.subscriptionGuard,
    super.key,
  });

  final StudyRoomEntity room;
  final UserStorageService? userStorageService;
  final CommunityRepository? communityRepository;
  final EphemeralRoomRepository? ephemeralRoomRepository;
  final LiveKitAudioService? liveKitAudioService;
  final StudyActivityTracker? studyActivityTracker;
  final SubscriptionGuard? subscriptionGuard;

  @override
  Widget build(BuildContext context) {
    final userStorage = userStorageService ?? locator<UserStorageService>();
    final communityRepo = communityRepository ?? locator<CommunityRepository>();
    final ephemeralRepo =
        ephemeralRoomRepository ?? locator<EphemeralRoomRepository>();
    final audioSvc = liveKitAudioService ??
        (locator.isRegistered<LiveKitAudioService>()
            ? locator<LiveKitAudioService>()
            : null);
    final activityTracker = studyActivityTracker ??
        (locator.isRegistered<StudyActivityTracker>()
            ? locator<StudyActivityTracker>()
            : null);
    final subGuard = subscriptionGuard ??
        (locator.isRegistered<SubscriptionGuard>()
            ? locator<SubscriptionGuard>()
            : null);

    final currentUserId = userStorage.getUserId() ?? 'user_local';
    final currentUserName = userStorage.getUserDisplayName() ?? 'Scholar';

    return BlocProvider<LiveRoomCubit>(
      create: (_) => LiveRoomCubit(
        initialRoom: room,
        repository: communityRepo,
        ephemeralRepository: ephemeralRepo,
        audioService: audioSvc,
        currentUserId: currentUserId,
        currentUserName: currentUserName,
        currentUserAvatar: userStorage.getUserAvatarUrl() ?? '',
      ),
      child: _LiveStudyRoomView(
        currentUserId: currentUserId,
        currentUserName: currentUserName,
        activityTracker: activityTracker,
        subscriptionGuard: subGuard,
      ),
    );
  }
}

class _LiveStudyRoomView extends StatefulWidget {
  const _LiveStudyRoomView({
    required this.currentUserId,
    required this.currentUserName,
    this.activityTracker,
    this.subscriptionGuard,
  });

  final String currentUserId;
  final String currentUserName;
  final StudyActivityTracker? activityTracker;
  final SubscriptionGuard? subscriptionGuard;

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
  String? _lastProcessedReactionId;
  bool _hasShownRoomEndedDialog = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final currentGoal = context.read<LiveRoomCubit>().state.activeGoal;
      if (currentGoal == null || currentGoal.trim().isEmpty) {
        LiveStudyRoomDialogs.showGoalEditDialog(
          context: context,
          currentGoal: null,
        );
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

  void _handleExit(BuildContext context) {
    final cubit = context.read<LiveRoomCubit>();
    final isHost = widget.currentUserId == cubit.state.room.createdBy;
    LiveStudyRoomDialogs.showExitConfirmationDialog(
      context: context,
      isHost: isHost,
      onLeaveOnly: () => _performExit(context),
      onEndForEveryone: () async {
        if (isHost) {
          await cubit.endRoomAsHost();
        }
        if (context.mounted) {
          _performExit(context);
        }
      },
    );
  }

  void _performExit(BuildContext context) {
    final cubit = context.read<LiveRoomCubit>();
    final state = cubit.state;

    final hasStudyActivity =
        state.completedPomodoros > 0 || state.cardsReviewedInSprint > 0;

    if (state.activeGoal != null &&
        state.activeGoal!.trim().isNotEmpty &&
        !state.isGoalAchieved) {
      LiveStudyRoomDialogs.showGoalVerificationDialog(
        context: context,
        goal: state.activeGoal!,
        onAfterVerification: () {
          final updatedState = cubit.state;
          final updatedHasActivity =
              updatedState.completedPomodoros > 0 ||
              updatedState.cardsReviewedInSprint > 0;
          if (updatedHasActivity) {
            LiveStudyRoomDialogs.showSummarySheet(
              context: context,
              state: updatedState,
              activityTracker: widget.activityTracker,
            );
          } else {
            Navigator.of(context).pop();
          }
        },
      );
      return;
    }

    if (hasStudyActivity) {
      LiveStudyRoomDialogs.showSummarySheet(
        context: context,
        state: state,
        activityTracker: widget.activityTracker,
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleVoicePodTapped(LiveRoomState state) async {
    final cubit = context.read<LiveRoomCubit>();
    final guard = widget.subscriptionGuard;
    if (guard != null && !guard.canBroadcastRoomVoice()) {
      final upgraded = await guard.requirePro(
        context,
        featureName: 'Live Voice Pod Broadcasting',
      );
      if (!upgraded) return;
    }
    if (state.isVoicePodEnabled) {
      unawaited(cubit.toggleMicMute());
    } else {
      cubit.toggleVoicePod();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    return BlocConsumer<LiveRoomCubit, LiveRoomState>(
      listener: (context, state) {
        if (state.lastReactionEvent != null &&
            state.lastReactionEvent!.id != _lastProcessedReactionId) {
          _lastProcessedReactionId = state.lastReactionEvent!.id;
          _reactionController.spawnMultiple(state.lastReactionEvent!.emojis);
        } else if (state.lastReactionEmoji != null &&
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
              title: 'Hand Raised',
              message: l10n.handRaisedNotice(p.displayName),
              icon: Icons.front_hand_rounded,
            );
          } else if (!p.isHandRaised) {
            _announcedHandRaises.remove(p.userId);
          }
        }

        if (state.showGoalVerificationModal &&
            state.activeGoal != null &&
            state.activeGoal!.trim().isNotEmpty) {
          LiveStudyRoomDialogs.showGoalVerificationDialog(
            context: context,
            goal: state.activeGoal!,
          );
        }

        if (state.microphonePermissionDenied) {
          context.read<LiveRoomCubit>().dismissMicPermissionPrompt();
          LiveStudyRoomDialogs.showMicrophonePermissionDialog(
            context: context,
            isPermanentlyDenied: state.isPermanentlyDeniedMic,
          );
        }

        if (state.isRoomEndedByHost && !_hasShownRoomEndedDialog) {
          _hasShownRoomEndedDialog = true;
          LiveStudyRoomDialogs.showRoomEndedByHostDialog(
            context: context,
            onConfirm: () => _performExit(context),
          );
        }
      },
      builder: (context, state) {
        final audience = state.ephemeralParticipants;
        final hasEphemeral = state.ephemeralParticipants.isNotEmpty;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            _handleExit(context);
          },
          child: CallbackShortcuts(
            bindings: <ShortcutActivator, VoidCallback>{
              const SingleActivator(LogicalKeyboardKey.escape): () =>
                  _handleExit(context),
            },
            child: Focus(
              autofocus: true,
              child: FloatingReactionOverlay(
                controller: _reactionController,
                child: Scaffold(
                  key: _scaffoldKey,
                  backgroundColor: isDark
                      ? colors.backgroundPrimary
                      : colors.surfacePrimary,
                  drawer: RoomControlDrawer(
                    state: state,
                    currentUserId: widget.currentUserId,
                    currentUserName: widget.currentUserName,
                    colors: colors,
                    typography: typography,
                    isDark: isDark,
                    l10n: l10n,
                    onEditGoal: () => LiveStudyRoomDialogs.showGoalEditDialog(
                      context: context,
                      currentGoal: state.activeGoal,
                    ),
                    onOpenDeckPicker: () =>
                        InRoomDeckPickerModal.show(context),
                    onLaunchSprint: () =>
                        LiveStudyRoomDialogs.showStartCoOpSprintDialog(
                      context: context,
                    ),
                    onLeaveRoom: () => _handleExit(context),
                    canBroadcastVoice:
                        widget.subscriptionGuard?.canBroadcastRoomVoice() ??
                            true,
                    onVoicePodTapped: () => _handleVoicePodTapped(state),
                  ),
                  appBar: LiveStudyRoomAppBar(
                    state: state,
                    currentUserId: widget.currentUserId,
                    onLeave: () => _handleExit(context),
                    onOpenTools: () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                  body: SafeArea(
                    child: Column(
                      children: [
                        if (state.isReconnecting) ...[
                          const SizedBox(height: 4),
                          ReconnectingBanner(
                            attempt: state.reconnectAttempt,
                            onRetry: () => context
                                .read<LiveRoomCubit>()
                                .retryAudioConnection(),
                            isDark: isDark,
                          ),
                        ],
                        if (state.isCoOpSprintActive) ...[
                          const SizedBox(height: 4),
                          CoOpSprintBanner(
                            state: state,
                            isDark: isDark,
                          ),
                        ],
                        if (state.activeSpeakerIds.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          ActiveSpeakersBanner(
                            speakerIds: state.activeSpeakerIds,
                            participants: state.ephemeralParticipants,
                            isDark: isDark,
                          ),
                        ],
                        const SizedBox(height: 4),

                        // Compact In-Room View Mode Switcher
                        InRoomModeSwitcherBar(
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
                              ? RepaintBoundary(
                                  child: WhiteboardCanvasWidget(
                                    strokes: state.whiteboardStrokes,
                                    canUndo: state.whiteboardStrokes.any(
                                      (s) => s.userId == widget.currentUserId,
                                    ),
                                    canRedo: state
                                        .whiteboardRedoStack.isNotEmpty,
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
                                  ),
                                )
                              : Column(
                                  children: [
                                    // Silent Focus Cockpit: Body-doubling flow state
                                    Expanded(
                                      flex: 5,
                                      child: FocusCockpitSection(
                                        participants:
                                            state.ephemeralParticipants,
                                        activeSpeakerIds:
                                            state.activeSpeakerIds,
                                        fallbackNames: hasEphemeral
                                            ? const []
                                            : state.participants,
                                        isDark: isDark,
                                        subject: state.room.subject,
                                        participantCount: hasEphemeral
                                            ? state
                                                .ephemeralParticipants.length
                                            : state.participants.length,
                                        activeGoal: state.activeGoal,
                                        isVoicePodEnabled:
                                            state.isVoicePodEnabled,
                                      ),
                                    ),

                                    const SizedBox(height: 2),

                                    // Audience / Other Scholars section
                                    if (audience.isNotEmpty ||
                                        (!hasEphemeral &&
                                            state.participants.length > 1))
                                      Expanded(
                                        flex: 3,
                                        child: AudienceSection(
                                          audience: audience,
                                          fallbackNames: hasEphemeral
                                              ? const []
                                              : state.participants
                                                  .skip(1)
                                                  .toList(),
                                          isDark: isDark,
                                        ),
                                      ),
                                  ],
                                ),
                        ),

                        // Sleek Bottom Control & Reaction Bar
                        MinimalInRoomBottomBar(
                          state: state,
                          currentUserId: widget.currentUserId,
                          colors: colors,
                          typography: typography,
                          isDark: isDark,
                          onReact: (emoji) {
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
            ),
          ),
        );
      },
    );
  }
}
