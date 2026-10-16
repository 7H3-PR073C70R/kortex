import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/shared/widgets/app_logo_loader.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Loading indicator state for the deck detail view.
class DeckDetailLoadingState extends StatelessWidget {
  const DeckDetailLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: AppLogoLoader(size: 56),
    );
  }
}

/// Error message state with retry button when flashcards fail to load.
class DeckDetailErrorState extends StatelessWidget {
  const DeckDetailErrorState({
    required this.errorMessage,
    required this.onRetry,
    super.key,
  });

  final String errorMessage;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 56,
            color: colors.textMuted.withAlpha(140),
          ),
          const SizedBox(height: 16),
          Text(
            'Unable to Load Cards',
            style: typography.callout.bold.copyWith(
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            errorMessage,
            textAlign: TextAlign.center,
            style: typography.footnote.regular.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          ShrinkableButton(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(AppRadius.badge),
              ),
              child: Text(
                'Retry',
                style: typography.caption.bold.copyWith(
                  color: colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty state when a deck contains zero cards.
class DeckDetailEmptyState extends StatelessWidget {
  const DeckDetailEmptyState({
    required this.onRefresh,
    super.key,
  });

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.style_outlined,
            size: 56,
            color: colors.textMuted.withAlpha(120),
          ),
          const SizedBox(height: 16),
          Text(
            'No Flashcards Found',
            style: typography.callout.bold.copyWith(
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This deck does not have any active cards yet.',
            textAlign: TextAlign.center,
            style: typography.footnote.regular.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          ShrinkableButton(
            onTap: onRefresh,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: colors.surfaceSecondary,
                borderRadius: BorderRadius.circular(AppRadius.badge),
                border: Border.all(
                  color: colors.surfaceBorder,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.refresh_rounded,
                    size: 14,
                    color: colors.textPrimary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Refresh Cards',
                    style: typography.caption.bold.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
