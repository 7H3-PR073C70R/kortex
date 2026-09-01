import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// A reusable platform-adaptive segmented tab bar.
///
/// On iOS and macOS, it renders a high-fidelity Liquid Glass morphism
/// container with frosted backdrop blur, specular refraction highlights,
/// and smooth sliding capsule animations.
///
/// On Android and other platforms, it renders a clean Material 3 tonal
/// segmented container with platform-native transitions.
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: isDark
                ? colors.surfaceSecondary.withAlpha(140)
                : colors.surfacePrimary.withAlpha(180),
            borderRadius: BorderRadius.circular(height / 2),
            border: Border.all(
              color: isDark
                  ? colors.surfaceBorderHighlight.withAlpha(60)
                  : colors.surfaceBorder.withAlpha(120),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(isDark ? 35 : 10),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final tabWidth =
                  (constraints.maxWidth - (padding.horizontal)) / tabs.length;

              return Stack(
                children: [
                  // Smooth animated sliding liquid capsule
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    left: selectedIndex * tabWidth,
                    top: 0,
                    bottom: 0,
                    width: tabWidth,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            colors.primary,
                            colors.primary.withAlpha(210),
                          ],
                        ),
                        borderRadius: BorderRadius.circular((height - 8) / 2),
                        border: Border.all(
                          color: Colors.white.withAlpha(isDark ? 50 : 80),
                          width: 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colors.primary.withAlpha(isDark ? 90 : 60),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Tab Labels Row
                  Row(
                    children: List.generate(tabs.length, (index) {
                      final isSelected = selectedIndex == index;
                      return Expanded(
                        child: ShrinkableButton(
                          onTap: () {
                            if (!isSelected) {
                              unawaited(HapticFeedback.selectionClick());
                              onTabSelected(index);
                            }
                          },
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: isSelected
                                  ? typography.caption.bold.copyWith(
                                      color: Colors.white,
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
                      );
                    }),
                  ),
                ],
              );
            },
          ),
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? colors.surfaceBorderHighlight.withAlpha(60)
              : colors.surfaceBorder.withAlpha(120),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth =
              (constraints.maxWidth - (padding.horizontal)) / tabs.length;

          return Stack(
            children: [
              // Material 3 animated selection indicator
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                left: selectedIndex * tabWidth,
                top: 0,
                bottom: 0,
                width: tabWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: colors.primary.withAlpha(50),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),

              // Tab text buttons
              Row(
                children: List.generate(tabs.length, (index) {
                  final isSelected = selectedIndex == index;
                  return Expanded(
                    child: InkWell(
                      onTap: () {
                        if (!isSelected) {
                          unawaited(HapticFeedback.selectionClick());
                          onTabSelected(index);
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 150),
                          style: isSelected
                              ? typography.caption.bold.copyWith(
                                  color: Colors.white,
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
