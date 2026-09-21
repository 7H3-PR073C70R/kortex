import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';

/// Modal bottom sheet container featuring an accessible drag handle and header.
class AppBottomSheet extends StatelessWidget {
  const AppBottomSheet({
    required this.child,
    super.key,
    this.title,
    this.subtitle,
    this.showDragHandle = true,
    this.showCloseButton = true,
    this.padding,
    this.semanticLabel,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final bool showDragHandle;
  final bool showCloseButton;
  final EdgeInsetsGeometry? padding;
  final String? semanticLabel;

  /// Convenience method to display an [AppBottomSheet].
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    String? title,
    String? subtitle,
    bool showDragHandle = true,
    bool showCloseButton = true,
    bool isScrollControlled = true,
    bool isDismissible = true,
    bool enableDrag = true,
    EdgeInsetsGeometry? padding,
    Color? backgroundColor,
    String? semanticLabel,
  }) {
    final colors = context.colors;

    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: backgroundColor ?? colors.surfacePrimary,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.dialog),
        ),
      ),
      builder: (context) => AppBottomSheet(
        title: title,
        subtitle: subtitle,
        showDragHandle: showDragHandle,
        showCloseButton: showCloseButton,
        padding: padding,
        semanticLabel: semanticLabel,
        child: child,
      ),
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
      label: semanticLabel ?? title ?? l10n.defaultBottomSheetTitle,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: MediaQuery.of(context).viewInsets,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showDragHandle) ...[
                    const SizedBox(height: 12),
                    Center(
                      child: Semantics(
                        button: true,
                        label: l10n.dismissSheet,
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            width: 48,
                            height: 24,
                            alignment: Alignment.center,
                            child: Container(
                              width: 36,
                              height: 4,
                              decoration: BoxDecoration(
                                color: colors.surfaceBorderHighlight,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.micro,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (title != null || showCloseButton) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (title != null)
                                  Text(
                                    title!,
                                    style: typography.title3.bold.copyWith(
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                if (subtitle != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitle!,
                                    style: typography.caption.regular.copyWith(
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (showCloseButton)
                            Semantics(
                              button: true,
                              label: l10n.closeSheet,
                              child: PlatformHoverBuilder(
                                builder: (context, isHovered, child) {
                                  return AnimatedScale(
                                    scale: isHovered ? 1.08 : 1.0,
                                    duration: AppMotion.snappy,
                                    curve: AppMotion.easeOutCubic,
                                    child: child,
                                  );
                                },
                                child: SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: IconButton(
                                    icon: Icon(
                                      Icons.close,
                                      color: colors.textMuted,
                                      size: 20,
                                    ),
                                    splashRadius: 20,
                                    tooltip: l10n.closeSheet,
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ExcludeSemantics(
                      child: Divider(
                        color: colors.surfaceBorder,
                        height: 1,
                        thickness: 1,
                      ),
                    ),
                  ],
                  Flexible(
                    child: Padding(
                      padding:
                          padding ??
                          const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                      child: child,
                    ),
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
