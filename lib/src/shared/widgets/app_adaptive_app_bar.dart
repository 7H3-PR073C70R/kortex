import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/shared/widgets/app_back_button.dart';
import 'package:kortex/src/shared/widgets/app_breadcrumbs.dart';

/// A platform-adaptive application bar that automatically suppresses back buttons
/// and swaps titles for interactive breadcrumbs when rendered on wide layouts (width >= 1024dp).
class AppAdaptiveAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AppAdaptiveAppBar({
    super.key,
    this.title,
    this.titleText,
    this.breadcrumbs,
    this.leading,
    this.actions,
    this.backgroundColor,
    this.elevation = 0,
    this.centerTitle,
    this.toolbarHeight = kToolbarHeight,
    this.bottom,
    this.forceShowBackButton = false,
  });

  /// Explicit custom title widget. Used when breadcrumbs are not applicable.
  final Widget? title;

  /// String title convenience.
  final String? titleText;

  /// Optional hierarchical breadcrumbs displayed on wide screens.
  final List<AppBreadcrumbItem>? breadcrumbs;

  /// Custom leading widget override. If null, automatically falls back to [AppBackButton].
  final Widget? leading;

  /// Actions on the trailing edge.
  final List<Widget>? actions;

  /// Background color. Defaults to transparent.
  final Color? backgroundColor;

  /// App bar elevation. Defaults to 0.
  final double elevation;

  /// Whether to center title on compact layouts. Defaults to true on compact, false on wide.
  final bool? centerTitle;

  /// Toolbar height.
  final double toolbarHeight;

  /// Optional bottom widget.
  final PreferredSizeWidget? bottom;

  /// Force display of the back button even on wide layouts.
  final bool forceShowBackButton;

  @override
  Size get preferredSize => Size.fromHeight(
        toolbarHeight + (bottom?.preferredSize.height ?? 0.0),
      );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= AppBackButton.desktopBreakpoint;

    final effectiveLeading = leading ??
        (isWide && !forceShowBackButton
            ? null
            : AppBackButton(forceShow: forceShowBackButton));

    Widget? effectiveTitle;
    if (isWide && breadcrumbs != null && breadcrumbs!.isNotEmpty) {
      effectiveTitle = AppBreadcrumbs(items: breadcrumbs!);
    } else if (title != null) {
      effectiveTitle = title;
    } else if (titleText != null) {
      effectiveTitle = Text(
        titleText!,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: typography.title3.bold.copyWith(
          color: colors.textPrimary,
          fontSize: isWide ? 18 : 16,
        ),
      );
    }

    return AppBar(
      backgroundColor: backgroundColor ?? colors.transparent,
      elevation: elevation,
      automaticallyImplyLeading: false,
      leading: effectiveLeading,
      leadingWidth: isWide && !forceShowBackButton ? 0 : null,
      title: effectiveTitle,
      centerTitle: centerTitle ?? (!isWide),
      actions: actions,
      bottom: bottom,
    );
  }
}
