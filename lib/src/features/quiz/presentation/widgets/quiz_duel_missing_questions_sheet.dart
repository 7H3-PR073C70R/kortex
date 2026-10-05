import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_sheet.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';

/// Modal bottom sheet informing the student that no past questions or study decks
/// exist for the selected course, explaining how to proceed (go online for AI or create deck).
class QuizDuelMissingQuestionsSheet extends StatelessWidget {
  const QuizDuelMissingQuestionsSheet({
    required this.subject, super.key,
    this.onRetry,
  });

  final String subject;
  final VoidCallback? onRetry;

  static Future<void> show(
    BuildContext context, {
    required String subject,
    VoidCallback? onRetry,
  }) {
    return AppAdaptiveSheet.showModal<void>(
      context: context,
      maxWidth: 600,
      builder: (_) => QuizDuelMissingQuestionsSheet(
        subject: subject,
        onRetry: onRetry,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;
    final isDesktop = AppAdaptiveSheet.isDesktopOrWeb(context);

    return Align(
      alignment: isDesktop ? Alignment.center : Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: MediaQuery.sizeOf(context).height * (isDesktop ? 0.80 : 0.85),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
            borderRadius: isDesktop
                ? BorderRadius.circular(AppRadius.dialog)
                : const BorderRadius.vertical(
                    top: Radius.circular(AppRadius.dialog),
                  ),
            border: Border.all(
              color: colors.surfaceBorder.withValues(alpha: 0.5),
            ),
            boxShadow: isDesktop
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 28,
                      offset: const Offset(0, 14),
                    ),
                  ]
                : null,
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, isDesktop ? 24 : 12, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag Handle
                  if (!isDesktop) ...[
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colors.surfaceBorder,
                          borderRadius: BorderRadius.circular(AppRadius.badge),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Glowing Warning / Offline Icon
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: colors.warning.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colors.warning.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.cloud_off_rounded,
                        size: 32,
                        color: colors.warning,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title
                  Text(
                    'No Questions for $subject',
                    style: typography.title2.bold.copyWith(
                      color: colors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  // Subtitle explanation
                  Text(
                    "We couldn't find any saved past questions or flashcards for $subject on your device.",
                    style: typography.body.regular.copyWith(
                      color: colors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Option 1: Online Mode
                  _buildOptionCard(
                    context,
                    icon: Icons.wifi_rounded,
                    iconBg: colors.primary.withValues(alpha: 0.12),
                    iconColor: colors.primary,
                    title: 'Connect to the Internet',
                    description:
                        'Go online so our AI can dynamically generate verified quiz questions for $subject.',
                  ),
                  const SizedBox(height: 12),

                  // Option 2: Study Deck Mode
                  _buildOptionCard(
                    context,
                    icon: Icons.auto_stories_rounded,
                    iconBg: colors.syllabotAccent.withValues(alpha: 0.12),
                    iconColor: colors.syllabotAccent,
                    title: 'Create a Flashcard Deck',
                    description:
                        'Add question-and-answer study cards for $subject to practice and duel anytime, even completely offline.',
                  ),
                  const SizedBox(height: 24),

                  // Primary CTA: Create Deck
                  AppButton(
                    text: 'Create Study Deck for $subject',
                    prefixIcon: const Icon(Icons.add_rounded),
                    onPressed: () {
                      AppFeedback.selection();
                      Navigator.of(context).pop();
                      unawaited(
                        context.router.push(
                          CreateDeckRoute(
                            mappedSubject: subject,
                            courseTitle: subject,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),

                  // Secondary CTA: Try Again (Online)
                  if (onRetry != null) ...[
                    AppButton(
                      text: 'Try Again (Online)',
                      variant: AppButtonVariant.secondary,
                      prefixIcon: const Icon(Icons.refresh_rounded),
                      onPressed: () {
                        AppFeedback.light();
                        Navigator.of(context).pop();
                        onRetry!();
                      },
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Dismiss button
                  AppButton(
                    text: 'Choose Another Subject',
                    variant: AppButtonVariant.ghost,
                    onPressed: () {
                      AppFeedback.light();
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard(
    BuildContext context, {
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? colors.surfacePrimary.withValues(alpha: 0.5)
            : colors.surfaceSecondary.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: colors.surfaceBorder.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(AppRadius.badge),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: typography.body.semiBold.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: typography.caption.regular.copyWith(
                    color: colors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
