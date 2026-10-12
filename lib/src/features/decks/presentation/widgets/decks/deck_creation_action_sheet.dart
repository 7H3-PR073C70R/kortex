import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_sheet.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Modal bottom sheet or desktop dialog presenting deck creation choices.
class DeckCreationActionSheet extends StatelessWidget {
  const DeckCreationActionSheet({super.key});

  static Future<void> show(BuildContext context) {
    return AppAdaptiveSheet.showActionMenu<void>(
      context: context,
      builder: (bottomSheetContext) => const DeckCreationActionSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;
    final isDesktop = AppAdaptiveSheet.isDesktopOrWeb(context);

    return SafeArea(
      top: false,
      child: Align(
        alignment: isDesktop ? Alignment.center : Alignment.bottomCenter,
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
              borderRadius: isDesktop
                  ? BorderRadius.circular(AppRadius.dialog)
                  : const BorderRadius.vertical(
                      top: Radius.circular(AppRadius.dialog),
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
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isDesktop) ...[
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.surfaceBorder,
                        borderRadius: BorderRadius.circular(AppRadius.micro),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.l10n.decksCreateSheetTitle,
                      style: typography.title3.bold.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    if (isDesktop)
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        tooltip: 'Close',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        color: colors.textSecondary,
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  context.l10n.decksCreateSheetSubtitle,
                  style: typography.footnote.regular.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),

                // Option 1: Dedicated Study Deck Creation Page
                DeckActionOptionTile(
                  icon: Icons.layers_rounded,
                  iconColor: colors.primary,
                  title: 'Create Study Deck',
                  subtitle:
                      'Upload past questions or create flashcards manually',
                  onTap: () {
                    Navigator.pop(context);
                    unawaited(
                      context.router.push(
                        CreateDeckRoute(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),

                // Option 2: Upload Documents
                DeckActionOptionTile(
                  icon: Icons.document_scanner_rounded,
                  iconColor: colors.primary,
                  title: context.l10n.decksUploadDocTitle,
                  subtitle: context.l10n.decksUploadDocSubtitle,
                  onTap: () {
                    Navigator.pop(context);
                    unawaited(
                      context.router.push(
                        DocumentIngestionRoute(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Reusable option tile with icon, title, subtitle, and chevron.
class DeckActionOptionTile extends StatelessWidget {
  const DeckActionOptionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return ShrinkableButton(
      onTap: () {
        unawaited(HapticFeedback.lightImpact());
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.panel),
          color: isDark
              ? colors.surfaceSecondary.withAlpha(150)
              : colors.surfacePrimary.withAlpha(200),
          border: Border.all(
            color: isDark
                ? colors.surfaceBorderHighlight.withAlpha(50)
                : colors.surfaceBorder.withAlpha(100),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.card),
                color: iconColor.withAlpha(isDark ? 40 : 25),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: typography.body.bold.copyWith(
                      color: colors.textPrimary,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: typography.footnote.regular.copyWith(
                      color: colors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: colors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
