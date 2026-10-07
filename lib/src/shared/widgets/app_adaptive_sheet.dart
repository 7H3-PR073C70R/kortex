import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';

/// Presentation mode for adaptive sheets on desktop and web viewports.
enum AdaptiveSheetMode {
  /// Centered modal dialog with full corner radius and max-width clamp.
  /// Replaces Short Bottom Sheets on Desktop/Web.
  modal,

  /// Slide-in drawer anchored to the right side of the workstation.
  /// Replaces Tall/Expandable Sheets on Desktop/Web.
  sideDrawer,

  /// Compact popover dialog with focused actions.
  /// Replaces Action Sheets / Context Menus on Desktop/Web.
  actionMenu,
}

/// Unified platform-adaptive presentation engine that ensures:
/// - Mobile: Native fluid bottom sheets with drag handles and bottom pinning.
/// - Desktop & Web: Native dialogs, side drawers, and popovers without bottom sheets.
class AppAdaptiveSheet {
  AppAdaptiveSheet._();

  /// Determines whether the current device is a desktop platform or web viewport.
  static bool isDesktopOrWeb(BuildContext context) {
    if (kIsWeb) return true;
    switch (defaultTargetPlatform) {
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return true;
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
        return MediaQuery.sizeOf(context).width >= 768;
    }
  }

  /// Presents a modal that adaptively renders as a Centered Dialog on Desktop/Web
  /// and as a Bottom Sheet on Mobile.
  static Future<T?> showModal<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    double maxWidth = 580,
    double? maxHeight,
    bool isDismissible = true,
    bool isScrollControlled = true,
    bool enableDrag = true,
    bool useRootNavigator = false,
    bool useSafeArea = true,
    Color? backgroundColor,
    Color? barrierColor,
    String? semanticLabel,
    RouteSettings? routeSettings,
  }) {
    if (isDesktopOrWeb(context)) {
      final colors = context.colors;
      final isDark = context.isDarkMode;
      final l10n = context.l10n;

      return showGeneralDialog<T>(
        context: context,
        useRootNavigator: useRootNavigator,
        barrierDismissible: isDismissible,
        barrierLabel: semanticLabel ?? l10n.dismissDialog,
        barrierColor: barrierColor ?? colors.black.withAlpha(isDark ? 160 : 120),
        routeSettings: routeSettings,
        pageBuilder: (dialogContext, animation, secondaryAnimation) {
          final size = MediaQuery.sizeOf(dialogContext);
          final effectiveMaxHeight = maxHeight ?? (size.height * 0.88);

          final dialogBody = Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxWidth,
                maxHeight: effectiveMaxHeight,
              ),
              child: Material(
                type: MaterialType.transparency,
                child: builder(dialogContext),
              ),
            ),
          );

          return useSafeArea ? SafeArea(child: dialogBody) : dialogBody;
        },
        transitionDuration: AppMotion.snappy,
        transitionBuilder: (context, anim1, anim2, child) {
          final curved = AppMotion.easeOutCubic.transform(anim1.value);
          return Transform.scale(
            scale: 0.95 + (0.05 * curved),
            child: Opacity(
              opacity: anim1.value,
              child: child,
            ),
          );
        },
      );
    }

    return showModalBottomSheet<T>(
      context: context,
      useRootNavigator: useRootNavigator,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      useSafeArea: useSafeArea,
      backgroundColor: backgroundColor ?? Colors.transparent,
      barrierColor: barrierColor,
      routeSettings: routeSettings,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.dialog),
        ),
      ),
      builder: (sheetCtx) => Align(
        alignment: Alignment.bottomCenter,
        child: builder(sheetCtx),
      ),
    );
  }

  /// Presents a side drawer that slides from the right on Desktop/Web
  /// and presents as a bottom sheet on Mobile.
  /// (Pattern: Tall / Expandable Sheet -> Side Drawer).
  static Future<T?> showSideDrawer<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    double? width,
    double drawerWidth = 480,
    bool isDismissible = true,
    bool isScrollControlled = true,
    bool useRootNavigator = false,
    Color? backgroundColor,
    Color? barrierColor,
    String? semanticLabel,
    RouteSettings? routeSettings,
  }) {
    final effectiveWidth = width ?? drawerWidth;
    if (isDesktopOrWeb(context)) {
      final colors = context.colors;
      final isDark = context.isDarkMode;
      final l10n = context.l10n;

      return showGeneralDialog<T>(
        context: context,
        useRootNavigator: useRootNavigator,
        barrierDismissible: isDismissible,
        barrierLabel: semanticLabel ?? l10n.dismissDialog,
        barrierColor: barrierColor ?? colors.black.withAlpha(isDark ? 160 : 120),
        routeSettings: routeSettings,
        pageBuilder: (dialogContext, animation, secondaryAnimation) {
          return Align(
            alignment: Alignment.centerRight,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: effectiveWidth,
                minHeight: double.infinity,
              ),
              child: Material(
                type: MaterialType.transparency,
                child: builder(dialogContext),
              ),
            ),
          );
        },
        transitionDuration: AppMotion.snappy,
        transitionBuilder: (context, anim1, anim2, child) {
          final curved = AppMotion.easeOutCubic.transform(anim1.value);
          final offsetAnimation = Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).transform(curved);

          return SlideTransition(
            position: AlwaysStoppedAnimation(offsetAnimation),
            child: Opacity(
              opacity: anim1.value.clamp(0.0, 1.0),
              child: child,
            ),
          );
        },
      );
    }

    return showModalBottomSheet<T>(
      context: context,
      useRootNavigator: useRootNavigator,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      backgroundColor: backgroundColor ?? Colors.transparent,
      barrierColor: barrierColor,
      routeSettings: routeSettings,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.dialog),
        ),
      ),
      builder: (sheetCtx) => Align(
        alignment: Alignment.bottomCenter,
        child: builder(sheetCtx),
      ),
    );
  }

  /// Presents a compact action menu (popover/dialog) on Desktop/Web
  /// and an action sheet on Mobile.
  /// (Pattern: Action Sheet / Context Menu -> Dropdown Menu / Popover).
  static Future<T?> showActionMenu<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    double maxWidth = 400,
    bool isDismissible = true,
    bool useRootNavigator = false,
    Color? backgroundColor,
    Color? barrierColor,
    String? semanticLabel,
    RouteSettings? routeSettings,
  }) {
    return showModal<T>(
      context: context,
      builder: builder,
      maxWidth: maxWidth,
      isDismissible: isDismissible,
      useRootNavigator: useRootNavigator,
      backgroundColor: backgroundColor,
      barrierColor: barrierColor,
      semanticLabel: semanticLabel,
      routeSettings: routeSettings,
    );
  }
}

/// A container that wraps modal or sheet content with responsive styling:
/// - Desktop/Web modal: centered card with full rounded corners, subtle border and shadow.
/// - Desktop/Web side drawer: full-height pane with left border.
/// - Mobile: bottom-pinned sheet with drag handle.
class AppAdaptiveContainer extends StatelessWidget {
  const AppAdaptiveContainer({
    required this.child,
    super.key,
    this.title,
    this.subtitle,
    this.showCloseButton = true,
    this.showDragHandle = true,
    this.padding,
    this.backgroundColor,
    this.borderColor,
    this.maxWidth = 600,
    this.mode = AdaptiveSheetMode.modal,
    this.headerTrailing,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final bool showCloseButton;
  final bool showDragHandle;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final Color? borderColor;
  final double maxWidth;
  final AdaptiveSheetMode mode;
  final Widget? headerTrailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;
    final l10n = context.l10n;
    final isDesktop = AppAdaptiveSheet.isDesktopOrWeb(context);

    final effectiveBgColor = backgroundColor ??
        (isDark ? colors.surfaceSecondary : colors.surfacePrimary);
    final effectiveBorderColor = borderColor ??
        (isDark ? colors.surfaceBorder.withAlpha(90) : colors.surfaceBorder);

    if (isDesktop && mode == AdaptiveSheetMode.sideDrawer) {
      return Container(
        decoration: BoxDecoration(
          color: effectiveBgColor,
          border: Border(
            left: BorderSide(color: effectiveBorderColor, width: 1.2),
          ),
          boxShadow: [
            BoxShadow(
              color: colors.black.withAlpha(isDark ? 90 : 35),
              blurRadius: 28,
              offset: const Offset(-8, 0),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context, isDesktop: true),
              Expanded(
                child: Padding(
                  padding: padding ?? const EdgeInsets.all(20),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (isDesktop) {
      return Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Container(
            decoration: BoxDecoration(
              color: effectiveBgColor,
              borderRadius: BorderRadius.circular(AppRadius.dialog),
              border: Border.all(color: effectiveBorderColor, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: colors.black.withAlpha(isDark ? 100 : 40),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context, isDesktop: true),
                Flexible(
                  child: Padding(
                    padding: padding ?? const EdgeInsets.all(20),
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Mobile Bottom Sheet Presentation
    return SafeArea(
      top: false,
      child: Padding(
        padding: MediaQuery.of(context).viewInsets,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Container(
              decoration: BoxDecoration(
                color: effectiveBgColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.dialog),
                ),
                border: Border(
                  top: BorderSide(color: effectiveBorderColor, width: 1.2),
                ),
              ),
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
                    const SizedBox(height: 8),
                  ],
                  _buildHeader(context, isDesktop: false),
                  Flexible(
                    child: Padding(
                      padding: padding ?? const EdgeInsets.all(20),
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

  Widget _buildHeader(
    BuildContext context, {
    required bool isDesktop,
  }) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;

    if (title == null && subtitle == null && !showCloseButton && headerTrailing == null) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
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
              ?headerTrailing,
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
                      width: 36,
                      height: 36,
                      child: IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: colors.textMuted,
                          size: 18,
                        ),
                        splashRadius: 18,
                        padding: EdgeInsets.zero,
                        tooltip: l10n.closeSheet,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        ExcludeSemantics(
          child: Divider(
            color: colors.surfaceBorder.withAlpha(70),
            height: 1,
            thickness: 1,
          ),
        ),
      ],
    );
  }
}
