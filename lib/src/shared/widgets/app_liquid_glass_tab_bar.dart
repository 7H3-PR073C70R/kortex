import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
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

  bool get _isApplePlatform {
    if (kIsWeb) return false;
    return Platform.isIOS || Platform.isMacOS;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    if (_isApplePlatform && icons == null) {
      return _buildNativeLiquidGlassBar(context, colors, typography, isDark);
    } else {
      return _buildLiquidGlassSegmentedBar(context, colors, typography, isDark);
    }
  }

  /// Apple Native Liquid Glass Segmented Control
  Widget _buildNativeLiquidGlassBar(
    BuildContext context,
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
    bool isDark,
  ) {
    final fontSize = isCompact ? 11.5 : 12.5;

    return Padding(
      padding: padding,
      child: GlassSegmentedControl(
        segments: tabs.map((tab) => GlassSegment(label: tab)).toList(),
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

  /// Cross-Platform Liquid Glass Segmented Control with Specular Sheen & Backdrop Blur
  Widget _buildLiquidGlassSegmentedBar(
    BuildContext context,
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
    bool isDark,
  ) {
    final fontSize = isCompact ? 11.5 : 12.5;

    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.panel),
        boxShadow: [
          BoxShadow(
            color: colors.black.withAlpha(isDark ? 80 : 15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.panel),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: isDark
                  ? colors.surfaceSecondary.withAlpha(140)
                  : colors.surfaceSecondary.withAlpha(200),
              borderRadius: BorderRadius.circular(AppRadius.panel),
              border: Border.all(
                color: isDark
                    ? colors.white.withAlpha(35)
                    : colors.white.withAlpha(180),
                width: 1.2,
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final tabWidth = constraints.maxWidth / tabs.length;

                return Stack(
                  children: [
                    // Sliding Liquid Glass Active Capsule
                    AnimatedPositioned(
                      duration: AppMotion.snappy,
                      curve: Curves.easeOutCubic,
                      left: selectedIndex * tabWidth,
                      top: 0,
                      bottom: 0,
                      width: tabWidth,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: isDark
                                ? [
                                    colors.primary.withAlpha(90),
                                    colors.primary.withAlpha(60),
                                  ]
                                : [
                                    colors.primary,
                                    colors.primary.withAlpha(230),
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(AppRadius.card),
                          border: Border.all(
                            color: colors.primary.withAlpha(isDark ? 140 : 100),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colors.primary.withAlpha(isDark ? 80 : 40),
                              blurRadius: 12,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            // Specular top highlight sheen line
                            Positioned(
                              top: 1,
                              left: 8,
                              right: 8,
                              height: 1,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      colors.transparent,
                                      colors.white.withAlpha(isDark ? 50 : 130),
                                      colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Tab Item Row
                    Row(
                      children: List.generate(tabs.length, (index) {
                        final isSelected = selectedIndex == index;
                        final icon = icons != null && index < icons!.length
                            ? icons![index]
                            : null;

                        return Expanded(
                          child: Semantics(
                            button: true,
                            selected: isSelected,
                            label: tabs[index],
                            child: PlatformHoverBuilder(
                              builder: (context, isHovered, child) {
                                return GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    if (selectedIndex != index) {
                                      unawaited(HapticFeedback.selectionClick());
                                      onTabSelected(index);
                                    }
                                  },
                                  child: Center(
                                    child: AnimatedSwitcher(
                                      duration: AppMotion.snappy,
                                      child: Row(
                                        key: ValueKey('${index}_$isSelected'),
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          if (icon != null) ...[
                                            Icon(
                                              icon,
                                              size: isCompact ? 14 : 16,
                                              color: isSelected
                                                  ? colors.white
                                                  : (isHovered
                                                        ? colors.textPrimary
                                                        : colors.textSecondary),
                                            ),
                                            const SizedBox(width: 6),
                                          ],
                                          Flexible(
                                            child: Text(
                                              tabs[index],
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: isSelected
                                                  ? typography.caption.bold
                                                        .copyWith(
                                                          color: colors.white,
                                                          fontSize: fontSize,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        )
                                                  : typography.caption.medium
                                                        .copyWith(
                                                          color: isHovered
                                                              ? colors.textPrimary
                                                              : colors
                                                                    .textSecondary,
                                                          fontSize: fontSize,
                                                        ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
