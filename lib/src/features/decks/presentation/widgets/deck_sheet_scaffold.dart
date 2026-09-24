import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/l10n/l10n.dart';

/// Shared bottom-sheet skeleton for the decks flow.
///
/// Owns everything a sheet needs to feel like the rest of the app: grab
/// handle, titled header with optional leading and subtitle, close action,
/// surface decoration, safe-area handling and (optionally) a scroll wrapper.
/// Callers only supply the body [children].
class DeckSheetScaffold extends StatelessWidget {
  const DeckSheetScaffold({
    required this.title,
    required this.children,
    this.subtitle,
    this.leading,
    this.maxWidth = 600,
    this.maxHeightFactor = 0.88,
    this.scrollable = true,
    this.dismissOnClose = true,
    super.key,
  });

  final String title;
  final String? subtitle;

  /// Optional widget rendered before the title (icon chip, badge, ...).
  final Widget? leading;

  final double maxWidth;
  final double maxHeightFactor;

  /// When false the body must size itself inside the max-height constraint
  /// (e.g. sheets containing an expanding list).
  final bool scrollable;

  final bool dismissOnClose;

  /// The sheet body, laid out in a start-aligned column under the header.
  final List<Widget> children;

  void _onClose(BuildContext context) {
    if (dismissOnClose) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Grab handle
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
        const SizedBox(height: 14),

        // Header
        Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: typography.title3.bold.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: typography.footnote.regular.copyWith(
                        color: colors.textSecondary,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Semantics(
              button: true,
              label: l10n.closeSheet,
              child: IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  color: colors.textSecondary,
                  size: 20,
                ),
                onPressed: () => _onClose(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: MediaQuery.sizeOf(context).height * maxHeightFactor,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.dialog),
              ),
              border: Border.all(
                color: isDark
                    ? colors.surfaceBorderHighlight.withAlpha(70)
                    : colors.surfaceBorder,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.black.withAlpha(isDark ? 70 : 30),
                  blurRadius: 28,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: scrollable
                    ? SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [body],
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [body],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
