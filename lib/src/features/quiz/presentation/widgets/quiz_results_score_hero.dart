import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_result_entity.dart';
import 'package:kortex/src/features/quiz/domain/logic/academic_grade_evaluator.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_session_state.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/quiz_shell.dart';

/// Standard hero: an animated arc drawing the score, then the number
/// counting up to meet it. One moment, one number, no modal.
class QuizScoreHero extends StatelessWidget {
  const QuizScoreHero({
    required this.result,
    this.courseCode,
    super.key,
  });

  final QuizResultEntity result;
  final String? courseCode;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;
    final reduceMotion = quizReduceMotion(context);
    final score = result.scorePercent;
    final isPassed = score >= kQuizPassScore;
    final gradeColor = isPassed ? colors.success : colors.warning;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            gradeColor.withValues(alpha: isDark ? 0.25 : 0.12),
            (isDark ? colors.surfaceSecondary : colors.surfacePrimary)
                .withValues(alpha: 0.95),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(AppRadius.panel),
        border: Border.all(color: gradeColor.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: colors.black.withAlpha(isDark ? 25 : 6),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            width: 168,
            height: 168,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 700),
              curve: AppMotion.easeOutCubic,
              builder: (context, t, _) => Semantics(
                label: 'Score: $score%',
                child: CustomPaint(
                  painter: QuizScoreArcPainter(
                    progress: t,
                    color: gradeColor,
                    trackColor: colors.surfaceBorder,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(score * t).round()}%',
                          style: typography.largeTitle.bold.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'score',
                          style: typography.caption.regular.copyWith(
                            color: colors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isPassed ? 'You scored $score%' : 'You scored $score% this time',
            style: typography.title3.bold.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            '${result.correctAnswers} of ${result.totalQuestions} '
            'questions correct',
            style: typography.body.regular.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          // Real-World Standard Grade Badge
          () {
            final activeTrack =
                context.watch<AuthBloc?>()?.state.userProfile?.targetTrack;
            final gradeResult = AcademicGradeEvaluator.evaluate(
              scorePercent: score.toDouble(),
              track: activeTrack ?? courseCode,
            );

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: gradeResult.gradeColor.withAlpha(isDark ? 35 : 18),
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(
                  color: gradeResult.gradeColor.withAlpha(isDark ? 90 : 60),
                ),
              ),
              child: Column(
                children: [
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Icon(
                        Icons.verified_rounded,
                        size: 16,
                        color: gradeResult.gradeColor,
                      ),
                      Text(
                        'Real-World Grade: ${gradeResult.grade}',
                        style: typography.callout.bold.copyWith(
                          color: gradeResult.gradeColor,
                          fontSize: 14,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: gradeResult.gradeColor.withAlpha(
                            isDark ? 50 : 30,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          gradeResult.classification,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: typography.caption.bold.copyWith(
                            color: gradeResult.gradeColor,
                            fontSize: 10.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${gradeResult.standard} • ${gradeResult.remark}',
                    textAlign: TextAlign.center,
                    style: typography.footnote.regular.copyWith(
                      color: colors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            );
          }(),
          if (result.id.startsWith('day_one_diagnostic') ||
              result.quizTitle.toLowerCase().contains('diagnostic')) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: colors.primary.withAlpha(isDark ? 40 : 20),
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(
                  color: colors.primary.withAlpha(isDark ? 100 : 70),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: 16,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Day-One Readiness Calibrated! 🎯',
                        style: typography.caption.bold.copyWith(
                          color: colors.primary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your baseline readiness score is now unlocked on your executive dashboard and trend charts.',
                    textAlign: TextAlign.center,
                    style: typography.caption.regular.copyWith(
                      color: colors.textSecondary,
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Millionaire hero: the climb result, with the banked prize stated plainly.
class QuizMillionaireHero extends StatelessWidget {
  const QuizMillionaireHero({
    required this.currentTier,
    required this.bankedTier,
    required this.speedBonusXp,
    required this.isWalkedAway,
    super.key,
  });

  final int currentTier;
  final int bankedTier;
  final int speedBonusXp;
  final bool isWalkedAway;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;
    final reachedTop = currentTier >= 12;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            if (isDark) colors.surfaceSecondary else colors.surfacePrimary,
            if (isDark) colors.backgroundSecondary else colors.surfaceSecondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.panel),
        border: Border.all(
          color: isWalkedAway || reachedTop
              ? colors.warning.withValues(alpha: 0.6)
              : colors.success.withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: reachedTop
                    ? [colors.warning, colors.warning.withAlpha(200)]
                    : isWalkedAway
                    ? [colors.success, colors.success.withAlpha(200)]
                    : [colors.syllabotAccent, colors.primary],
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              reachedTop
                  ? Icons.emoji_events_rounded
                  : isWalkedAway
                  ? Icons.savings_rounded
                  : Icons.military_tech_rounded,
              size: 36,
              color: colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            reachedTop
                ? 'You reached the top'
                : isWalkedAway
                ? 'You cashed out'
                : 'Tier $currentTier reached',
            textAlign: TextAlign.center,
            style: typography.title3.bold.copyWith(color: colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            reachedTop
                ? 'All 12 tiers, one after another. The whole ladder is yours.'
                : isWalkedAway
                ? 'Your Tier $bankedTier prize is banked and stays with you.'
                : 'You climbed to Tier $currentTier. Anything you banked stays with you.',
            textAlign: TextAlign.center,
            style: typography.footnote.regular.copyWith(
              color: colors.white.withAlpha(200),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: colors.white.withValues(alpha: 0.15)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                QuizStatColumn(
                  title: 'Tier',
                  value: '$currentTier / 12',
                  color: colors.warning,
                ),
                Container(
                  width: 1,
                  height: 28,
                  color: colors.white.withAlpha(50),
                ),
                QuizStatColumn(
                  title: 'Speed bonus',
                  value: '+$speedBonusXp XP',
                  color: colors.success,
                ),
                Container(
                  width: 1,
                  height: 28,
                  color: colors.white.withAlpha(50),
                ),
                QuizStatColumn(
                  title: 'Banked XP',
                  value: '${(currentTier * 100) + speedBonusXp}',
                  color: colors.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The score ring behind the counting number.
class QuizScoreArcPainter extends CustomPainter {
  const QuizScoreArcPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  /// 0 → 1 sweep of the arc.
  final double progress;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = trackColor;
    canvas.drawArc(rect, 0, 2 * 3.141592653589793, false, track);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(
      rect,
      -1.5707963267948966,
      2 * 3.141592653589793 * progress,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(QuizScoreArcPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.trackColor != trackColor;
}

class QuizStatColumn extends StatelessWidget {
  const QuizStatColumn({
    required this.title,
    required this.value,
    required this.color,
    super.key,
  });

  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: typography.caption.bold.copyWith(
            color: colors.white.withAlpha(180),
            fontSize: 10.5,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: typography.subhead.bold.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
