import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/whiteboard/whiteboard_tool_types.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Floating toolbar at the bottom of the whiteboard for selecting tools, width, colors, and actions.
class WhiteboardFloatingToolbar extends StatelessWidget {
  const WhiteboardFloatingToolbar({
    required this.activeTool,
    required this.selectedColorHex,
    required this.strokeWidth,
    required this.isDark,
    required this.canUndo,
    required this.canRedo,
    required this.onToolChanged,
    required this.onColorChanged,
    required this.onStrokeWidthChanged,
    required this.onUndo,
    required this.onRedo,
    required this.onClear,
    super.key,
  });

  final WhiteboardTool activeTool;
  final int? selectedColorHex;
  final double strokeWidth;
  final bool isDark;
  final bool canUndo;
  final bool canRedo;
  final ValueChanged<WhiteboardTool> onToolChanged;
  final ValueChanged<int> onColorChanged;
  final ValueChanged<double> onStrokeWidthChanged;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final VoidCallback? onClear;

  static const List<double> _strokeWidthPresets = [2.0, 4.0, 8.0];

  List<int> _buildColorPalette(AppThemeColorsExtension colors) => [
        colors.white.toARGB32(),
        colors.primary.toARGB32(),
        colors.alpineMoss.toARGB32(),
        colors.warmOchre.toARGB32(),
        colors.deepBronze.toARGB32(),
        colors.quartzCyan.toARGB32(),
        colors.slateTerracotta.toARGB32(),
        colors.error.toARGB32(),
      ];

  void _showClearConfirmDialog(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;

    unawaited(
      showDialog<void>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          backgroundColor:
              isDark ? colors.surfaceSecondary : colors.surfacePrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.delete_sweep_rounded, color: colors.error, size: 24),
              const SizedBox(width: 8),
              Text(
                l10n.whiteboardClearTitle,
                style: typography.subhead.bold.copyWith(
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
          content: Text(
            l10n.whiteboardClearConfirmMessage,
            style: typography.caption.regular.copyWith(
              color: colors.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text(
                l10n.whiteboardClearCancel,
                style: context.typography.body.regular
                    .copyWith(color: colors.textSecondary),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                onClear?.call();
              },
              child: Text(l10n.whiteboardClearAll),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolIcon(
    BuildContext context, {
    required IconData icon,
    required WhiteboardTool tool,
    required String tooltip,
  }) {
    final colors = context.colors;
    final isSelected = activeTool == tool;

    return Padding(
      padding: const EdgeInsets.only(right: 3),
      child: Tooltip(
        message: tooltip,
        child: GestureDetector(
          onTap: () {
            unawaited(HapticFeedback.selectionClick());
            onToolChanged(tool);
          },
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: isSelected
                  ? colors.primary.withAlpha(isDark ? 60 : 35)
                  : colors.transparent,
              border: isSelected
                  ? Border.all(color: colors.primary.withAlpha(120))
                  : null,
            ),
            child: Icon(
              icon,
              size: 16,
              color: isSelected ? colors.primary : colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: colors.surfacePrimary.withAlpha(isDark ? 235 : 250),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colors.primary.withAlpha(isDark ? 60 : 35),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.black.withAlpha(isDark ? 100 : 35),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top Row: Tool selector & Stroke Widths
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildToolIcon(
                  context,
                  icon: Icons.edit_rounded,
                  tool: WhiteboardTool.pen,
                  tooltip: l10n.whiteboardToolPen,
                ),
                _buildToolIcon(
                  context,
                  icon: Icons.brush_rounded,
                  tool: WhiteboardTool.highlighter,
                  tooltip: l10n.whiteboardToolHighlighter,
                ),
                _buildToolIcon(
                  context,
                  icon: Icons.cleaning_services_rounded,
                  tool: WhiteboardTool.eraser,
                  tooltip: l10n.whiteboardToolEraser,
                ),
                const SizedBox(width: 4),
                Container(
                  height: 18,
                  width: 1,
                  color: colors.textMuted.withAlpha(60),
                ),
                const SizedBox(width: 4),
                _buildToolIcon(
                  context,
                  icon: Icons.horizontal_rule_rounded,
                  tool: WhiteboardTool.line,
                  tooltip: l10n.whiteboardToolLine,
                ),
                _buildToolIcon(
                  context,
                  icon: Icons.arrow_forward_rounded,
                  tool: WhiteboardTool.arrow,
                  tooltip: l10n.whiteboardToolArrow,
                ),
                _buildToolIcon(
                  context,
                  icon: Icons.crop_square_rounded,
                  tool: WhiteboardTool.rectangle,
                  tooltip: l10n.whiteboardToolRectangle,
                ),
                _buildToolIcon(
                  context,
                  icon: Icons.circle_outlined,
                  tool: WhiteboardTool.circle,
                  tooltip: l10n.whiteboardToolCircle,
                ),
                const SizedBox(width: 8),
                // Stroke width presets
                ..._strokeWidthPresets.map((w) {
                  final isSel = strokeWidth == w;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: GestureDetector(
                      onTap: () {
                        unawaited(HapticFeedback.selectionClick());
                        onStrokeWidthChanged(w);
                      },
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSel
                              ? colors.primary.withAlpha(40)
                              : colors.transparent,
                          border: isSel
                              ? Border.all(
                                  color: colors.primary,
                                  width: 1.5,
                                )
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Container(
                          width: w + 2,
                          height: w + 2,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSel
                                ? colors.primary
                                : colors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Bottom Row: Color Swatches + Undo / Redo / Clear
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ..._buildColorPalette(colors).map((colorHex) {
                  final isSelected = activeTool != WhiteboardTool.eraser &&
                      (selectedColorHex ?? colors.primary.toARGB32()) ==
                          colorHex;
                  return Padding(
                    padding: const EdgeInsets.only(right: 5),
                    child: GestureDetector(
                      onTap: () {
                        unawaited(HapticFeedback.selectionClick());
                        onColorChanged(colorHex);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: isSelected ? 22 : 16,
                        height: isSelected ? 22 : 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(colorHex),
                          border: Border.all(
                            color: isSelected
                                ? colors.primary
                                : colors.gray.withAlpha(80),
                            width: isSelected ? 2.2 : 1.0,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(width: 8),
                // Undo
                Tooltip(
                  message: l10n.whiteboardUndo,
                  child: ShrinkableButton(
                    onTap: canUndo
                        ? () {
                            unawaited(HapticFeedback.lightImpact());
                            onUndo?.call();
                          }
                        : null,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: canUndo
                            ? colors.surfaceTertiary
                            : colors.surfaceTertiary.withAlpha(60),
                      ),
                      child: Icon(
                        Icons.undo_rounded,
                        size: 14,
                        color: canUndo
                            ? colors.textPrimary
                            : colors.textMuted.withAlpha(100),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                // Redo
                Tooltip(
                  message: l10n.whiteboardRedo,
                  child: ShrinkableButton(
                    onTap: canRedo
                        ? () {
                            unawaited(HapticFeedback.lightImpact());
                            onRedo?.call();
                          }
                        : null,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: canRedo
                            ? colors.surfaceTertiary
                            : colors.surfaceTertiary.withAlpha(60),
                      ),
                      child: Icon(
                        Icons.redo_rounded,
                        size: 14,
                        color: canRedo
                            ? colors.textPrimary
                            : colors.textMuted.withAlpha(100),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                // Clear
                Tooltip(
                  message: l10n.whiteboardClear,
                  child: ShrinkableButton(
                    onTap: () {
                      unawaited(HapticFeedback.mediumImpact());
                      _showClearConfirmDialog(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.error.withAlpha(
                          isDark ? 40 : 25,
                        ),
                      ),
                      child: Icon(
                        Icons.delete_sweep_rounded,
                        size: 14,
                        color: colors.error,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
