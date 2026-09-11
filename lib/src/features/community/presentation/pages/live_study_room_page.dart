import 'dart:async';
import 'dart:math' as math;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/data/client/ephemeral_presence_client.dart';
import 'package:kortex/src/features/community/domain/entities/study_room_entity.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';
import 'package:kortex/src/features/community/domain/repositories/ephemeral_room_repository.dart';
import 'package:kortex/src/features/community/domain/services/livekit_audio_service.dart';
import 'package:kortex/src/features/community/presentation/bloc/live_room_cubit.dart';
import 'package:kortex/src/features/community/presentation/widgets/room_chat_drawer.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_avatar.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

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

class _LiveStudyRoomViewState extends State<_LiveStudyRoomView> {
  final Set<String> _announcedHandRaises = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final currentGoal = context.read<LiveRoomCubit>().state.activeGoal;
      if (currentGoal == null || currentGoal.trim().isEmpty) {
        _showGoalEditDialog(context, null);
      }
    });
  }

  void _showGoalEditDialog(BuildContext context, String? currentGoal) {
    final controller = TextEditingController(text: currentGoal ?? '');
    final colors = context.colors;
    final typography = context.typography;

    unawaited(
      showDialog<void>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          backgroundColor: context.isDarkMode ? colors.surfaceSecondary : colors.surfacePrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Text('🎯', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                'Set Micro-Goal',
                style: typography.subhead.bold.copyWith(color: colors.textPrimary),
              ),
            ],
          ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Define what you intend to finish during this silent focus session.',
              style: typography.caption.regular.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              style: typography.body.regular.copyWith(color: colors.textPrimary),
              decoration: InputDecoration(
                hintText: 'e.g. Solve 10 calculus integrals',
                hintStyle: typography.caption.regular.copyWith(color: colors.textMuted),
                filled: true,
                fillColor: colors.primary.withAlpha(20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colors.primary.withAlpha(50)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          backgroundColor: context.isDarkMode ? colors.surfaceSecondary : colors.surfacePrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Text('⚡', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                'Launch Co-Op Sprint',
                style: typography.subhead.bold.copyWith(color: colors.textPrimary),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rally everyone in this room for a synchronized 3-minute study sprint! All members review concurrently and earn Pod XP.',
                style: typography.caption.regular.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: colors.primary.withAlpha(50)),
                ),
                tileColor: colors.primary.withAlpha(context.isDarkMode ? 30 : 15),
                leading: const Icon(Icons.flash_on_rounded, color: Colors.amber),
                title: Text('10-Card Sprint (3 min)', style: typography.caption.bold.copyWith(color: colors.textPrimary)),
                subtitle: Text('Fast-paced rapid recall challenge', style: typography.caption.regular.copyWith(color: colors.textSecondary, fontSize: 11)),
                onTap: () {
                  Navigator.of(dialogCtx).pop();
                  cubit.startCoOpSprint(deckTitle: 'Rapid Flashcard Sprint');
                },
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: colors.syllabotAccent.withAlpha(50)),
                ),
                tileColor: colors.syllabotAccent.withAlpha(context.isDarkMode ? 30 : 15),
                leading: const Icon(Icons.quiz_rounded, color: Colors.cyan),
                title: Text('Past Questions Battle (5 min)', style: typography.caption.bold.copyWith(color: colors.textPrimary)),
                subtitle: Text('Review 15 CBT past questions together', style: typography.caption.regular.copyWith(color: colors.textSecondary, fontSize: 11)),
                onTap: () {
                  Navigator.of(dialogCtx).pop();
                  cubit.startCoOpSprint(deckTitle: 'CBT Past Questions Sprint', targetCards: 15);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
            ),
          ],
        ),
      ),
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
      },
      builder: (context, state) {
        final audience = state.ephemeralParticipants
            .where((p) => !p.isHandRaised)
            .toList();

        final hasEphemeral = state.ephemeralParticipants.isNotEmpty;

        return Scaffold(
          backgroundColor: isDark
              ? colors.backgroundPrimary
              : colors.surfacePrimary,
          appBar: AppBar(
            backgroundColor: colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: colors.textPrimary),
              onPressed: () => unawaited(context.router.maybePop()),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.room.title,
                  style: typography.headline.bold.copyWith(color: colors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  state.room.subject,
                  style: typography.caption.regular.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _LivePulseBadge(colors: colors),
                    const SizedBox(width: 8),
                    _PomodoroMiniPill(state: state, colors: colors, typography: typography),
                  ],
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                // Micro-Goal Status Pill & Ambient Soundscape Player
                _MicroGoalPill(
                  activeGoal: state.activeGoal,
                  isDark: isDark,
                  onTapEdit: () => _showGoalEditDialog(context, state.activeGoal),
                ),
                const SizedBox(height: 6),
                _AmbientSoundscapeBar(
                  state: state,
                  isDark: isDark,
                ),
                const SizedBox(height: 6),
                _AmbientActivityTicker(
                  tickerItems: state.recentActivityTicker,
                  cardsReviewed: state.cardsReviewedInSprint,
                  isDark: isDark,
                ),
                if (state.isCoOpSprintActive) ...[
                  const SizedBox(height: 6),
                  _CoOpSprintBanner(
                    state: state,
                    isDark: isDark,
                  ),
                ],
                if (state.activeSpeakerIds.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _ActiveSpeakersBanner(
                    speakerIds: state.activeSpeakerIds,
                    participants: state.ephemeralParticipants,
                    isDark: isDark,
                  ),
                ],
                const SizedBox(height: 6),

                // Main body: Silent Focus Cockpit
                Expanded(
                  child: Column(
                    children: [
                            // Silent Focus Cockpit: Body-doubling flow state
                            Expanded(
                              flex: 5,
                              child: _FocusCockpitSection(
                                participants: state.ephemeralParticipants,
                                activeSpeakerIds: state.activeSpeakerIds,
                                fallbackNames: hasEphemeral ? const [] : state.participants,
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
                            if (audience.isNotEmpty || (!hasEphemeral && state.participants.length > 1))
                              Expanded(
                                flex: 3,
                                child: _AudienceSection(
                                  audience: audience,
                                  fallbackNames: hasEphemeral ? const [] : state.participants.skip(1).toList(),
                                  colors: colors,
                                  typography: typography,
                                  isDark: isDark,
                                  l10n: l10n,
                                ),
                              ),
                          ],
                        ),
                ),

                // Floating Micro-Reaction Rail for Silent Focus
                _MicroReactionRail(
                  onReact: (emoji) {
                    context.read<LiveRoomCubit>().triggerMicroReaction(emoji);
                  },
                  isDark: isDark,
                ),

                // Bottom action bar with Voice Pod, Fast Card Logger, Whiteboard, Chat, Timer, Leave
                _BottomActionBar(
                  state: state,
                  currentUserId: widget.currentUserId,
                  colors: colors,
                  typography: typography,
                  isDark: isDark,
                  l10n: l10n,
                  onLaunchSprint: () => _showStartCoOpSprintDialog(context),
                ),
              ],
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
            color: colors.warning.withAlpha(isDark ? 30 : 15),
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
            child: const Icon(
              Icons.bolt_rounded,
              color: Colors.amber,
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
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
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
                  const Icon(Icons.check_rounded, color: Colors.white, size: 14),
                  const SizedBox(width: 3),
                  Text(
                    '+1 Card',
                    style: typography.caption.bold.copyWith(
                      color: Colors.white,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: Icon(Icons.close_rounded, size: 18, color: colors.textSecondary),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => context.read<LiveRoomCubit>().endCoOpSprint(),
          ),
        ],
      ),
    );
  }
}

// ── Micro-Goal Status Pill ───────────────────────────────────────────────────

class _MicroGoalPill extends StatelessWidget {
  const _MicroGoalPill({
    required this.activeGoal,
    required this.isDark,
    required this.onTapEdit,
  });

  final String? activeGoal;
  final bool isDark;
  final VoidCallback onTapEdit;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    final hasGoal = activeGoal != null && activeGoal!.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ShrinkableButton(
        onTap: onTapEdit,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: hasGoal
                ? colors.primary.withAlpha(isDark ? 40 : 20)
                : (isDark ? colors.surfaceSecondary : colors.surfacePrimary),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hasGoal
                  ? colors.primary.withAlpha(isDark ? 80 : 50)
                  : colors.primary.withAlpha(isDark ? 30 : 15),
            ),
          ),
          child: Row(
            children: [
              const Text('🎯', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasGoal ? 'My Goal: $activeGoal' : 'Set a micro-goal for this focus session...',
                  style: typography.caption.bold.copyWith(
                    color: hasGoal ? colors.textPrimary : colors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.edit_rounded,
                size: 14,
                color: hasGoal ? colors.primary : colors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Ambient Activity Ticker ───────────────────────────────────────────────────

class _AmbientActivityTicker extends StatelessWidget {
  const _AmbientActivityTicker({
    required this.tickerItems,
    required this.cardsReviewed,
    required this.isDark,
  });

  final List<String> tickerItems;
  final int cardsReviewed;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final latestMessage = tickerItems.isNotEmpty
        ? tickerItems.first
        : (cardsReviewed > 0
            ? '⚡️ You completed $cardsReviewed cards in this sprint!'
            : '🌱 Silent focus active. Set a goal and start reviewing.');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: colors.primary.withAlpha(isDark ? 25 : 12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: colors.primary.withAlpha(isDark ? 50 : 25),
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.bolt_rounded, size: 14, color: Colors.amber),
            const SizedBox(width: 6),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  latestMessage,
                  key: ValueKey(latestMessage),
                  style: typography.caption.medium.copyWith(
                    color: colors.textPrimary,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
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
          color: isDark ? colors.surfaceSecondary.withAlpha(150) : colors.surfacePrimary,
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
                          context.read<LiveRoomCubit>().setAmbientSoundTrack(track['name']!);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isPlaying ? colors.syllabotAccent : colors.primary)
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
                              Text(track['emoji']!, style: const TextStyle(fontSize: 11)),
                              const SizedBox(width: 4),
                              Text(
                                track['name']!,
                                style: typography.caption.bold.copyWith(
                                  fontSize: 10.5,
                                  color: isSelected ? colors.white : colors.textSecondary,
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

            // Volume indicator / popup
            PopupMenuButton<double>(
              icon: Icon(
                state.ambientAudioVolume > 0.5
                    ? Icons.volume_up_rounded
                    : (state.ambientAudioVolume > 0 ? Icons.volume_down_rounded : Icons.volume_mute_rounded),
                size: 18,
                color: isPlaying ? colors.syllabotAccent : colors.textSecondary,
              ),
              color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              itemBuilder: (_) => [
                PopupMenuItem(
                  enabled: false,
                  child: StatefulBuilder(
                    builder: (ctx, setMenuState) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ambient Volume', style: typography.caption.bold.copyWith(color: colors.textPrimary)),
                        Slider(
                          value: state.ambientAudioVolume,
                          activeColor: colors.syllabotAccent,
                          onChanged: (val) {
                            setMenuState(() {});
                            context.read<LiveRoomCubit>().setAmbientVolume(val);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
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
              (n) => EphemeralParticipant(userId: n, displayName: n, avatarUrl: ''),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isVoicePodEnabled ? cColors.warning : cColors.syllabotAccent)
                      .withAlpha(cIsDark ? 40 : 25),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isVoicePodEnabled ? Icons.record_voice_over_rounded : Icons.headphones_rounded,
                      size: 12,
                      color: isVoicePodEnabled ? cColors.warning : cColors.syllabotAccent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isVoicePodEnabled ? 'Voice Pod Active' : 'Silent Flow Cockpit',
                      style: cTypography.caption.bold.copyWith(
                        color: isVoicePodEnabled ? cColors.warning : cColors.syllabotAccent,
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
                        isSpeaking: isVoicePodEnabled &&
                            (activeSpeakerIds.contains(p.userId) ||
                             (!p.isMuted && activeSpeakerIds.isEmpty)),
                        activeGoal: activeGoal,
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
    required this.activeGoal,
    required this.isVoicePodEnabled,
  });

  final EphemeralParticipant participant;
  final dynamic colors;
  final dynamic typography;
  final bool isDark;
  final bool isSpeaking;
  final String? activeGoal;
  final bool isVoicePodEnabled;

  @override
  Widget build(BuildContext context) {
    final cColors = context.colors;
    final cTypography = context.typography;
    final cIsDark = context.isDarkMode;

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
              isGlowing: true,
              isDark: cIsDark,
            ),
            if (isVoicePodEnabled && !participant.isMuted)
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cColors.recallEasy,
                ),
                child: const Icon(Icons.mic_rounded, size: 9, color: Colors.white),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          participant.displayName.split(' ').first,
          style: cTypography.caption.medium.copyWith(color: cColors.textPrimary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: (isSpeaking ? cColors.recallEasy : cColors.primary).withAlpha(25),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            isSpeaking ? 'Speaking' : 'Deep Flow',
            style: cTypography.caption.bold.copyWith(
              color: isSpeaking ? cColors.recallEasy : cColors.primary,
              fontSize: 9.5,
            ),
          ),
        ),
        if (activeGoal != null && activeGoal!.trim().isNotEmpty) ...[
          const SizedBox(height: 3),
          Container(
            constraints: const BoxConstraints(maxWidth: 90),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: cColors.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              '🎯 $activeGoal',
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
            .map((n) => EphemeralParticipant(userId: n, displayName: n, avatarUrl: ''))
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
                            child: const Text('✋', style: TextStyle(fontSize: 8)),
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

// ── Micro Reaction Rail ──────────────────────────────────────────────────────

class _MicroReactionRail extends StatelessWidget {
  const _MicroReactionRail({
    required this.onReact,
    required this.isDark,
  });

  final ValueChanged<String> onReact;
  final bool isDark;

  static const List<String> _reactions = ['👏', '🔥', '☕️', '🧠', '🎯', '✨'];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? colors.surfaceSecondary.withAlpha(160)
            : colors.surfacePrimary.withAlpha(220),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colors.primary.withAlpha(isDark ? 40 : 20),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _reactions.map((emoji) {
          return ShrinkableButton(
            onTap: () {
              unawaited(HapticFeedback.lightImpact());
              onReact(emoji);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Bottom action bar ─────────────────────────────────────────────────────────

class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar({
    required this.state,
    required this.currentUserId,
    required this.colors,
    required this.typography,
    required this.isDark,
    required this.l10n,
    this.onLaunchSprint,
  });

  final LiveRoomState state;
  final String currentUserId;
  final dynamic colors;
  final dynamic typography;
  final bool isDark;
  final AppLocalizations l10n;
  final VoidCallback? onLaunchSprint;

  @override
  Widget build(BuildContext context) {
    final cColors = context.colors;
    final cTypography = context.typography;
    final cIsDark = context.isDarkMode;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: cIsDark ? cColors.surfaceSecondary.withAlpha(180) : cColors.surfacePrimary,
        border: Border(
          top: BorderSide(color: cColors.primary.withAlpha(20)),
        ),
      ),
      child: Row(
        children: [
          // Launch Co-Op Sprint Button
          ShrinkableButton(
            onTap: onLaunchSprint,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
              decoration: BoxDecoration(
                color: state.isCoOpSprintActive
                    ? cColors.warning.withAlpha(cIsDark ? 50 : 30)
                    : cColors.primary.withAlpha(cIsDark ? 40 : 20),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: state.isCoOpSprintActive
                      ? cColors.warning
                      : cColors.primary.withAlpha(cIsDark ? 90 : 50),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.bolt_rounded,
                    size: 16,
                    color: state.isCoOpSprintActive ? cColors.warning : cColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    state.isCoOpSprintActive ? state.formattedSprintTimer : 'Sprint',
                    style: cTypography.caption.bold.copyWith(
                      color: state.isCoOpSprintActive ? cColors.warning : cColors.primary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Fast Sprint Card Logger (+5 Cards)
          ShrinkableButton(
            onTap: () {
              unawaited(HapticFeedback.mediumImpact());
              context.read<LiveRoomCubit>().logCardReviewed(5);
              context.showSnackBar(
                message: 'Logged 5 cards in sprint! 🎯 Total: ${state.cardsReviewedInSprint + 5}',
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
              decoration: BoxDecoration(
                color: cColors.syllabotAccent.withAlpha(cIsDark ? 40 : 20),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: cColors.syllabotAccent.withAlpha(cIsDark ? 90 : 50),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.flash_on_rounded, size: 16, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text(
                    '+5 Cards',
                    style: cTypography.caption.bold.copyWith(
                      color: cColors.textPrimary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Voice Pod Toggle Button (Silent Mode vs Audio Discussion)
          Expanded(
            child: ShrinkableButton(
              onTap: () {
                unawaited(HapticFeedback.mediumImpact());
                context.read<LiveRoomCubit>().toggleVoicePod();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: state.isVoicePodEnabled
                      ? cColors.warning
                      : cColors.primary.withAlpha(cIsDark ? 50 : 30),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: state.isVoicePodEnabled
                      ? [
                          BoxShadow(
                            color: cColors.warning.withAlpha(100),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      state.isVoicePodEnabled
                          ? Icons.record_voice_over_rounded
                          : Icons.headphones_rounded,
                      color: state.isVoicePodEnabled ? cColors.white : cColors.primary,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        state.isVoicePodEnabled ? 'Voice Pod ON' : 'Silent Focus',
                        style: cTypography.footnote.bold.copyWith(
                          color: state.isVoicePodEnabled ? cColors.white : cColors.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Mic Mute / Unmute Toggle Button (Only visible when voice pod is active)
          if (state.isVoicePodEnabled) ...[
            ShrinkableButton(
              onTap: () {
                unawaited(HapticFeedback.mediumImpact());
                if (!state.isAudioConnected && state.isMuted) {
                  context.showSnackBar(
                    message: 'Connecting to room audio...',
                  );
                }
                context.read<LiveRoomCubit>().toggleMicMute();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: state.isMuted
                      ? cColors.error.withAlpha(cIsDark ? 40 : 20)
                      : cColors.recallEasy.withAlpha(cIsDark ? 50 : 30),
                  border: Border.all(
                    color: state.isMuted
                        ? cColors.error.withAlpha(cIsDark ? 100 : 70)
                        : cColors.recallEasy.withAlpha(cIsDark ? 120 : 80),
                    width: 1.5,
                  ),
                  boxShadow: !state.isMuted
                      ? [
                          BoxShadow(
                            color: cColors.recallEasy.withAlpha(80),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  state.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                  color: state.isMuted ? cColors.error : cColors.recallEasy,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],

          // In-Room Live Chat Drawer Button with Unread Badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              ShrinkableButton(
                onTap: () {
                  unawaited(HapticFeedback.lightImpact());
                  RoomChatDrawer.show(context, currentUserId: currentUserId);
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cColors.surfaceSecondary,
                    border: Border.all(color: cColors.primary.withAlpha(50)),
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: cColors.primary,
                    size: 18,
                  ),
                ),
              ),
              if (state.unreadChatCount > 0)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: cColors.error,
                      border: Border.all(color: cColors.surfacePrimary, width: 1.5),
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Center(
                      child: Text(
                        state.unreadChatCount > 9 ? '9+' : '${state.unreadChatCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),

          // Pause/Resume timer
          ShrinkableButton(
            onTap: () => context.read<LiveRoomCubit>().toggleTimerPause(),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cColors.surfaceSecondary,
                border: Border.all(color: cColors.primary.withAlpha(50)),
              ),
              child: Icon(
                state.room.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                color: cColors.primary,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Leave Room
          ShrinkableButton(
            onTap: () => unawaited(context.router.maybePop()),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cColors.error.withAlpha(25),
                border: Border.all(color: cColors.error.withAlpha(80)),
              ),
              child: Icon(
                Icons.call_end_rounded,
                color: cColors.error,
                size: 18,
              ),
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
        boxShadow: [
          BoxShadow(
            color: colors.recallEasy.withAlpha(30),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.recallEasy,
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.volume_up_rounded, size: 14, color: colors.recallEasy),
          const SizedBox(width: 6),
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
  });

  final String name;
  final dynamic colors;
  final dynamic typography;
  final double size;
  final bool isGlowing;
  final bool isDark;

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

    if (!widget.isGlowing) {
      return AppAvatar(
        customDimension: widget.size,
        name: widget.name,
        backgroundColor: cColors.primary.withAlpha(50),
        foregroundColor: cColors.primary,
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
            boxShadow: [
              BoxShadow(
                color: cColors.primary.withAlpha((80 * _pulse.value).round()),
                blurRadius: 24 * _pulse.value,
                spreadRadius: 4 * _pulse.value,
              ),
            ],
          ),
          child: child,
        );
      },
      child: AppAvatar(
        customDimension: widget.size,
        name: widget.name,
        backgroundColor: cColors.primary.withAlpha(60),
        foregroundColor: cColors.primary,
        borderColor: cColors.primary.withAlpha(150),
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
                boxShadow: [
                  BoxShadow(
                    color: cColors.error.withAlpha((80 * _fade.value).round()),
                    blurRadius: 6,
                  ),
                ],
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
