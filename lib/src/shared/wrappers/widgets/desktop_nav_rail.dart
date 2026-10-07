import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/gen/assets.gen.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';
import 'package:kortex/src/shared/wrappers/widgets/main_nav_item.dart';
import 'package:kortex/src/shared/wrappers/widgets/nav_tab_handler.dart';

/// Desktop Left Navigation Rail (>= 1024dp)
class DesktopNavRail extends StatelessWidget {
  const DesktopNavRail({
    required this.tabsRouter,
    required this.width,
    super.key,
    this.onTabSelected,
  });

  final TabsRouter tabsRouter;
  final double width;
  final VoidCallback? onTabSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    return Semantics(
      container: true,
      label: l10n.navBarSemanticsLabel,
      child: Container(
        width: width,
        height: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        decoration: BoxDecoration(
          color: isDark
              ? colors.surfacePrimary.withAlpha(200)
              : colors.surfacePrimary.withAlpha(235),
        ),
        child: SafeArea(
          right: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. App Header Branding
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    AppAssets.svgs.kortexLogo.svg(
                      width: 32,
                      height: 32,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.appName,
                          style: typography.headline.bold.copyWith(
                            color: colors.textPrimary,
                            letterSpacing: 2,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.engineSubtitle,
                          style: typography.caption.bold.copyWith(
                            color: colors.syllabotAccent,
                            fontSize: 9,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // 2. Navigation Items
              Expanded(
                child: ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: kNavItems5.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final item = kNavItems5[index];
                    final isSelected = tabsRouter.activeIndex == index;
                    final label = item.labelBuilder(l10n);

                    return DesktopNavRailItem(
                      icon: isSelected ? item.activeIcon : item.icon,
                      label: label,
                      isSelected: isSelected,
                      itemIndex: index,
                      totalItems: kNavItems5.length,
                      onTap: () {
                        handleTabTap(
                          context,
                          tabsRouter,
                          index,
                          label,
                        );
                        onTabSelected?.call();
                      },
                    );
                  },
                ),
              ),

              // 3. Desktop Footer Info
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: AppRadius.radiusPanel,
                  color: isDark
                      ? colors.surfaceSecondary.withAlpha(120)
                      : colors.surfaceSecondary.withAlpha(180),
                  border: Border.all(
                    color: colors.surfaceBorder,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.recallEasy,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.neuralEngineActive,
                        style: typography.caption.medium.copyWith(
                          color: colors.textSecondary,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DesktopNavRailItem extends StatelessWidget {
  const DesktopNavRailItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.itemIndex,
    required this.totalItems,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final int itemIndex;
  final int totalItems;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    return Semantics(
      button: true,
      selected: isSelected,
      label: l10n.navTabSemantics(label, itemIndex + 1, totalItems),
      child: PlatformHoverBuilder(
        builder: (context, isHovered, _) {
          return ShrinkableButton(
            onTap: onTap,
            shrinkScale: 0.98,
            child: AnimatedContainer(
              duration: AppMotion.snappy,
              curve: AppMotion.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: AppRadius.radiusCard,
                color: isSelected
                    ? colors.primary.withAlpha(isDark ? 45 : 25)
                    : (isHovered
                          ? colors.surfaceBorder.withAlpha(isDark ? 35 : 45)
                          : colors.transparent),
                border: Border.all(
                  color: isSelected
                      ? colors.primary.withAlpha(isDark ? 100 : 70)
                      : (isHovered ? colors.surfaceBorder : colors.transparent),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 22,
                    color: isSelected ? colors.primary : colors.textSecondary,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      label,
                      style: isSelected
                          ? typography.subhead.semiBold.copyWith(
                              color: colors.textPrimary,
                              fontSize: 14,
                            )
                          : typography.subhead.regular.copyWith(
                              color: colors.textSecondary,
                              fontSize: 14,
                            ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isSelected)
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.primary,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
