import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// A reusable platform-adaptive segmented tab bar.
///
/// On iOS and macOS:
/// - Uses [GlassSegmentedControl] from `liquid_glass_widgets` with authentic
///   iOS liquid glass physics, drag gesture support, and specular refraction.
///
/// On Android and other platforms:
/// - Renders a clean Material 3 tonal container with drag & tap interaction.
class AppLiquidGlassTabBar extends StatelessWidget {
  const AppLiquidGlassTabBar({
    required this.tabs,
    required this.selectedIndex,
    required this.onTabSelected,
    this.height = 42.0,
    this.padding = const EdgeInsets.all(4),
    this.isCompact = false,
    super.key,
  }) : assert(tabs.length >= 2, 'At least 2 tabs are required.');

  final List<String> tabs;
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

    if (_isApplePlatform) {
      return _buildLiquidGlassBar(context, colors, typography, isDark);
    } else {
      return _buildMaterialSegmentedBar(context, colors, typography, isDark);
    }
  }

  /// iOS & macOS Liquid Glass Segmented Control
  Widget _buildLiquidGlassBar(
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
          color: Colors.white,
          fontSize: fontSize,
        ),
        unselectedTextStyle: typography.caption.medium.copyWith(
          color: colors.textSecondary,
          fontSize: fontSize,
        ),
      ),
    );
  }

  /// Android & Cross-Platform Material 3 Segmented Control
  Widget _buildMaterialSegmentedBar(
    BuildContext context,
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
    bool isDark,
  ) {
    return Container(
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: isDark
            ? colors.surfaceSecondary.withAlpha(180)
            : colors.surfaceSecondary.withAlpha(160),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? colors.surfaceBorderHighlight.withAlpha(60)
              : colors.surfaceBorder.withAlpha(120),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = constraints.maxWidth / tabs.length;

          return Stack(
            alignment: Alignment.center,
            children: [
              // Sliding active pill
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                left: selectedIndex * tabWidth,
                top: 0,
                bottom: 0,
                width: tabWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? colors.primary : colors.surfacePrimary,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(isDark ? 45 : 18),
                        blurRadius: 5,
                        offset: const Offset(0, 1.5),
                      ),
                    ],
                  ),
                ),
              ),

              // Tab items
              Row(
                children: List.generate(tabs.length, (index) {
                  final isSelected = selectedIndex == index;
                  return Expanded(
                    child: Semantics(
                      button: true,
                      selected: isSelected,
                      label: tabs[index],
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (selectedIndex != index) {
                            unawaited(HapticFeedback.selectionClick());
                            onTabSelected(index);
                          }
                        },
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 180),
                            style: isSelected
                                ? typography.caption.bold.copyWith(
                                    color: isDark
                                        ? Colors.white
                                        : colors.primary,
                                    fontSize: isCompact ? 11.5 : 12.5,
                                  )
                                : typography.caption.medium.copyWith(
                                    color: colors.textSecondary,
                                    fontSize: isCompact ? 11.5 : 12.5,
                                  ),
                            child: Text(
                              tabs[index],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}
