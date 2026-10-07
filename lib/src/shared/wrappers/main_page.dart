import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/features/ingestion/presentation/widgets/background_ingestion_indicator.dart';
import 'package:kortex/src/shared/widgets/app_sync_beacon.dart';
import 'package:kortex/src/shared/widgets/floating_syllabot_overlay.dart';
import 'package:kortex/src/shared/wrappers/widgets/adaptive_bottom_nav_dock.dart';
import 'package:kortex/src/shared/wrappers/widgets/desktop_nav_rail.dart';
import 'package:kortex/src/shared/wrappers/widgets/main_nav_item.dart';
import 'package:kortex/src/shared/wrappers/widgets/tablet_nav_rail.dart';
import 'package:kortex/src/shared/wrappers/widgets/web_3d_flip_drawer.dart';

/// Main application shell wrapper using [AutoTabsScaffold], responsive
/// desktop navigation rail, 3D perspective web drawer, and native platform adaptive bottom dock.
@RoutePage()
class MainPage extends HookWidget {
  const MainPage({super.key});

  static const String routeName = '/main';
  static const double desktopBreakpoint = 1024;
  static const double tabletBreakpoint = 720;
  static const double tabletShortestSideBreakpoint = 600;
  static const double railWidth = 240;
  static const double tabletRailWidth = 72;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;
    final isDrawerOpen = useState(false);
    final drawerAnimController = useAnimationController(
      duration: AppMotion.expressive,
    );

    useEffect(() {
      if (isDrawerOpen.value) {
        unawaited(drawerAnimController.forward());
      } else {
        unawaited(drawerAnimController.reverse());
      }
      return null;
    }, [isDrawerOpen.value]);

    return FloatingSyllabotOverlay(
      child: Stack(
        fit: StackFit.expand,
        children: [
          AutoTabsScaffold(
            routes: kNavItems5.map((item) => item.route).toList(),
            homeIndex: 0,
            animationDuration: AppMotion.standard,
            animationCurve: AppMotion.easeOutCubic,
            extendBody: true,
            backgroundColor: colors.backgroundPrimary,
            resizeToAvoidBottomInset: false,
            transitionBuilder: (context, child, animation) {
              final tabsRouter = AutoTabsRouter.of(context);

              return ColoredBox(
                color: colors.backgroundPrimary,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final mediaQuery = MediaQuery.of(context);
                    final isDesktop = constraints.maxWidth >= desktopBreakpoint;
                    final isLandscape =
                        mediaQuery.orientation == Orientation.landscape;
                    final isTablet =
                        mediaQuery.size.shortestSide >= tabletShortestSideBreakpoint;
                    final isTabletLandscape = !isDesktop &&
                        isTablet &&
                        constraints.maxWidth >= tabletBreakpoint &&
                        isLandscape;
                    final webOrDesktop = isWebOrDesktop;

                    // 1. Web & Desktop Narrow Viewport (< 720px): 3D Flip Perspective Drawer
                    if (webOrDesktop && constraints.maxWidth < tabletBreakpoint) {
                      return WebDesktop3dFlipDrawer(
                        tabsRouter: tabsRouter,
                        drawerAnimController: drawerAnimController,
                        isDrawerOpen: isDrawerOpen,
                        animation: animation,
                        child: child,
                      );
                    }

                    // 2. Wide & Medium Rail Layouts (Desktop >= 1024 / Tablet 720-1023)
                    if (isDesktop ||
                        isTabletLandscape ||
                        (webOrDesktop && constraints.maxWidth >= tabletBreakpoint)) {
                      return Row(
                        children: [
                          if (isDesktop || constraints.maxWidth >= desktopBreakpoint)
                            DesktopNavRail(
                              tabsRouter: tabsRouter,
                              width: railWidth,
                            )
                          else
                            TabletNavRail(
                              tabsRouter: tabsRouter,
                              width: tabletRailWidth,
                            ),
                          VerticalDivider(
                            width: 1,
                            thickness: 1,
                            color: isDark
                                ? colors.surfaceBorderHighlight.withAlpha(60)
                                : colors.surfaceBorder,
                          ),
                          Expanded(
                            child: SafeArea(
                              top: false,
                              bottom: false,
                              left: false,
                              child: FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    return SafeArea(
                      top: false,
                      bottom: false,
                      child: FadeTransition(
                        opacity: animation,
                        child: child,
                      ),
                    );
                  },
                ),
              );
            },
            bottomNavigationBuilder: (context, tabsRouter) {
              final mediaQuery = MediaQuery.of(context);
              final width = mediaQuery.size.width;
              final isLandscape =
                  mediaQuery.orientation == Orientation.landscape;
              final isTablet =
                  mediaQuery.size.shortestSide >= tabletShortestSideBreakpoint;
              final isTabletLandscape =
                  isTablet && width >= tabletBreakpoint && isLandscape;

              if (isWebOrDesktop || width >= desktopBreakpoint || isTabletLandscape) {
                return const SizedBox.shrink();
              }
              return Align(
                alignment: Alignment.bottomCenter,
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 540),
                  child: AdaptiveBottomNavDock(
                    tabsRouter: tabsRouter,
                  ),
                ),
              );
            },
          ),
          const BackgroundIngestionIndicator(),
          const AppSyncBeacon(),
        ],
      ),
    );
  }
}
