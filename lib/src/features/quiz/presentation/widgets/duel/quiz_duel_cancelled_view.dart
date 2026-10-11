import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';

/// Screen displayed when matchmaking is cancelled or match ends unexpectedly.
class QuizDuelCancelledView extends StatelessWidget {
  const QuizDuelCancelledView({
    required this.onFindAnother,
    required this.onReturnToDashboard,
    super.key,
    this.errorMessage,
  });

  final String? errorMessage;
  final VoidCallback onFindAnother;
  final VoidCallback onReturnToDashboard;

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
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.warning.withAlpha(30),
                    ),
                    child: const Icon(
                      Icons.exit_to_app_rounded,
                      size: 48,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Duel Ended',
                    style: typography.title2.bold.copyWith(
                      color: colors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    errorMessage ??
                        'The duel match was cancelled or completed.',
                    style: typography.body.regular.copyWith(
                      color: colors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  AppButton(
                    text: 'Find Another Duel ⚔️',
                    onPressed: onFindAnother,
                  ),
                  const SizedBox(height: 12),
                  AppButton(
                    text: 'Return to Dashboard',
                    variant: AppButtonVariant.ghost,
                    onPressed: onReturnToDashboard,
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
