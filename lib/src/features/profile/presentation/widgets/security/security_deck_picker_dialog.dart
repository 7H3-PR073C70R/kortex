import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_sheet.dart';

/// Modal sheet for picking a specific deck to export.
class SecurityDeckPickerDialog {
  static Future<void> show({
    required BuildContext context,
    required List<DeckEntity> decks,
    required void Function(DeckEntity deck) onSelectDeck,
  }) async {
    final colors = context.colors;
    final typography = context.typography;

    await AppAdaptiveSheet.showModal<void>(
      context: context,
      maxWidth: 600,
      builder: (sheetContext) {
        final isDesktop = AppAdaptiveSheet.isDesktopOrWeb(sheetContext);
        final isDark = sheetContext.isDarkMode;
        return Align(
          alignment: isDesktop ? Alignment.center : Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Container(
              decoration: BoxDecoration(
                color: sheetContext.colors.surfacePrimary,
                borderRadius: isDesktop
                    ? BorderRadius.circular(AppRadius.dialog)
                    : const BorderRadius.vertical(
                        top: Radius.circular(AppRadius.dialog),
                      ),
                boxShadow: isDesktop
                    ? [
                        BoxShadow(
                          color: colors.black.withAlpha(isDark ? 80 : 30),
                          blurRadius: 32,
                          offset: const Offset(0, 12),
                        ),
                      ]
                    : null,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select Deck to Export',
                        style: typography.title3.bold.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      if (isDesktop)
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          color: colors.textMuted,
                          tooltip: 'Close',
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: decks.length,
                      separatorBuilder: (_, index) => const Divider(height: 1),
                      itemBuilder: (_, index) {
                        final d = decks[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.style_rounded,
                            color: colors.primary,
                          ),
                          title: Text(
                            d.title,
                            style: typography.body.bold.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            '${d.totalCards} cards • ${d.subject}',
                            style: typography.footnote.regular.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                          trailing: Icon(
                            Icons.chevron_right_rounded,
                            color: colors.textSecondary,
                          ),
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                            onSelectDeck(d);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
