import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/monetization/domain/services/subscription_guard.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_result_entity.dart';
import 'package:kortex/src/features/quiz/domain/services/assessment_orchestrator_service.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/quiz_results_actions_bar.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/quiz_shell.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Middle section displaying Academic Readiness, Quick Actions, Socratic AI
/// Remediation, Topic Weaknesses, and Focus Next guidance.
class QuizResultsBreakdownSection extends StatelessWidget {
  const QuizResultsBreakdownSection({
    required this.result,
    required this.mistakes,
    required this.hasQuestions,
    required this.onTryAgain,
    required this.onPracticeFlashcards,
    required this.onAskClass,
    required this.onShare,
    this.orchestratorService,
    this.subscriptionGuard,
    super.key,
  });

  final QuizResultEntity result;
  final int mistakes;
  final bool hasQuestions;
  final VoidCallback onTryAgain;
  final VoidCallback onPracticeFlashcards;
  final VoidCallback onAskClass;
  final VoidCallback onShare;
  final AssessmentOrchestratorService? orchestratorService;
  final SubscriptionGuard? subscriptionGuard;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;
    final reduceMotion = quizReduceMotion(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Academic Readiness Index Card
        if (orchestratorService != null)
          _buildReadinessCard(context, isDark),

        const SizedBox(height: 18),

        // 2. Seamless Quick Study Actions
        QuizStaggeredFade(
          index: 2,
          reduceMotion: reduceMotion,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: colors.surfaceBorder),
              boxShadow: [
                BoxShadow(
                  color: colors.black.withAlpha(isDark ? 20 : 4),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                if (hasQuestions) ...[
                  Expanded(
                    child: QuizResultQuickActionButton(
                      icon: Icons.replay_rounded,
                      label: 'Retake',
                      color: colors.primary,
                      onTap: onTryAgain,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: QuizResultQuickActionButton(
                    icon: Icons.style_rounded,
                    label: 'Flashcards',
                    color: colors.syllabotAccent,
                    onTap: onPracticeFlashcards,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: QuizResultQuickActionButton(
                    icon: Icons.forum_rounded,
                    label: 'Ask Class',
                    color: colors.info,
                    onTap: onAskClass,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: QuizResultQuickActionButton(
                    icon: Icons.share_rounded,
                    label: 'Share',
                    color: colors.textSecondary,
                    onTap: onShare,
                  ),
                ),
              ],
            ),
          ),
        ),

        // 3. Socratic AI Concept Remediation Banner
        if (mistakes > 0)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colors.syllabotAccent.withAlpha(isDark ? 40 : 20),
                    colors.primary.withAlpha(isDark ? 30 : 15),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(
                  color: colors.syllabotAccent.withAlpha(isDark ? 90 : 60),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.psychology_rounded,
                        color: colors.syllabotAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Socratic AI Concept Remediation',
                        style: typography.callout.bold.copyWith(
                          color: colors.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'You missed $mistakes question${mistakes > 1 ? 's' : ''}. '
                    'Syllabot has extracted key concept rules into an instant review recovery deck.',
                    style: typography.footnote.regular.copyWith(
                      color: colors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: onPracticeFlashcards,
                    borderRadius: BorderRadius.circular(AppRadius.badge),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: colors.syllabotAccent,
                        borderRadius: BorderRadius.circular(AppRadius.badge),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.auto_awesome_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Launch Socratic Recovery Deck',
                            style: typography.caption.bold.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 24),

        // 4. Topic breakdown
        Text(
          l10n.quizTopicWeakness,
          style: typography.title3.bold.copyWith(color: colors.textPrimary),
        ),
        const SizedBox(height: 12),
        if (result.weaknesses.isEmpty)
          QuizStaggeredFade(
            index: 1,
            reduceMotion: reduceMotion,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Every topic looks solid. Keep practising to hold it.',
                style: typography.body.regular.copyWith(color: colors.success),
              ),
            ),
          )
        else
          _buildWeaknessList(context, isDark, reduceMotion),

        // 5. What to look at next
        if (mistakes > 0) ...[
          const SizedBox(height: 24),
          QuizStaggeredFade(
            index: 2,
            reduceMotion: reduceMotion,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.warning.withValues(alpha: isDark ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(
                  color: colors.warning.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: colors.warning.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.psychology_alt_rounded,
                      color: colors.warning,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Where to focus next',
                          style: typography.subhead.bold.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$mistakes ${mistakes == 1 ? 'question' : 'questions'} '
                          'need another pass. Reviewing them now is when it sticks.',
                          style: typography.caption.regular.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildReadinessCard(BuildContext context, bool isDark) {
    final colors = context.colors;
    final typography = context.typography;
    final readiness = orchestratorService!
        .calculateReadinessIndex(
          recentScorePercent: result.scorePercent.toDouble(),
        )
        .round();
    final readinessColor = readiness >= 75
        ? colors.success
        : (readiness >= 55 ? colors.syllabotAccent : colors.warning);

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: readinessColor.withAlpha(isDark ? 30 : 15),
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: readinessColor.withAlpha(isDark ? 80 : 50)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: readinessColor.withAlpha(isDark ? 50 : 25),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.speed_rounded,
                color: readinessColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Academic Readiness Index',
                    style: typography.caption.bold.copyWith(
                      color: colors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$readiness% Final Exam Mastery',
                    style: typography.callout.bold.copyWith(
                      color: colors.textPrimary,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: readinessColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                readiness >= 75
                    ? 'Exam Ready'
                    : (readiness >= 55
                        ? 'Building Mastery'
                        : 'Action Required'),
                style: typography.caption.bold.copyWith(
                  color: Colors.white,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeaknessList(
    BuildContext context,
    bool isDark,
    bool reduceMotion,
  ) {
    final colors = context.colors;
    final typography = context.typography;
    final isPro = subscriptionGuard?.canAccessAiDiagnostics() ?? false;
    final displayedWeaknesses =
        isPro ? result.weaknesses : result.weaknesses.take(1).toList();
    final hiddenCount = result.weaknesses.length - displayedWeaknesses.length;

    return Column(
      children: [
        ...displayedWeaknesses.asMap().entries.map((entry) {
          final weakness = entry.value;
          final acc = (weakness.accuracy * 100).toInt();
          final isWeak = weakness.isWeak;
          final badgeColor = isWeak ? colors.error : colors.success;

          return QuizStaggeredFade(
            index: 1 + (entry.key % 6),
            distance: 10,
            reduceMotion: reduceMotion,
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(
                  color: isWeak
                      ? colors.error.withValues(alpha: 0.3)
                      : colors.surfaceBorder,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.black.withAlpha(isDark ? 20 : 4),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          weakness.subTopic,
                          style: typography.body.bold.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${weakness.correctCount} of '
                          '${weakness.totalQuestions} correct',
                          style: typography.caption.regular.copyWith(
                            color: colors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.badge),
                      border: Border.all(
                        color: badgeColor.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      '$acc%',
                      style: typography.caption.bold.copyWith(
                        color: badgeColor,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        if (hiddenCount > 0)
          QuizStaggeredFade(
            index: 2,
            distance: 10,
            reduceMotion: reduceMotion,
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colors.primary.withAlpha(isDark ? 35 : 18),
                    if (isDark)
                      colors.surfaceSecondary
                    else
                      colors.surfacePrimary,
                  ],
                ),
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(
                  color: colors.primary.withAlpha(isDark ? 80 : 50),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colors.primary.withAlpha(25),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.psychology_rounded,
                      color: colors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$hiddenCount more cognitive weakness breakdown${hiddenCount > 1 ? 's' : ''}',
                          style: typography.body.bold.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Unlock complete AI diagnostic insights and personalized weak-point flashcards',
                          style: typography.caption.regular.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ShrinkableButton(
                    onTap: () => subscriptionGuard?.requirePro(
                      context,
                      featureName: 'Cognitive AI Diagnostics',
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(AppRadius.card - 4),
                      ),
                      child: Text(
                        'Unlock',
                        style: typography.caption.bold.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
