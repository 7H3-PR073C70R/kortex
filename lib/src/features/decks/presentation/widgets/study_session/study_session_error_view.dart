import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_back_button.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Full-screen error / empty state card displayed when a study session fails or has no cards.
class StudySessionErrorView extends StatelessWidget {
  const StudySessionErrorView({
    required this.errorMessage,
    super.key,
  });

  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final isNoCards = errorMessage?.toLowerCase().contains('no cards') == true ||
        errorMessage?.toLowerCase().contains('no flashcards') == true;

    return Column(
      children: [
        // Top Navigation Bar
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (AppBackButton.shouldShow(context))
                const AppBackButton()
              else
                TextButton.icon(
                  onPressed: () => context.router.maybePop(),
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Exit'),
                  style: TextButton.styleFrom(
                    foregroundColor: colors.textSecondary,
                  ),
                ),
              Text(
                'Study Session',
                style: typography.subhead.bold.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(width: 44),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? colors.surfaceSecondary.withAlpha(140)
                        : colors.surfacePrimary,
                    borderRadius: BorderRadius.circular(
                      AppRadius.dialog,
                    ),
                    border: Border.all(
                      color: colors.primary.withAlpha(
                        isDark ? 60 : 30,
                      ),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colors.black.withAlpha(
                          isDark ? 40 : 15,
                        ),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Glowing Icon Container
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              colors.primary.withAlpha(
                                isDark ? 70 : 35,
                              ),
                              colors.syllabotAccent.withAlpha(
                                isDark ? 50 : 20,
                              ),
                            ],
                          ),
                          border: Border.all(
                            color: colors.primary.withAlpha(
                              isDark ? 100 : 50,
                            ),
                          ),
                        ),
                        child: Icon(
                          isNoCards
                              ? Icons.style_outlined
                              : Icons.error_outline_rounded,
                          size: 32,
                          color: isNoCards
                              ? colors.primary
                              : colors.warning,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        isNoCards
                            ? 'No Flashcards Yet'
                            : 'Unable to Load Session',
                        textAlign: TextAlign.center,
                        style: typography.title3.bold.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isNoCards
                            ? 'This deck does not have any flashcards yet. Generate cards with Syllabot AI or create them manually to start active recall.'
                            : (errorMessage ?? l10n.dashboardUnableToLoad),
                        textAlign: TextAlign.center,
                        style: typography.footnote.regular.copyWith(
                          color: colors.textSecondary,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (isNoCards) ...[
                        ShrinkableButton(
                          onTap: () {
                            AppFeedback.light();
                            unawaited(
                              context.router.replace(
                                DocumentIngestionRoute(),
                              ),
                            );
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              vertical: 13,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  colors.primary,
                                  colors.syllabotAccent,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(
                                AppRadius.card,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: colors.black.withAlpha(
                                    isDark ? 40 : 20,
                                  ),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.auto_awesome_rounded,
                                  color: colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Generate with AI',
                                  style: typography.subhead.bold.copyWith(
                                    color: colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      ShrinkableButton(
                        onTap: () {
                          AppFeedback.light();
                          context.router.pop();
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: colors.surfaceSecondary.withAlpha(
                              isDark ? 160 : 100,
                            ),
                            borderRadius: BorderRadius.circular(
                              AppRadius.card,
                            ),
                            border: Border.all(
                              color: colors.primary.withAlpha(
                                isDark ? 40 : 20,
                              ),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Return to Workspace',
                            style: typography.footnote.bold.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
