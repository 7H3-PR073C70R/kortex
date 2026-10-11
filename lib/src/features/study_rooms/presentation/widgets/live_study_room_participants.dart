import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/study_rooms/domain/entities/ephemeral_participant.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/live_study_room_audio_widgets.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_avatar.dart';

/// Silent body-doubling cockpit displaying foreground scholars and study metrics.
class FocusCockpitSection extends StatelessWidget {
  const FocusCockpitSection({
    required this.participants,
    required this.activeSpeakerIds,
    required this.fallbackNames,
    required this.isDark,
    required this.subject,
    required this.participantCount,
    required this.activeGoal,
    required this.isVoicePodEnabled,
    super.key,
  });

  final List<EphemeralParticipant> participants;
  final Set<String> activeSpeakerIds;
  final List<String> fallbackNames;
  final bool isDark;
  final String subject;
  final int participantCount;
  final String? activeGoal;
  final bool isVoicePodEnabled;

  @override
  Widget build(BuildContext context) {
    final cColors = context.colors;
    final cTypography = context.typography;
    final cIsDark = context.isDarkMode;
    final l10n = context.l10n;

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
                    GlowAvatar(
                      name: 'You',
                      size: 60,
                      isGlowing: true,
                      isDark: cIsDark,
                    ),
                  ]
                : scholars
                      .take(6)
                      .map(
                        (p) => FocusParticipantTile(
                          participant: p,
                          isDark: cIsDark,
                          isSpeaking:
                              isVoicePodEnabled &&
                              activeSpeakerIds.contains(p.userId),
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

/// Tile representing an active scholar in the cockpit grid.
class FocusParticipantTile extends StatelessWidget {
  const FocusParticipantTile({
    required this.participant,
    required this.isDark,
    required this.isSpeaking,
    required this.isVoicePodEnabled,
    super.key,
  });

  final EphemeralParticipant participant;
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

    if (participant.isHandRaised) {
      statusLabel = 'Hand Raised';
      statusColor = cColors.warning;
    } else if (participant.isAway) {
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
            GlowAvatar(
              name: participant.displayName,
              size: 56,
              isGlowing: !participant.isAway,
              isDark: cIsDark,
              glowColor: statusColor,
            ),
            if (participant.isHandRaised)
              Positioned(
                top: 0,
                left: 0,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cColors.warning,
                    boxShadow: [
                      BoxShadow(
                        color: cColors.warning.withAlpha(120),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Text(
                    '✋',
                    style: TextStyle(fontSize: 10),
                  ),
                ),
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
              if (participant.isHandRaised) ...[
                Text('✋ ', style: context.typography.body.regular.copyWith(fontSize: 8)),
              ] else if (participant.isAiBuddy) ...[
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

/// Audience / passive listening participants section.
class AudienceSection extends StatelessWidget {
  const AudienceSection({
    required this.audience,
    required this.fallbackNames,
    required this.isDark,
    super.key,
  });

  final List<EphemeralParticipant> audience;
  final List<String> fallbackNames;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final cColors = context.colors;
    final cTypography = context.typography;
    final l10n = context.l10n;

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
