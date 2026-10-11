import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_duel_entity.dart';
import 'package:kortex/src/shared/widgets/app_avatar.dart';

/// Pre-match countdown lobby view showing matched player profiles, room code, and countdown timer.
class QuizDuelCountdownView extends StatelessWidget {
  const QuizDuelCountdownView({
    required this.myPlayer,
    required this.opponent,
    required this.remainingSeconds,
    required this.reduceMotion,
    required this.onCopyRoomCode,
    super.key,
    this.match,
  });

  final QuizDuelMatch? match;
  final QuizDuelParticipant myPlayer;
  final QuizDuelParticipant opponent;
  final int remainingSeconds;
  final bool reduceMotion;
  final ValueChanged<String> onCopyRoomCode;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Arena Battle Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colors.primary.withAlpha(isDark ? 60 : 35),
                          colors.secondary.withAlpha(isDark ? 60 : 35),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.dialog),
                      border: Border.all(
                        color: colors.primary.withAlpha(120),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.bolt_rounded,
                          color: colors.warning,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'RIVAL FOUND • 1v1 DUEL',
                          style: typography.caption.bold.copyWith(
                            color: colors.primary,
                            letterSpacing: 1.2,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Match Details Subtitle
                  Text(
                    '${match?.subject ?? "Academic"} (${match?.examBoard ?? "Standard"}) • ${match?.totalQuestions ?? 10} Questions',
                    style: typography.body.medium.copyWith(
                      color: colors.textSecondary,
                      fontSize: 13.5,
                    ),
                  ),
                  if (match?.roomCode != null &&
                      match!.roomCode!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primary.withAlpha(isDark ? 35 : 20),
                        borderRadius: BorderRadius.circular(AppRadius.micro),
                        border: Border.all(
                          color: colors.primary.withAlpha(80),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.vpn_key_rounded,
                            size: 14,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'ROOM CODE: ${match!.roomCode}',
                            style: typography.caption.bold.copyWith(
                              color: colors.primary,
                              letterSpacing: 1.4,
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            borderRadius: BorderRadius.circular(AppRadius.micro),
                            onTap: () => onCopyRoomCode(match!.roomCode!),
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: Icon(
                                Icons.copy_rounded,
                                size: 14,
                                color: colors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 36),

                  // VS Battle Ring Cards
                  MomentScale(
                    reduceMotion: reduceMotion,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 24,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? colors.surfaceTertiary.withAlpha(180)
                            : colors.surfaceSecondary.withAlpha(200),
                        borderRadius: BorderRadius.circular(AppRadius.dialog),
                        border: Border.all(
                          color: colors.primary.withAlpha(isDark ? 80 : 40),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colors.black.withAlpha(isDark ? 50 : 20),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Player 1 (You)
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: colors.primary,
                                    width: 2.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: colors.black.withAlpha(isDark ? 50 : 20),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: AppAvatar(
                                  name: myPlayer.displayName,
                                  customDimension: 68,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                myPlayer.displayName,
                                style: typography.body.bold.copyWith(
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.primary.withAlpha(35),
                                  borderRadius: BorderRadius.circular(AppRadius.micro),
                                ),
                                child: Text(
                                  '${myPlayer.eloRating} ELO',
                                  style: typography.caption.bold.copyWith(
                                    color: colors.primary,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Glowing VS Emblem
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  colors.error,
                                  colors.warning,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: colors.black.withAlpha(isDark ? 60 : 30),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Text(
                              'VS',
                              style: typography.title2.bold.copyWith(
                                color: colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),

                          // Opponent (Rival)
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: colors.secondary,
                                    width: 2.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: colors.black.withAlpha(isDark ? 50 : 20),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: AppAvatar(
                                  name: opponent.displayName,
                                  customDimension: 68,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                opponent.displayName,
                                style: typography.body.bold.copyWith(
                                  fontSize: 15,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.secondary.withAlpha(35),
                                  borderRadius: BorderRadius.circular(AppRadius.micro),
                                ),
                                child: Text(
                                  '${opponent.eloRating} ELO',
                                  style: typography.caption.bold.copyWith(
                                    color: colors.secondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Countdown Indicator Pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primary.withAlpha(isDark ? 40 : 20),
                      borderRadius: BorderRadius.circular(AppRadius.dialog),
                      border: Border.all(
                        color: colors.primary.withAlpha(80),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              colors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Starting in ${remainingSeconds > 0 ? remainingSeconds : 1} second${remainingSeconds == 1 ? '' : 's'}...',
                          style: typography.body.bold.copyWith(
                            color: colors.primary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One-shot scale-in used for the "rival found" moment, so both player cards
/// arrive together in a single beat instead of popping in instantly.
class MomentScale extends StatelessWidget {
  const MomentScale({
    required this.reduceMotion,
    required this.child,
    super.key,
  });

  final bool reduceMotion;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (reduceMotion) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.expressive,
      curve: AppMotion.easeOutCubic,
      builder: (context, t, _) => Opacity(
        opacity: t,
        child: Transform.scale(scale: 0.92 + 0.08 * t, child: child),
      ),
    );
  }
}
