import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';

/// Active radar search and room code lobby display during 1v1 duel matchmaking.
class QuizDuelSearchingRadarView extends StatelessWidget {
  const QuizDuelSearchingRadarView({
    required this.pulseController,
    required this.activeRoomCode,
    required this.searchSeconds,
    required this.selectedSubject,
    required this.resolvedExamBoard,
    required this.selectedQuestionCount,
    required this.onCopyCode,
    required this.onShareInvite,
    super.key,
  });

  final AnimationController pulseController;
  final String? activeRoomCode;
  final int searchSeconds;
  final String selectedSubject;
  final String resolvedExamBoard;
  final int selectedQuestionCount;
  final void Function(String code) onCopyCode;
  final void Function(String code) onShareInvite;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            AnimatedBuilder(
              animation: pulseController,
              builder: (context, child) {
                return Container(
                  width: 96 + (pulseController.value * 18),
                  height: 96 + (pulseController.value * 18),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.primary.withValues(
                      alpha: (0.12 - (pulseController.value * 0.08)).clamp(0.0, 1.0),
                    ),
                    border: Border.all(
                      color: colors.primary.withValues(
                        alpha: (0.4 + (pulseController.value * 0.4)).clamp(0.0, 1.0),
                      ),
                      width: 2.5,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.primary,
                        boxShadow: [
                          BoxShadow(
                            color: colors.black.withValues(
                              alpha: isDark ? 0.4 : 0.15,
                            ),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          activeRoomCode != null
                              ? Icons.vpn_key_rounded
                              : Icons.radar_rounded,
                          color: colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            if (activeRoomCode != null) ...[
              // Private Room Active Display
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(
                    color: colors.primary.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'ROOM CODE: ',
                      style: typography.caption.bold.copyWith(
                        color: colors.textSecondary,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      activeRoomCode!,
                      style: typography.title2.bold.copyWith(
                        color: colors.primary,
                        letterSpacing: 3,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => onCopyCode(activeRoomCode!),
                      child: Icon(
                        Icons.copy_rounded,
                        color: colors.primary,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Waiting for friend to join with code...',
                style: typography.body.bold.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Share this 6-character code with your study partner to connect!',
                textAlign: TextAlign.center,
                style: typography.caption.regular.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => onShareInvite(activeRoomCode!),
                icon: const Icon(Icons.share_rounded, size: 16),
                label: const Text('Share Code & Invite'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.primary,
                  side: BorderSide(color: colors.primary.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.badge),
                  ),
                ),
              ),
            ] else ...[
              // Public Quick Match Active Display
              Text(
                searchSeconds < 4
                    ? 'Scanning online scholars in $selectedSubject…'
                    : searchSeconds < 8
                        ? 'Expanding campus matchmaking radius…'
                        : searchSeconds < 12
                            ? 'Rival found! Synchronizing exam room…'
                            : 'Connecting with AI study-buddy…',
                style: typography.title3.bold.copyWith(
                  color: colors.textPrimary,
                  fontSize: 15,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                '$selectedSubject ($resolvedExamBoard) • $selectedQuestionCount Questions\nInstant match in ~12 seconds',
                textAlign: TextAlign.center,
                style: typography.caption.regular.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
