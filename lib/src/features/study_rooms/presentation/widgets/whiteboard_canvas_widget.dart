import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/study_rooms/domain/entities/whiteboard_stroke.dart';
import 'package:kortex/src/features/study_rooms/domain/services/whiteboard_compression.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/whiteboard/whiteboard_canvas_painter.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/whiteboard/whiteboard_floating_toolbar.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/whiteboard/whiteboard_tool_types.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/whiteboard/whiteboard_top_status_bar.dart';
import 'package:kortex/src/l10n/l10n.dart';

export 'whiteboard/whiteboard_canvas_painter.dart';
export 'whiteboard/whiteboard_floating_toolbar.dart';
export 'whiteboard/whiteboard_tool_types.dart';
export 'whiteboard/whiteboard_top_status_bar.dart';

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
  int? _selectedColorHex;
  double _strokeWidth = 3.5;
  WhiteboardGridStyle _gridStyle = WhiteboardGridStyle.dots;
  bool _showGrid = true;
  bool _showToolsExpanded = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _selectedColorHex ??= context.colors.primary.toARGB32();
  }

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
      processedPoints = WhiteboardCompression.simplify(_livePoints);
    }

    final colors = context.colors;
    var effectiveColor = _selectedColorHex ?? colors.primary.toARGB32();
    var effectiveWidth = _strokeWidth;

    if (isEraser) {
      effectiveColor = widget.isDark
          ? colors.surfacePrimary.toARGB32()
          : colors.white.toARGB32();
      effectiveWidth = 20.0;
    } else if (isHighlighter) {
      // Apply 40% alpha (0x66) for highlighter feel
      effectiveColor = (effectiveColor & 0x00FFFFFF) | 0x66000000;
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
                color: isDark ? colors.surfacePrimary : colors.white,
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
                      child: RepaintBoundary(
                        child: CustomPaint(
                          size: Size(
                            constraints.maxWidth,
                            constraints.maxHeight,
                          ),
                          painter: WhiteboardCanvasPainter(
                            strokes: widget.strokes,
                            livePoints: _livePoints,
                            liveColorHex:
                                _selectedColorHex ?? colors.primary.toARGB32(),
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
                            colors: colors,
                          ),
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
              child: WhiteboardTopStatusBar(
                strokesCount: widget.strokes.length,
                showGrid: _showGrid,
                gridStyle: _gridStyle,
                showToolsExpanded: _showToolsExpanded,
                isDark: isDark,
                onToggleGrid: () {
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
                onToggleTools: () {
                  setState(() => _showToolsExpanded = !_showToolsExpanded);
                },
              ),
            ),

            // Floating Tools Toolbar (Tools, Colors, Width, Actions)
            if (_showToolsExpanded && !widget.readOnly)
              Positioned(
                bottom: 10,
                left: 10,
                right: 10,
                child: WhiteboardFloatingToolbar(
                  activeTool: _activeTool,
                  selectedColorHex: _selectedColorHex,
                  strokeWidth: _strokeWidth,
                  isDark: isDark,
                  canUndo: widget.canUndo,
                  canRedo: widget.canRedo,
                  onToolChanged: (tool) => setState(() => _activeTool = tool),
                  onColorChanged: (hex) => setState(() {
                    _selectedColorHex = hex;
                    if (_activeTool == WhiteboardTool.eraser) {
                      _activeTool = WhiteboardTool.pen;
                    }
                  }),
                  onStrokeWidthChanged: (w) =>
                      setState(() => _strokeWidth = w),
                  onUndo: widget.onUndo,
                  onRedo: widget.onRedo,
                  onClear: widget.onClear,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
