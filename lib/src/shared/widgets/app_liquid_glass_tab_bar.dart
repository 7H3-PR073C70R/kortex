import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

/// A reusable platform-adaptive segmented tab bar with authentic iOS/macOS
/// Liquid Glass effects and fluid horizontal drag-to-select physics.
///
/// On iOS and macOS:
/// - Renders a [LiquidGlass] shader container with refractive glass borders,
///   depth lighting, and frosted backdrop blur.
/// - Supports smooth horizontal drag gestures to smoothly glide the liquid
///   selection capsule across tabs with tactile haptics and elastic snap.
///
/// On Android and other platforms:
/// - Renders a clean Material 3 tonal container with drag & tap interaction.
class AppLiquidGlassTabBar extends StatefulWidget {
  const AppLiquidGlassTabBar({
    required this.tabs,
    required this.selectedIndex,
    required this.onTabSelected,
    this.height = 44.0,
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

  @override
  State<AppLiquidGlassTabBar> createState() => _AppLiquidGlassTabBarState();
}

class _AppLiquidGlassTabBarState extends State<AppLiquidGlassTabBar> {
  double? _dragAlignment;
  bool _isDragging = false;
  int? _highlightedIndex;

  bool get _isApplePlatform {
    if (kIsWeb) return false;
    return Platform.isIOS || Platform.isMacOS;
  }

  int get _lastIndex => widget.tabs.length - 1;

  double _getAlignment(int index) {
    if (_lastIndex == 0) return 0;
    return -1.0 + (index * 2 / _lastIndex);
  }

  void _updateHighlightedIndex() {
    if (!_isDragging || _dragAlignment == null) {
      _highlightedIndex = null;
      return;
    }

    final normalized = ((_dragAlignment! + 1) / 2).clamp(0.0, 1.0);
    final index = (normalized * _lastIndex).round().clamp(0, _lastIndex);
    if (_highlightedIndex != index) {
      _highlightedIndex = index;
      unawaited(HapticFeedback.selectionClick());
    }
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

  /// iOS & macOS Liquid Glass Segmented Control with Drag Interaction
  Widget _buildLiquidGlassBar(
    BuildContext context,
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
    bool isDark,
  ) {
    final effectiveHeight = widget.height;
    final currentActiveIndex = _isDragging
        ? (_highlightedIndex ?? widget.selectedIndex)
        : widget.selectedIndex;

    return Container(
      padding: widget.padding,
      child: Stack(
        children: [
          // Ambient depth shadow
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(effectiveHeight / 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(isDark ? 50 : 12),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
            ),
          ),

          // Liquid Glass Shader Layer
          LiquidGlass.withOwnLayer(
            shape: LiquidRoundedRectangle(
              borderRadius: effectiveHeight / 2,
            ),
            settings: LiquidGlassSettings(
              thickness: 18,
              blur: 20,
              glassColor: isDark
                  ? colors.surfaceSecondary.withAlpha(160)
                  : colors.surfacePrimary.withAlpha(210),
              lightIntensity: isDark ? 0.45 : 0.65,
              refractiveIndex: 1.45,
            ),
            child: Container(
              height: effectiveHeight,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(effectiveHeight / 2),
                border: Border.all(
                  color: isDark
                      ? colors.surfaceBorderHighlight.withAlpha(70)
                      : colors.surfaceBorder.withAlpha(140),
                  width: 1.1,
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final tabWidth = constraints.maxWidth / widget.tabs.length;
                  final totalDragWidth = constraints.maxWidth - tabWidth;

                  return GestureDetector(
                    onHorizontalDragStart: (details) {
                      setState(() {
                        _isDragging = true;
                        _dragAlignment = _getAlignment(widget.selectedIndex);
                        _updateHighlightedIndex();
                      });
                    },
                    onHorizontalDragUpdate: (details) {
                      if (!_isDragging || totalDragWidth <= 0) return;
                      setState(() {
                        final deltaAlignment =
                            (details.primaryDelta! / totalDragWidth) * 2.0;
                        _dragAlignment =
                            (_dragAlignment! + deltaAlignment).clamp(-1.0, 1.0);
                        _updateHighlightedIndex();
                      });
                    },
                    onHorizontalDragEnd: (details) {
                      setState(() {
                        _isDragging = false;
                        final currentA = _dragAlignment ??
                            _getAlignment(widget.selectedIndex);
                        final normalized =
                            ((currentA + 1) / 2).clamp(0.0, 1.0);
                        final targetIndex = (normalized * _lastIndex)
                            .round()
                            .clamp(0, _lastIndex);
                        _highlightedIndex = null;
                        _dragAlignment = null;

                        if (targetIndex != widget.selectedIndex) {
                          unawaited(HapticFeedback.selectionClick());
                          widget.onTabSelected(targetIndex);
                        }
                      });
                    },
                    onHorizontalDragCancel: () {
                      setState(() {
                        _isDragging = false;
                        _highlightedIndex = null;
                        _dragAlignment = null;
                      });
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Draggable & Animating Liquid Selection Capsule
                        AnimatedAlign(
                          duration: _isDragging
                              ? Duration.zero
                              : const Duration(milliseconds: 260),
                          curve: Curves.easeOutCubic,
                          alignment: Alignment(
                            _isDragging
                                ? (_dragAlignment ??
                                    _getAlignment(widget.selectedIndex))
                                : _getAlignment(widget.selectedIndex),
                            0,
                          ),
                          child: Container(
                            width: tabWidth,
                            height: effectiveHeight - 6,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  colors.primary,
                                  colors.primary.withAlpha(220),
                                  colors.primary.withAlpha(190),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(
                                (effectiveHeight - 6) / 2,
                              ),
                              border: Border.all(
                                color: Colors.white
                                    .withAlpha(isDark ? 65 : 100),
                                width: 0.9,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: colors.primary
                                      .withAlpha(isDark ? 95 : 65),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Tab Titles
                        Row(
                          children: List.generate(widget.tabs.length, (index) {
                            final isSelected = currentActiveIndex == index;
                            return Expanded(
                              child: Semantics(
                                button: true,
                                selected: isSelected,
                                label: widget.tabs[index],
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    if (widget.selectedIndex != index) {
                                      unawaited(
                                        HapticFeedback.selectionClick(),
                                      );
                                      widget.onTabSelected(index);
                                    }
                                  },
                                  child: Center(
                                    child: AnimatedDefaultTextStyle(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      style: isSelected
                                          ? typography.caption.bold.copyWith(
                                              color: Colors.white,
                                              fontSize: widget.isCompact
                                                  ? 11.5
                                                  : 12.5,
                                            )
                                          : typography.caption.medium.copyWith(
                                              color: colors.textSecondary,
                                              fontSize: widget.isCompact
                                                  ? 11.5
                                                  : 12.5,
                                            ),
                                      child: Text(
                                        widget.tabs[index],
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
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Android & Cross-Platform Material 3 Segmented Control
  /// with Drag Interaction
  Widget _buildMaterialSegmentedBar(
    BuildContext context,
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
    bool isDark,
  ) {
    final effectiveHeight = widget.height;
    final currentActiveIndex = _isDragging
        ? (_highlightedIndex ?? widget.selectedIndex)
        : widget.selectedIndex;

    return Container(
      height: effectiveHeight,
      padding: widget.padding,
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
          final tabWidth = constraints.maxWidth / widget.tabs.length;
          final totalDragWidth = constraints.maxWidth - tabWidth;

          return GestureDetector(
            onHorizontalDragStart: (details) {
              setState(() {
                _isDragging = true;
                _dragAlignment = _getAlignment(widget.selectedIndex);
                _updateHighlightedIndex();
              });
            },
            onHorizontalDragUpdate: (details) {
              if (!_isDragging || totalDragWidth <= 0) return;
              setState(() {
                final deltaAlignment =
                    (details.primaryDelta! / totalDragWidth) * 2.0;
                _dragAlignment =
                    (_dragAlignment! + deltaAlignment).clamp(-1.0, 1.0);
                _updateHighlightedIndex();
              });
            },
            onHorizontalDragEnd: (details) {
              setState(() {
                _isDragging = false;
                final currentA =
                    _dragAlignment ?? _getAlignment(widget.selectedIndex);
                final normalized = ((currentA + 1) / 2).clamp(0.0, 1.0);
                final targetIndex =
                    (normalized * _lastIndex).round().clamp(0, _lastIndex);
                _highlightedIndex = null;
                _dragAlignment = null;

                if (targetIndex != widget.selectedIndex) {
                  unawaited(HapticFeedback.selectionClick());
                  widget.onTabSelected(targetIndex);
                }
              });
            },
            onHorizontalDragCancel: () {
              setState(() {
                _isDragging = false;
                _highlightedIndex = null;
                _dragAlignment = null;
              });
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Sliding indicator
                AnimatedAlign(
                  duration: _isDragging
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment(
                    _isDragging
                        ? (_dragAlignment ??
                            _getAlignment(widget.selectedIndex))
                        : _getAlignment(widget.selectedIndex),
                    0,
                  ),
                  child: Container(
                    width: tabWidth,
                    height: effectiveHeight - 8,
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
                  children: List.generate(widget.tabs.length, (index) {
                    final isSelected = currentActiveIndex == index;
                    return Expanded(
                      child: Semantics(
                        button: true,
                        selected: isSelected,
                        label: widget.tabs[index],
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (widget.selectedIndex != index) {
                              unawaited(HapticFeedback.selectionClick());
                              widget.onTabSelected(index);
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
                                      fontSize:
                                          widget.isCompact ? 11.5 : 12.5,
                                    )
                                  : typography.caption.medium.copyWith(
                                      color: colors.textSecondary,
                                      fontSize:
                                          widget.isCompact ? 11.5 : 12.5,
                                    ),
                              child: Text(
                                widget.tabs[index],
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
            ),
          );
        },
      ),
    );
  }
}
