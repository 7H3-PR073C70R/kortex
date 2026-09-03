import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';

/// Modal dialog component trapping screen-reader focus within its route.
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    this.title,
    this.description,
    this.content,
    this.icon,
    this.iconBackgroundColor,
    this.primaryActionText,
    this.onPrimaryAction,
    this.secondaryActionText,
    this.onSecondaryAction,
    this.isDestructive = false,
    this.isPrimaryLoading = false,
    this.semanticLabel,
  });

  final String? title;
  final String? description;
  final Widget? content;
  final Widget? icon;
  final Color? iconBackgroundColor;
  final String? primaryActionText;
  final VoidCallback? onPrimaryAction;
  final String? secondaryActionText;
  final VoidCallback? onSecondaryAction;
  final bool isDestructive;
  final bool isPrimaryLoading;
  final String? semanticLabel;

  /// Helper to display the dialog with smooth transition and route trapping.
  static Future<T?> show<T>({
    required BuildContext context,
    String? title,
    String? description,
    Widget? content,
    Widget? icon,
    Color? iconBackgroundColor,
    String? primaryActionText,
    VoidCallback? onPrimaryAction,
    String? secondaryActionText,
    VoidCallback? onSecondaryAction,
    bool isDestructive = false,
    bool barrierDismissible = true,
  }) {
    final l10n = context.l10n;

    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: l10n.dismissDialog,
      barrierColor: Colors.black.withAlpha(160),
      pageBuilder: (context, anim1, anim2) {
        return AppDialog(
          title: title,
          description: description,
          content: content,
          icon: icon,
          iconBackgroundColor: iconBackgroundColor,
          primaryActionText: primaryActionText,
          onPrimaryAction: onPrimaryAction,
          secondaryActionText: secondaryActionText,
          onSecondaryAction: onSecondaryAction,
          isDestructive: isDestructive,
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        final curvedValue = Curves.easeOutCubic.transform(anim1.value);
        return Transform.scale(
          scale: 0.95 + (0.05 * curvedValue),
          child: Opacity(
            opacity: anim1.value,
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;

    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      label: semanticLabel ?? title ?? l10n.defaultDialogTitle,
      child: Dialog(
        backgroundColor: colors.surfacePrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 24,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colors.surfaceBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (icon != null) ...[
                Center(
                  child: ExcludeSemantics(
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color:
                            iconBackgroundColor ??
                            (isDestructive
                                ? colors.error.withAlpha(30)
                                : colors.primary.withAlpha(30)),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: IconTheme(
                        data: IconThemeData(
                          color: isDestructive ? colors.error : colors.primary,
                          size: 26,
                        ),
                        child: icon!,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (title != null) ...[
                Text(
                  title!,
                  style: typography.title3.bold.copyWith(
                    color: colors.textPrimary,
                  ),
                  textAlign: icon != null ? TextAlign.center : TextAlign.start,
                ),
                const SizedBox(height: 8),
              ],
              if (description != null) ...[
                Text(
                  description!,
                  style: typography.callout.regular.copyWith(
                    color: colors.textSecondary,
                  ),
                  textAlign: icon != null ? TextAlign.center : TextAlign.start,
                ),
              ],
              if (content != null) ...[
                if (title != null || description != null)
                  const SizedBox(height: 16),
                content!,
              ],
              if (primaryActionText != null || secondaryActionText != null) ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    if (secondaryActionText != null) ...[
                      Expanded(
                        child: AppButton.secondary(
                          text: secondaryActionText!,
                          onPressed:
                              onSecondaryAction ??
                              () => Navigator.of(context).pop(false),
                        ),
                      ),
                      if (primaryActionText != null) const SizedBox(width: 12),
                    ],
                    if (primaryActionText != null) ...[
                      Expanded(
                        child: AppButton(
                          text: primaryActionText!,
                          variant: isDestructive
                              ? AppButtonVariant.destructive
                              : AppButtonVariant.primary,
                          isLoading: isPrimaryLoading,
                          onPressed:
                              onPrimaryAction ??
                              () => Navigator.of(context).pop(true),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
