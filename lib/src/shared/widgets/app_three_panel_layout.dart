import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';

/// Responsive 3-Panel Desktop Layout component adhering to Senior UI/UX & PM Specs.
///
/// Pane Ratios & Responsiveness:
/// - Panel 1 (Navigation Panel): Fixed sidebar/rail (e.g. 240px desktop, 72px tablet rail).
/// - Panel 2 (Main List View): Dynamically resizes from full-flex (100% available space)
///   down to fixed width [mainPanelWidth] (e.g. 380px) when Panel 3 is active.
/// - Panel 3 (Detail View): Expands smoothly with [AppMotion.expressive] curve when selected.
///
/// Features:
/// - Smooth animated resizing and transitions between 2-panel and 3-panel states.
/// - Keyboard shortcuts (`Esc` key dismisses Panel 3 on desktop).
/// - Clean high-contrast pane dividers and glassmorphism styling.
/// - Graceful fallback to single-pane navigation on mobile screens.
class AppThreePanelLayout extends StatelessWidget {
  const AppThreePanelLayout({
    required this.navPanel,
    required this.mainPanel,
    required this.detailPanel,
    this.showDetailPanel = false,
    this.onCloseDetail,
    this.navPanelWidth = 240,
    this.mainPanelWidth = 520,
    this.desktopBreakpoint = 1024,
    this.detailTitle,
    this.detailActions,
    super.key,
  });

  /// Panel 1: Primary Navigation Sidebar / Rail
  final Widget navPanel;

  /// Panel 2: Main List / Feed View (e.g. Forum Posts list)
  final Widget mainPanel;

  /// Panel 3: Detail / Inspector View (e.g. Forum Thread detail)
  final Widget? detailPanel;

  /// Whether Panel 3 (Detail Pane) is currently open
  final bool showDetailPanel;

  /// Callback when user closes Panel 3 via header close button or `Esc` key
  final VoidCallback? onCloseDetail;

  /// Width of Panel 1 on Desktop
  final double navPanelWidth;

  /// Width of Panel 2 when Panel 3 is expanded
  final double mainPanelWidth;

  /// Minimum screen width breakpoint for Desktop 3-Panel mode
  final double desktopBreakpoint;

  /// Optional header title for Panel 3
  final String? detailTitle;

  /// Optional action buttons for Panel 3 header
  final List<Widget>? detailActions;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;

    return Focus(
      autofocus: showDetailPanel,
      onKeyEvent: (node, event) {
        if (showDetailPanel &&
            event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          onCloseDetail?.call();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= desktopBreakpoint;

          if (!isDesktop) {
            // Mobile / Tablet fallback: Show standard main view or detail push stack
            return mainPanel;
          }

          final isDetailActive = showDetailPanel && detailPanel != null;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // PANEL 1: Navigation Sidebar / Rail
              SizedBox(
                width: navPanelWidth,
                child: navPanel,
              ),

              // Pane Divider 1
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: isDark
                    ? colors.surfaceBorderHighlight.withAlpha(50)
                    : colors.surfaceBorder,
              ),

              // PANEL 2: Main View (Dynamic width: Flex 1 when detail hidden, fixed width when detail shown)
              AnimatedContainer(
                duration: AppMotion.expressive,
                curve: AppMotion.easeOutCubic,
                width: isDetailActive
                    ? mainPanelWidth
                    : (constraints.maxWidth - navPanelWidth - 1),
                child: ClipRect(
                  child: mainPanel,
                ),
              ),

              // Pane Divider 2 (visible only when Panel 3 is active)
              if (isDetailActive)
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: isDark
                      ? colors.surfaceBorderHighlight.withAlpha(50)
                      : colors.surfaceBorder,
                ),

              // PANEL 3: Detail View (Fills remaining space with spring entry animation)
              if (isDetailActive)
                Expanded(
                  child: AnimatedSwitcher(
                    duration: AppMotion.standard,
                    switchInCurve: AppMotion.easeOutCubic,
                    switchOutCurve: AppMotion.easeOutCubic,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.04, 0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: ColoredBox(
                      key: ValueKey(detailPanel.hashCode),
                      color: isDark
                          ? colors.backgroundPrimary
                          : colors.surfacePrimary,
                      child: Column(
                        children: [
                          // Detail Header Bar
                          _PanelHeaderBar(
                            title: detailTitle ?? 'Details',
                            onClose: onCloseDetail,
                            actions: detailActions,
                          ),
                          Divider(
                            height: 1,
                            thickness: 1,
                            color: isDark
                                ? colors.surfaceBorderHighlight.withAlpha(40)
                                : colors.surfaceBorder.withAlpha(80),
                          ),
                          // Detail Content Body
                          Expanded(
                            child: detailPanel!,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PanelHeaderBar extends StatelessWidget {
  const _PanelHeaderBar({
    required this.title,
    this.onClose,
    this.actions,
  });

  final String title;
  final VoidCallback? onClose;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(
            title,
            style: typography.title3.bold.copyWith(
              color: colors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          if (actions != null) ...actions!,
          if (onClose != null) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20),
              tooltip: 'Close Panel (Esc)',
              onPressed: onClose,
              splashRadius: 20,
            ),
          ],
        ],
      ),
    );
  }
}
