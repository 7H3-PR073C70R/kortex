import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';
import 'package:kortex/src/shared/wrappers/widgets/desktop_nav_rail.dart';

/// 3D Flip Perspective Window Overlay Drawer for narrow Web and Desktop viewports (< 720px).
/// Main content tilts back in 3D perspective while retaining visibility in the background,
/// revealing the left navigation rail overlay drawer without glow effects.
class WebDesktop3dFlipDrawer extends StatelessWidget {
  const WebDesktop3dFlipDrawer({
    required this.tabsRouter,
    required this.drawerAnimController,
    required this.isDrawerOpen,
    required this.animation,
    required this.child,
    super.key,
  });

  final TabsRouter tabsRouter;
  final AnimationController drawerAnimController;
  final ValueNotifier<bool> isDrawerOpen;
  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;

    return AnimatedBuilder(
      animation: drawerAnimController,
      builder: (context, _) {
        final progress = CurvedAnimation(
          parent: drawerAnimController,
          curve: AppMotion.easeOutCubic,
        ).value;

        return Stack(
          fit: StackFit.expand,
          children: [
            // 1. Semi-transparent backdrop barrier when drawer open
            if (progress > 0)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => isDrawerOpen.value = false,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    color: Colors.black.withAlpha(
                      (90 * progress).toInt(),
                    ),
                  ),
                ),
              ),

            // 2. Main Page Content with 3D Flip Window Perspective Shift
            Positioned.fill(
              child: Transform(
                alignment: Alignment.centerLeft,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(0.12 * progress)
                  // ignore: deprecated_member_use, Matrix4 3D perspective scale transform
                  ..scale(
                    1 - (0.12 * progress),
                    1 - (0.12 * progress),
                    1,
                  )
                  // ignore: deprecated_member_use, Matrix4 3D perspective translation transform
                  ..translate(180.0 * progress),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    20 * progress,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        20 * progress,
                      ),
                      boxShadow: progress > 0
                          ? [
                              BoxShadow(
                                color: Colors.black.withAlpha(
                                  isDark ? 120 : 40,
                                ),
                                blurRadius: 24,
                                spreadRadius: 2,
                                offset: const Offset(-8, 8),
                              ),
                            ]
                          : null,
                    ),
                    child: IgnorePointer(
                      ignoring: progress > 0.3,
                      child: SafeArea(
                        top: false,
                        bottom: false,
                        child: FadeTransition(
                          opacity: animation,
                          child: child,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 3. Slide-in Navigation Drawer Overlay
            if (progress > 0)
              Positioned(
                left: -260.0 * (1 - progress),
                top: 0,
                bottom: 0,
                width: 250,
                child: SafeArea(
                  child: Material(
                    elevation: 16,
                    shadowColor: Colors.black.withAlpha(
                      isDark ? 160 : 60,
                    ),
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(24),
                    ),
                    clipBehavior: Clip.antiAlias,
                    color: colors.surfacePrimary,
                    child: DesktopNavRail(
                      tabsRouter: tabsRouter,
                      width: 250,
                      onTabSelected: () => isDrawerOpen.value = false,
                    ),
                  ),
                ),
              ),

            // 4. Floating Hamburger Button (Top-Left)
            Positioned(
              left: 12 + (180.0 * progress),
              top: 12,
              child: SafeArea(
                child: Material(
                  color: Colors.transparent,
                  child: ShrinkableButton(
                    onTap: () => isDrawerOpen.value = !isDrawerOpen.value,
                    child: PlatformHoverBuilder(
                      builder: (context, isHovered, _) {
                        return Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark
                                ? colors.surfaceSecondary.withAlpha(220)
                                : colors.surfacePrimary.withAlpha(240),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isHovered
                                  ? colors.primary.withAlpha(120)
                                  : colors.surfaceBorder,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(
                                  isDark ? 80 : 20,
                                ),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: AnimatedSwitcher(
                            duration: AppMotion.snappy,
                            child: Icon(
                              progress > 0.5
                                  ? Icons.close_rounded
                                  : Icons.menu_rounded,
                              key: ValueKey(
                                progress > 0.5,
                              ),
                              size: 22,
                              color: colors.textPrimary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
