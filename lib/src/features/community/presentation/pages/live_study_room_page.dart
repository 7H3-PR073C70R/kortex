import 'dart:async';
import 'dart:math' as math;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/data/client/ephemeral_presence_client.dart';
import 'package:kortex/src/features/community/domain/entities/study_room_entity.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';
import 'package:kortex/src/features/community/domain/repositories/ephemeral_room_repository.dart';
import 'package:kortex/src/features/community/presentation/bloc/live_room_cubit.dart';
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
    return BlocProvider<LiveRoomCubit>(
      create: (_) => LiveRoomCubit(
        initialRoom: room,
        repository: locator<CommunityRepository>(),
        ephemeralRepository: locator<EphemeralRoomRepository>(),
        currentUserId: userStorage.getUserId(),
        currentUserName: userStorage.getUserDisplayName() ?? 'You',
        currentUserAvatar: userStorage.getUserAvatarUrl() ?? '',
      ),
      child: const _LiveStudyRoomView(),
    );
  }
}

class _LiveStudyRoomView extends StatelessWidget {
  const _LiveStudyRoomView();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    return BlocBuilder<LiveRoomCubit, LiveRoomState>(
      builder: (context, state) {
        final onStage = state.ephemeralParticipants
            .where((p) => p.isHandRaised)
            .toList();
        final audience = state.ephemeralParticipants
            .where((p) => !p.isHandRaised)
            .toList();

        // Fallback: use string list if no ephemeral participants yet
        final hasEphemeral = state.ephemeralParticipants.isNotEmpty;

        return Scaffold(
          backgroundColor: isDark
              ? colors.backgroundPrimary
              : colors.surfacePrimary,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
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
              // Live badge + timer mini pill
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
                // Stage section — participants with hand raised
                Expanded(
                  flex: 5,
                  child: _StageSection(
                    onStage: onStage,
                    fallbackNames: hasEphemeral ? const [] : state.participants,
                    colors: colors,
                    typography: typography,
                    isDark: isDark,
                    subject: state.room.subject,
                    participantCount: hasEphemeral
                        ? state.ephemeralParticipants.length
                        : state.participants.length,
                  ),
                ),

                const SizedBox(height: 2),

                // Audience section — listeners
                if (audience.isNotEmpty || (!hasEphemeral && state.participants.length > 1))
                  Expanded(
                    flex: 3,
                    child: _AudienceSection(
                      audience: audience,
                      fallbackNames: hasEphemeral ? const [] : state.participants.skip(1).toList(),
                      colors: colors,
                      typography: typography,
                      isDark: isDark,
                    ),
                  ),

                // Bottom action bar
                _BottomActionBar(
                  state: state,
                  colors: colors,
                  typography: typography,
                  isDark: isDark,
                  l10n: l10n,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Stage Section ──────────────────────────────────────────────────────────────

class _StageSection extends StatelessWidget {
  const _StageSection({
    required this.onStage,
    required this.fallbackNames,
    required this.colors,
    required this.typography,
    required this.isDark,
    required this.subject,
    required this.participantCount,
  });

  final List<EphemeralParticipant> onStage;
  final List<String> fallbackNames;
  final dynamic colors;
  final dynamic typography;
  final bool isDark;
  final String subject;
  final int participantCount;

  @override
  Widget build(BuildContext context) {
    final cColors = context.colors;
    final cTypography = context.typography;
    final cIsDark = context.isDarkMode;

    final speakers = onStage.isNotEmpty
        ? onStage
        : fallbackNames
            .take(3)
            .map(
              (n) => EphemeralParticipant(userId: n, displayName: n, avatarUrl: ''),
            )
            .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cColors.primary.withAlpha(cIsDark ? 30 : 15),
            cColors.primary.withAlpha(cIsDark ? 10 : 5),
          ],
        ),
      ),
      child: Column(
        children: [
          // Topic label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: cColors.primary.withAlpha(cIsDark ? 50 : 30),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              subject.toUpperCase(),
              style: cTypography.caption.bold.copyWith(
                color: cColors.primary,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const Spacer(),

          // Speakers row with glow rings
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 24,
            runSpacing: 16,
            children: speakers.isEmpty
                ? [
                    _GlowAvatar(
                      name: 'Start',
                      colors: cColors,
                      typography: cTypography,
                      size: 72,
                      isGlowing: false,
                      isDark: cIsDark,
                    ),
                  ]
                : speakers
                    .take(5)
                    .map(
                      (p) => _SpeakerTile(
                        participant: p,
                        colors: cColors,
                        typography: cTypography,
                        isDark: cIsDark,
                      ),
                    )
                    .toList(),
          ),

          const Spacer(),

          // Participant count + join hint
          Text(
            '$participantCount in this room',
            style: cTypography.caption.regular.copyWith(
              color: cColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ── Speaker tile (on-stage) ──────────────────────────────────────────────────

class _SpeakerTile extends StatelessWidget {
  const _SpeakerTile({
    required this.participant,
    required this.colors,
    required this.typography,
    required this.isDark,
  });

  final EphemeralParticipant participant;
  final dynamic colors;
  final dynamic typography;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final cColors = context.colors;
    final cTypography = context.typography;
    final cIsDark = context.isDarkMode;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _GlowAvatar(
          name: participant.displayName,
          colors: cColors,
          typography: cTypography,
          size: 64,
          isGlowing: true,
          isDark: cIsDark,
        ),
        const SizedBox(height: 8),
        Text(
          participant.displayName.split(' ').first,
          style: cTypography.caption.medium.copyWith(color: cColors.textPrimary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Icon(Icons.mic_rounded, size: 12, color: cColors.primary),
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
  });

  final List<EphemeralParticipant> audience;
  final List<String> fallbackNames;
  final dynamic colors;
  final dynamic typography;
  final bool isDark;

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
            'Audience',
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
                    AppAvatar(
                      customDimension: 36,
                      name: p.displayName,
                      backgroundColor: cColors.primary.withAlpha(40),
                      foregroundColor: cColors.primary,
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

// ── Bottom action bar ─────────────────────────────────────────────────────────

class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar({
    required this.state,
    required this.colors,
    required this.typography,
    required this.isDark,
    required this.l10n,
  });

  final LiveRoomState state;
  final dynamic colors;
  final dynamic typography;
  final bool isDark;
  final dynamic l10n;

  @override
  Widget build(BuildContext context) {
    final cColors = context.colors;
    final cTypography = context.typography;
    final cIsDark = context.isDarkMode;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: cIsDark ? cColors.surfaceSecondary.withAlpha(180) : cColors.surfacePrimary,
        border: Border(
          top: BorderSide(color: cColors.primary.withAlpha(20)),
        ),
      ),
      child: Row(
        children: [
          // Raise Hand — primary CTA
          Expanded(
            flex: 3,
            child: ShrinkableButton(
              onTap: () {
                unawaited(HapticFeedback.mediumImpact());
                context.read<LiveRoomCubit>().toggleHandRaise();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: state.isHandRaised ? cColors.primary : cColors.primary.withAlpha(cIsDark ? 50 : 30),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: state.isHandRaised
                      ? [BoxShadow(color: cColors.primary.withAlpha(100), blurRadius: 12, spreadRadius: 2)]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      state.isHandRaised ? Icons.pan_tool_rounded : Icons.pan_tool_outlined,
                      color: state.isHandRaised ? Colors.white : cColors.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      state.isHandRaised ? 'On Stage' : 'Raise Hand',
                      style: cTypography.footnote.bold.copyWith(
                        color: state.isHandRaised ? Colors.white : cColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Pause/Resume timer
          ShrinkableButton(
            onTap: () => context.read<LiveRoomCubit>().toggleTimerPause(),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cColors.surfaceSecondary,
                border: Border.all(color: cColors.primary.withAlpha(50)),
              ),
              child: Icon(
                state.room.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                color: cColors.primary,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Leave
          ShrinkableButton(
            onTap: () => unawaited(context.router.maybePop()),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.redAccent.withAlpha(30),
                border: Border.all(color: Colors.redAccent.withAlpha(80)),
              ),
              child: const Icon(
                Icons.call_end_rounded,
                color: Colors.redAccent,
                size: 20,
              ),
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
    final cTypography = context.typography;
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
                color: Colors.redAccent.withValues(alpha: _fade.value),
                boxShadow: [
                  BoxShadow(
                    color: Colors.redAccent.withAlpha((80 * _fade.value).round()),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 5),
            Text(
              'LIVE',
              style: cTypography.caption.bold.copyWith(
                color: Colors.redAccent.withValues(alpha: _fade.value),
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
