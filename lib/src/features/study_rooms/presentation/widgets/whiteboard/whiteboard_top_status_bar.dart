import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/whiteboard/whiteboard_tool_types.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Top bar overlay displaying live stroke counter, grid toggles, and tools expand button.
class WhiteboardTopStatusBar extends StatelessWidget {
  const WhiteboardTopStatusBar({
    required this.strokesCount,
    required this.showGrid,
    required this.gridStyle,
    required this.showToolsExpanded,
    required this.isDark,
    required this.onToggleGrid,
    required this.onToggleTools,
    super.key,
  });

  final int strokesCount;
  final bool showGrid;
  final WhiteboardGridStyle gridStyle;
  final bool showToolsExpanded;
  final bool isDark;
  final VoidCallback onToggleGrid;
  final VoidCallback onToggleTools;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;

    return Row(
      children: [
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: (isDark ? colors.black : colors.white).withAlpha(180),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colors.primary.withAlpha(isDark ? 40 : 20),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.success,
                  ),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    l10n.whiteboardLiveStatus(strokesCount),
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.caption.bold.copyWith(
                      fontSize: 11,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        // Toggle Grid Button
        Tooltip(
          message: l10n.whiteboardToggleGrid,
          child: ShrinkableButton(
            onTap: () {
              unawaited(HapticFeedback.selectionClick());
              onToggleGrid();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: (isDark ? colors.black : colors.white).withAlpha(180),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colors.primary.withAlpha(isDark ? 40 : 20),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    showGrid
                        ? (gridStyle == WhiteboardGridStyle.dots
                            ? Icons.grain_rounded
                            : Icons.grid_on_rounded)
                        : Icons.grid_off_rounded,
                    size: 14,
                    color: showGrid ? colors.primary : colors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    showGrid
                        ? (gridStyle == WhiteboardGridStyle.dots
                            ? l10n.whiteboardGridDots
                            : l10n.whiteboardGridLines)
                        : l10n.whiteboardGridBlank,
                    style: context.typography.caption.regular.copyWith(
                      fontSize: 11,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        // Collapse / Expand Tools Button
        Tooltip(
          message: l10n.whiteboardToggleTools,
          child: ShrinkableButton(
            onTap: () {
              unawaited(HapticFeedback.selectionClick());
              onToggleTools();
            },
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (isDark ? colors.black : colors.white).withAlpha(180),
                border: Border.all(
                  color: colors.primary.withAlpha(isDark ? 40 : 20),
                ),
              ),
              child: Icon(
                showToolsExpanded
                    ? Icons.keyboard_arrow_down_rounded
                    : Icons.tune_rounded,
                size: 16,
                color: colors.textPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
