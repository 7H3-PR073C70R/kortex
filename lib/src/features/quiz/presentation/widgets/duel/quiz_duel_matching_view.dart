import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_duel_entity.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';

/// Dedicated matchmaking radar view shown while searching for a live challenger.
class QuizDuelMatchingView extends StatelessWidget {
  const QuizDuelMatchingView({
    required this.onPlayWithAi,
    required this.onCancelSearch,
    super.key,
    this.match,
  });

  final QuizDuelMatch? match;
  final VoidCallback onPlayWithAi;
  final VoidCallback onCancelSearch;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
      appBar: AppBar(
        backgroundColor: colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: onCancelSearch,
        ),
        title: Text(
          match?.subject ?? 'Finding Duel',
          style: typography.body.bold,
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.9, end: 1.15),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeInOut,
                    builder: (context, scale, child) {
                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 104,
                          height: 104,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.primary.withAlpha(25),
                            border: Border.all(
                              color: colors.primary.withAlpha(80),
                              width: 2.2,
                            ),
                          ),
                          child: Center(
                            child: Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: colors.primary,
                                boxShadow: [
                                  BoxShadow(
                                    color: colors.primary.withAlpha(90),
                                    blurRadius: 18,
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.radar_rounded,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Searching for Challenger...',
                    style: typography.title2.bold.copyWith(
                      color: colors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${match?.subject ?? "Academic"} • ${match?.examBoard ?? "WAEC"}\nLooking for active scholars nearby...',
                    style: typography.body.regular.copyWith(
                      color: colors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 36),
                  AppButton(
                    text: 'Play with AI Bot Now ⚡',
                    onPressed: onPlayWithAi,
                  ),
                  const SizedBox(height: 12),
                  AppButton(
                    text: 'Cancel Search',
                    variant: AppButtonVariant.secondary,
                    onPressed: onCancelSearch,
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
