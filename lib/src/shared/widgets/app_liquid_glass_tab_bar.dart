import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// A reusable platform-adaptive segmented tab bar featuring Liquid Glass physics,
/// specular refraction, frosted glass backdrops, and optional icon labels.
class AppLiquidGlassTabBar extends StatelessWidget {
  const AppLiquidGlassTabBar({
    required this.tabs,
    required this.selectedIndex,
    required this.onTabSelected,
    this.icons,
    this.height = 46.0,
    this.padding = const EdgeInsets.all(4),
    this.isCompact = false,
    super.key,
  })  : assert(tabs.length >= 2, 'At least 2 tabs are required.'),
        assert(
          icons == null || icons.length == tabs.length,
          'icons list length must match tabs list length if provided.',
        );

  final List<String> tabs;
  final List<IconData?>? icons;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final double height;
  final EdgeInsetsGeometry padding;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    final fontSize = isCompact ? 11.5 : 12.5;

    return Padding(
      padding: padding,
      child: GlassSegmentedControl(
        segments: List.generate(
          tabs.length,
          (index) {
            final icon =
                icons != null && index < icons!.length ? icons![index] : null;
            return GlassSegment(
              label: tabs[index],
              icon: icon != null
                  ? Icon(
                      icon,
                      size: isCompact ? 14 : 16,
                    )
                  : null,
            );
          },
        ),
        selectedIndex: selectedIndex,
        onSegmentSelected: onTabSelected,
        height: height,
        useOwnLayer: true,
        indicatorColor: colors.primary,
        selectedTextStyle: typography.caption.bold.copyWith(
          color: colors.white,
          fontSize: fontSize,
        ),
        unselectedTextStyle: typography.caption.medium.copyWith(
          color: colors.textSecondary,
          fontSize: fontSize,
        ),
      ),
    );
  }
}
