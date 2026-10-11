import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/study_rooms/domain/entities/ephemeral_participant.dart';
import 'package:kortex/src/features/study_rooms/presentation/bloc/live_room_cubit.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/live_study_room_audio_widgets.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_animated_entrance.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Banner shown when WebRTC / audio stream reconnection is in progress.
class ReconnectingBanner extends StatelessWidget {
  const ReconnectingBanner({
    required this.attempt,
    required this.onRetry,
    required this.isDark,
    super.key,
  });

  final int attempt;
  final VoidCallback onRetry;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: colors.warning.withAlpha(isDark ? 35 : 20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colors.warning.withAlpha(isDark ? 80 : 50),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(colors.warning),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              attempt > 1
                  ? 'Reconnecting to room audio (attempt $attempt)...'
                  : 'Audio stream interrupted. Reconnecting...',
              style: typography.caption.medium.copyWith(
                color: colors.warning,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onRetry,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Text(
                'Retry',
                style: typography.caption.bold.copyWith(
                  color: colors.warning,
                  fontSize: 12,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Banner displaying active Co-Op Sprint countdown and card increment action.
class CoOpSprintBanner extends StatelessWidget {
  const CoOpSprintBanner({
    required this.state,
    required this.isDark,
    super.key,
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
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
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
          const SizedBox(width: 4),
          ShrinkableButton(
            onTap: () {
              unawaited(HapticFeedback.mediumImpact());
              context.read<LiveRoomCubit>().logCardReviewed();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
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
                    size: 13,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '+1 Card',
                    style: typography.caption.bold.copyWith(
                      color: colors.white,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
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

/// Floating banner showing who is currently speaking on voice.
class ActiveSpeakersBanner extends StatelessWidget {
  const ActiveSpeakersBanner({
    required this.speakerIds,
    required this.participants,
    required this.isDark,
    super.key,
  });

  final Set<String> speakerIds;
  final List<EphemeralParticipant> participants;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    if (speakerIds.isEmpty) return const SizedBox.shrink();

    final speakingUsers = participants
        .where((p) => speakerIds.contains(p.userId))
        .toList();

    final names = speakingUsers.isNotEmpty
        ? speakingUsers.map((p) => p.displayName).join(', ')
        : 'Peer';

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
          InRoomEqualizerVisualizer(color: colors.recallEasy),
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

/// Live pulse badge indicating room is currently active.
class LivePulseBadge extends StatelessWidget {
  const LivePulseBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final cColors = context.colors;
    final cTypography = context.typography;
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cColors.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cColors.error.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppPulsingBeacon(
            color: cColors.error,
            size: 6,
            pulseSpread: 4,
          ),
          const SizedBox(width: 6),
          Text(
            l10n.liveIndicator,
            style: cTypography.caption.bold.copyWith(
              color: cColors.error,
              letterSpacing: 1.2,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
