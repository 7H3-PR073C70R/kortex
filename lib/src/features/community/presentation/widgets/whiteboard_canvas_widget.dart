import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/community/data/client/ephemeral_presence_client.dart';
import 'package:kortex/src/features/community/domain/services/whiteboard_compression.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

enum WhiteboardTool {
  pen,
  highlighter,
  eraser,
  line,
  arrow,
  rectangle,
  circle,
}

enum WhiteboardGridStyle {
  dots,
  lines,
  blank,
}

/// A collaborative, high-performance whiteboard canvas widget for Live Study Rooms.
/// Supports freehand drawing, highlighter, shapes (rectangle, circle, line, arrow),
/// eraser, color palette, stroke width adjustments, undo/redo, and Douglas-Peucker simplification.
class WhiteboardCanvasWidget extends StatefulWidget {
  const WhiteboardCanvasWidget({
    required this.strokes,
    this.onStrokeDrawn,
    this.onUndo,
    this.onRedo,
    this.onClear,
    this.canUndo = false,
    this.canRedo = false,
    this.isDark = true,
    this.currentUserId = 'user_local',
    this.currentUserName = 'Scholar',
    this.readOnly = false,
    super.key,
  });

  final List<WhiteboardStroke> strokes;
  final ValueChanged<WhiteboardStroke>? onStrokeDrawn;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final VoidCallback? onClear;
  final bool canUndo;
  final bool canRedo;
  final bool isDark;
  final String currentUserId;
  final String currentUserName;
  final bool readOnly;

  @override
  State<WhiteboardCanvasWidget> createState() => _WhiteboardCanvasWidgetState();
}

class _WhiteboardCanvasWidgetState extends State<WhiteboardCanvasWidget> {
  final List<WhiteboardPoint> _livePoints = [];
  WhiteboardTool _activeTool = WhiteboardTool.pen;
  int _selectedColorHex = 0xFF6366F1; // Default Indigo
  double _strokeWidth = 3.5;
  WhiteboardGridStyle _gridStyle = WhiteboardGridStyle.dots;
  bool _showGrid = true;
  bool _showToolsExpanded = true;

  static const List<int> _colorPalette = [
    0xFFFFFFFF, // White
    0xFF6366F1, // Indigo
    0xFF10B981, // Emerald
    0xFFF59E0B, // Amber
    0xFFEC4899, // Pink
    0xFF06B6D4, // Cyan
    0xFF8B5CF6, // Purple
    0xFFEF4444, // Red
  ];

  static const List<double> _strokeWidthPresets = [2.0, 4.0, 8.0];

  void _onPointerDown(PointerDownEvent event, BoxConstraints constraints) {
    if (widget.readOnly) return;
    final normalizedX = (event.localPosition.dx / constraints.maxWidth).clamp(
      0.0,
      1.0,
    );
    final normalizedY = (event.localPosition.dy / constraints.maxHeight).clamp(
      0.0,
      1.0,
    );

    setState(() {
      _livePoints
        ..clear()
        ..add(WhiteboardPoint(x: normalizedX, y: normalizedY));
    });
  }

  void _onPointerMove(PointerMoveEvent event, BoxConstraints constraints) {
    if (widget.readOnly || _livePoints.isEmpty) return;
    final normalizedX = (event.localPosition.dx / constraints.maxWidth).clamp(
      0.0,
      1.0,
    );
    final normalizedY = (event.localPosition.dy / constraints.maxHeight).clamp(
      0.0,
      1.0,
    );

    setState(() {
      if (_isShapeTool(_activeTool)) {
        // Shapes only need start point and current endpoint
        if (_livePoints.length > 1) {
          _livePoints[1] = WhiteboardPoint(x: normalizedX, y: normalizedY);
        } else {
          _livePoints.add(WhiteboardPoint(x: normalizedX, y: normalizedY));
        }
      } else {
        _livePoints.add(WhiteboardPoint(x: normalizedX, y: normalizedY));
      }
    });
  }

  void _onPointerUp(PointerUpEvent event, BoxConstraints constraints) {
    if (widget.readOnly || _livePoints.isEmpty) return;

    final normalizedX = (event.localPosition.dx / constraints.maxWidth).clamp(
      0.0,
      1.0,
    );
    final normalizedY = (event.localPosition.dy / constraints.maxHeight).clamp(
      0.0,
      1.0,
    );

    if (_isShapeTool(_activeTool)) {
      if (_livePoints.length > 1) {
        _livePoints[1] = WhiteboardPoint(x: normalizedX, y: normalizedY);
      } else {
        _livePoints.add(WhiteboardPoint(x: normalizedX, y: normalizedY));
      }
    } else {
      _livePoints.add(WhiteboardPoint(x: normalizedX, y: normalizedY));
    }

    _finalizeStroke();
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (_livePoints.isNotEmpty) {
      setState(_livePoints.clear);
    }
  }

  bool _isShapeTool(WhiteboardTool tool) {
    return tool == WhiteboardTool.line ||
        tool == WhiteboardTool.arrow ||
        tool == WhiteboardTool.rectangle ||
        tool == WhiteboardTool.circle;
  }

  String? _shapeTypeForTool(WhiteboardTool tool) {
    switch (tool) {
      case WhiteboardTool.line:
        return 'line';
      case WhiteboardTool.arrow:
        return 'arrow';
      case WhiteboardTool.rectangle:
        return 'rectangle';
      case WhiteboardTool.circle:
        return 'circle';
      case WhiteboardTool.pen:
      case WhiteboardTool.highlighter:
      case WhiteboardTool.eraser:
        return null;
    }
  }

  void _finalizeStroke() {
    if (_livePoints.isEmpty) return;

    final isEraser = _activeTool == WhiteboardTool.eraser;
    final isHighlighter = _activeTool == WhiteboardTool.highlighter;
    final isShape = _isShapeTool(_activeTool);

    // Simplify polyline points with Douglas-Peucker unless it is a 2-point shape
    final List<WhiteboardPoint> processedPoints;
    if (isShape || _livePoints.length <= 2) {
      processedPoints = List<WhiteboardPoint>.from(_livePoints);
    } else {
      // Epsilon 0.0015 corresponds to ~1.5 pixels on a 1000px canvas
      processedPoints = WhiteboardCompression.simplify(
        _livePoints,
        epsilon: 0.0015,
      );
    }

    var effectiveColor = _selectedColorHex;
    var effectiveWidth = _strokeWidth;

    if (isEraser) {
      effectiveColor = widget.isDark ? 0xFF12131A : 0xFFFFFFFF;
      effectiveWidth = 20.0;
    } else if (isHighlighter) {
      // Apply 40% alpha (0x66) for highlighter feel
      effectiveColor = (_selectedColorHex & 0x00FFFFFF) | 0x66000000;
      effectiveWidth = 14.0;
    }

    final stroke = WhiteboardStroke(
      id: 'wb_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(99999)}',
      userId: widget.currentUserId,
      userName: widget.currentUserName,
      colorHex: effectiveColor,
      strokeWidth: effectiveWidth,
      isEraser: isEraser,
      elementType: isShape ? 'shape' : 'stroke',
      shapeType: _shapeTypeForTool(_activeTool),
      points: processedPoints,
    );

    widget.onStrokeDrawn?.call(stroke);

    setState(_livePoints.clear);
  }

  void _showClearConfirmDialog() {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;

    unawaited(
      showDialog<void>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          backgroundColor: widget.isDark
              ? colors.surfaceSecondary
              : colors.surfacePrimary,
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
                style: TextStyle(color: colors.textSecondary),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                widget.onClear?.call();
              },
              child: Text(l10n.whiteboardClearAll),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final isDark = widget.isDark;

    return Semantics(
      label: l10n.whiteboardCanvasSemantics,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Stack(
          children: [
            // Whiteboard Surface
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF13141E) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: colors.primary.withAlpha(isDark ? 60 : 30),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.black.withAlpha(isDark ? 80 : 20),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Listener(
                      onPointerDown: (event) =>
                          _onPointerDown(event, constraints),
                      onPointerMove: (event) =>
                          _onPointerMove(event, constraints),
                      onPointerUp: (event) => _onPointerUp(event, constraints),
                      onPointerCancel: _onPointerCancel,
                      child: CustomPaint(
                        size: Size(constraints.maxWidth, constraints.maxHeight),
                        painter: _WhiteboardCanvasPainter(
                          strokes: widget.strokes,
                          livePoints: _livePoints,
                          liveColorHex: _selectedColorHex,
                          liveStrokeWidth:
                              _activeTool == WhiteboardTool.highlighter
                              ? 14.0
                              : (_activeTool == WhiteboardTool.eraser
                                    ? 20.0
                                    : _strokeWidth),
                          activeTool: _activeTool,
                          isDark: isDark,
                          showGrid: _showGrid,
                          gridStyle: _gridStyle,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Top Status & Grid Controls Overlay
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: Row(
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.black : Colors.white).withAlpha(
                          180,
                        ),
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
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              l10n.whiteboardLiveStatus(widget.strokes.length),
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
                        setState(() {
                          if (!_showGrid) {
                            _showGrid = true;
                            _gridStyle = WhiteboardGridStyle.dots;
                          } else if (_gridStyle == WhiteboardGridStyle.dots) {
                            _gridStyle = WhiteboardGridStyle.lines;
                          } else {
                            _showGrid = false;
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.black : Colors.white)
                              .withAlpha(180),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colors.primary.withAlpha(isDark ? 40 : 20),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _showGrid
                                  ? (_gridStyle == WhiteboardGridStyle.dots
                                        ? Icons.grain_rounded
                                        : Icons.grid_on_rounded)
                                  : Icons.grid_off_rounded,
                              size: 14,
                              color: _showGrid
                                  ? colors.primary
                                  : colors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _showGrid
                                  ? (_gridStyle == WhiteboardGridStyle.dots
                                        ? l10n.whiteboardGridDots
                                        : l10n.whiteboardGridLines)
                                  : l10n.whiteboardGridBlank,
                              style: context.typography.caption.regular
                                  .copyWith(
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
                        setState(
                          () => _showToolsExpanded = !_showToolsExpanded,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (isDark ? Colors.black : Colors.white)
                              .withAlpha(180),
                          border: Border.all(
                            color: colors.primary.withAlpha(isDark ? 40 : 20),
                          ),
                        ),
                        child: Icon(
                          _showToolsExpanded
                              ? Icons.keyboard_arrow_down_rounded
                              : Icons.tune_rounded,
                          size: 16,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Floating Tools Toolbar (Tools, Colors, Width, Actions)
            if (_showToolsExpanded && !widget.readOnly)
              Positioned(
                bottom: 10,
                left: 10,
                right: 10,
                child: Container(
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
                              icon: Icons.edit_rounded,
                              tool: WhiteboardTool.pen,
                              tooltip: l10n.whiteboardToolPen,
                            ),
                            _buildToolIcon(
                              icon: Icons.brush_rounded,
                              tool: WhiteboardTool.highlighter,
                              tooltip: l10n.whiteboardToolHighlighter,
                            ),
                            _buildToolIcon(
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
                              icon: Icons.horizontal_rule_rounded,
                              tool: WhiteboardTool.line,
                              tooltip: l10n.whiteboardToolLine,
                            ),
                            _buildToolIcon(
                              icon: Icons.arrow_forward_rounded,
                              tool: WhiteboardTool.arrow,
                              tooltip: l10n.whiteboardToolArrow,
                            ),
                            _buildToolIcon(
                              icon: Icons.crop_square_rounded,
                              tool: WhiteboardTool.rectangle,
                              tooltip: l10n.whiteboardToolRectangle,
                            ),
                            _buildToolIcon(
                              icon: Icons.circle_outlined,
                              tool: WhiteboardTool.circle,
                              tooltip: l10n.whiteboardToolCircle,
                            ),
                            const SizedBox(width: 8),
                            // Stroke width presets
                            ..._strokeWidthPresets.map((w) {
                              final isSel = _strokeWidth == w;
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                child: GestureDetector(
                                  onTap: () {
                                    unawaited(HapticFeedback.selectionClick());
                                    setState(() => _strokeWidth = w);
                                  },
                                  child: Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isSel
                                          ? colors.primary.withAlpha(40)
                                          : Colors.transparent,
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
                            ..._colorPalette.map((colorHex) {
                              final isSelected =
                                  _activeTool != WhiteboardTool.eraser &&
                                  _selectedColorHex == colorHex;
                              return Padding(
                                padding: const EdgeInsets.only(right: 5),
                                child: GestureDetector(
                                  onTap: () {
                                    unawaited(HapticFeedback.selectionClick());
                                    setState(() {
                                      _selectedColorHex = colorHex;
                                      if (_activeTool ==
                                          WhiteboardTool.eraser) {
                                        _activeTool = WhiteboardTool.pen;
                                      }
                                    });
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
                                            : Colors.grey.withAlpha(80),
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
                                onTap: widget.canUndo
                                    ? () {
                                        unawaited(HapticFeedback.lightImpact());
                                        widget.onUndo?.call();
                                      }
                                    : null,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: widget.canUndo
                                        ? colors.surfaceTertiary
                                        : colors.surfaceTertiary.withAlpha(60),
                                  ),
                                  child: Icon(
                                    Icons.undo_rounded,
                                    size: 14,
                                    color: widget.canUndo
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
                                onTap: widget.canRedo
                                    ? () {
                                        unawaited(HapticFeedback.lightImpact());
                                        widget.onRedo?.call();
                                      }
                                    : null,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: widget.canRedo
                                        ? colors.surfaceTertiary
                                        : colors.surfaceTertiary.withAlpha(60),
                                  ),
                                  child: Icon(
                                    Icons.redo_rounded,
                                    size: 14,
                                    color: widget.canRedo
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
                                  _showClearConfirmDialog();
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
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolIcon({
    required IconData icon,
    required WhiteboardTool tool,
    required String tooltip,
  }) {
    final colors = context.colors;
    final isSelected = _activeTool == tool;

    return Padding(
      padding: const EdgeInsets.only(right: 3),
      child: Tooltip(
        message: tooltip,
        child: GestureDetector(
          onTap: () {
            unawaited(HapticFeedback.selectionClick());
            setState(() => _activeTool = tool);
          },
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: isSelected
                  ? colors.primary.withAlpha(widget.isDark ? 60 : 35)
                  : Colors.transparent,
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
}

class _WhiteboardCanvasPainter extends CustomPainter {
  const _WhiteboardCanvasPainter({
    required this.strokes,
    required this.livePoints,
    required this.liveColorHex,
    required this.liveStrokeWidth,
    required this.activeTool,
    required this.isDark,
    required this.showGrid,
    required this.gridStyle,
  });

  final List<WhiteboardStroke> strokes;
  final List<WhiteboardPoint> livePoints;
  final int liveColorHex;
  final double liveStrokeWidth;
  final WhiteboardTool activeTool;
  final bool isDark;
  final bool showGrid;
  final WhiteboardGridStyle gridStyle;

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Grid Background if enabled
    if (showGrid) {
      _drawGrid(canvas, size);
    }

    // 2. Draw completed strokes
    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;
      _drawCompletedStroke(canvas, size, stroke);
    }

    // 3. Draw live dragging stroke / shape preview
    if (livePoints.isNotEmpty) {
      _drawLiveStroke(canvas, size);
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withAlpha(
        isDark ? 15 : 12,
      )
      ..strokeWidth = 1.0;

    const spacing = 24.0;

    if (gridStyle == WhiteboardGridStyle.dots) {
      for (var x = spacing / 2; x < size.width; x += spacing) {
        for (var y = spacing / 2; y < size.height; y += spacing) {
          canvas.drawCircle(Offset(x, y), 1, gridPaint);
        }
      }
    } else if (gridStyle == WhiteboardGridStyle.lines) {
      for (var y = spacing; y < size.height; y += spacing) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      }
    }
  }

  void _drawCompletedStroke(Canvas canvas, Size size, WhiteboardStroke stroke) {
    final paint = Paint()
      ..color = Color(stroke.colorHex)
      ..strokeWidth = stroke.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (stroke.isShape) {
      _drawShape(
        canvas,
        size,
        stroke.shapeType ?? 'rectangle',
        stroke.points.first,
        stroke.points.last,
        paint,
      );
    } else {
      final path = Path()
        ..moveTo(
          stroke.points.first.x * size.width,
          stroke.points.first.y * size.height,
        );

      for (var i = 1; i < stroke.points.length; i++) {
        path.lineTo(
          stroke.points[i].x * size.width,
          stroke.points[i].y * size.height,
        );
      }
      canvas.drawPath(path, paint);
    }
  }

  void _drawLiveStroke(Canvas canvas, Size size) {
    var effectiveColor = liveColorHex;
    if (activeTool == WhiteboardTool.eraser) {
      effectiveColor = isDark ? 0xFF13141E : 0xFFFFFFFF;
    } else if (activeTool == WhiteboardTool.highlighter) {
      effectiveColor = (liveColorHex & 0x00FFFFFF) | 0x66000000;
    }

    final livePaint = Paint()
      ..color = Color(effectiveColor)
      ..strokeWidth = liveStrokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (_isShapeTool(activeTool) && livePoints.length >= 2) {
      _drawShape(
        canvas,
        size,
        _shapeTypeForTool(activeTool) ?? 'rectangle',
        livePoints.first,
        livePoints.last,
        livePaint,
      );
    } else {
      final livePath = Path()
        ..moveTo(
          livePoints.first.x * size.width,
          livePoints.first.y * size.height,
        );

      for (var i = 1; i < livePoints.length; i++) {
        livePath.lineTo(
          livePoints[i].x * size.width,
          livePoints[i].y * size.height,
        );
      }
      canvas.drawPath(livePath, livePaint);
    }
  }

  void _drawShape(
    Canvas canvas,
    Size size,
    String shapeType,
    WhiteboardPoint p1,
    WhiteboardPoint p2,
    Paint paint,
  ) {
    final start = Offset(p1.x * size.width, p1.y * size.height);
    final end = Offset(p2.x * size.width, p2.y * size.height);

    switch (shapeType) {
      case 'line':
        canvas.drawLine(start, end, paint);
      case 'arrow':
        _drawArrow(canvas, start, end, paint);
      case 'rectangle':
        final rect = Rect.fromPoints(start, end);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(4)),
          paint,
        );
      case 'circle':
        final rect = Rect.fromPoints(start, end);
        canvas.drawOval(rect, paint);
      case _:
        canvas.drawLine(start, end, paint);
    }
  }

  void _drawArrow(Canvas canvas, Offset start, Offset end, Paint paint) {
    canvas.drawLine(start, end, paint);

    final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
    const arrowHeadLength = 14.0;
    const arrowAngle = math.pi / 6; // 30 degrees

    final arrowP1 = Offset(
      end.dx - arrowHeadLength * math.cos(angle - arrowAngle),
      end.dy - arrowHeadLength * math.sin(angle - arrowAngle),
    );
    final arrowP2 = Offset(
      end.dx - arrowHeadLength * math.cos(angle + arrowAngle),
      end.dy - arrowHeadLength * math.sin(angle + arrowAngle),
    );

    canvas
      ..drawLine(end, arrowP1, paint)
      ..drawLine(end, arrowP2, paint);
  }

  bool _isShapeTool(WhiteboardTool tool) {
    return tool == WhiteboardTool.line ||
        tool == WhiteboardTool.arrow ||
        tool == WhiteboardTool.rectangle ||
        tool == WhiteboardTool.circle;
  }

  String? _shapeTypeForTool(WhiteboardTool tool) {
    return switch (tool) {
      WhiteboardTool.line => 'line',
      WhiteboardTool.arrow => 'arrow',
      WhiteboardTool.rectangle => 'rectangle',
      WhiteboardTool.circle => 'circle',
      WhiteboardTool.pen ||
      WhiteboardTool.highlighter ||
      WhiteboardTool.eraser => null,
    };
  }

  @override
  bool shouldRepaint(covariant _WhiteboardCanvasPainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.livePoints != livePoints ||
        oldDelegate.liveColorHex != liveColorHex ||
        oldDelegate.liveStrokeWidth != liveStrokeWidth ||
        oldDelegate.activeTool != activeTool ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.gridStyle != gridStyle;
  }
}
