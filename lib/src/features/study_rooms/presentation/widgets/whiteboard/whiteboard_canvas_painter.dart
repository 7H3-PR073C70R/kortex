import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/features/study_rooms/domain/entities/whiteboard_stroke.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/whiteboard/whiteboard_tool_types.dart';

/// High-performance custom painter for the collaborative whiteboard canvas.
class WhiteboardCanvasPainter extends CustomPainter {
  const WhiteboardCanvasPainter({
    required this.strokes,
    required this.livePoints,
    required this.liveColorHex,
    required this.liveStrokeWidth,
    required this.activeTool,
    required this.isDark,
    required this.showGrid,
    required this.gridStyle,
    required this.colors,
  });

  final List<WhiteboardStroke> strokes;
  final List<WhiteboardPoint> livePoints;
  final int liveColorHex;
  final double liveStrokeWidth;
  final WhiteboardTool activeTool;
  final bool isDark;
  final bool showGrid;
  final WhiteboardGridStyle gridStyle;
  final AppThemeColorsExtension colors;

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
      ..color = (isDark ? colors.white : colors.black).withAlpha(
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

  Path _buildSmoothPath(List<WhiteboardPoint> points, Size size) {
    final path = Path();
    if (points.isEmpty) return path;

    final p0 = Offset(points[0].x * size.width, points[0].y * size.height);
    path.moveTo(p0.dx, p0.dy);

    if (points.length == 1) {
      path.addOval(Rect.fromCircle(center: p0, radius: 0.5));
      return path;
    }

    if (points.length == 2) {
      final p1 = Offset(points[1].x * size.width, points[1].y * size.height);
      path.lineTo(p1.dx, p1.dy);
      return path;
    }

    for (var i = 1; i < points.length - 1; i++) {
      final pCurrent = Offset(
        points[i].x * size.width,
        points[i].y * size.height,
      );
      final pNext = Offset(
        points[i + 1].x * size.width,
        points[i + 1].y * size.height,
      );
      final midX = (pCurrent.dx + pNext.dx) / 2;
      final midY = (pCurrent.dy + pNext.dy) / 2;
      path.quadraticBezierTo(pCurrent.dx, pCurrent.dy, midX, midY);
    }

    final pLast = Offset(
      points.last.x * size.width,
      points.last.y * size.height,
    );
    path.lineTo(pLast.dx, pLast.dy);

    return path;
  }

  void _drawCompletedStroke(Canvas canvas, Size size, WhiteboardStroke stroke) {
    final strokeColor = stroke.isEraser
        ? (isDark ? colors.surfacePrimary : colors.white)
        : Color(stroke.colorHex);

    final paint = Paint()
      ..color = strokeColor
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
      final path = _buildSmoothPath(stroke.points, size);
      canvas.drawPath(path, paint);
    }
  }

  void _drawLiveStroke(Canvas canvas, Size size) {
    var effectiveColor = liveColorHex;
    if (activeTool == WhiteboardTool.eraser) {
      effectiveColor = isDark
          ? colors.surfacePrimary.toARGB32()
          : colors.white.toARGB32();
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
      final livePath = _buildSmoothPath(livePoints, size);
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

  static bool _isShapeTool(WhiteboardTool tool) {
    return tool == WhiteboardTool.line ||
        tool == WhiteboardTool.arrow ||
        tool == WhiteboardTool.rectangle ||
        tool == WhiteboardTool.circle;
  }

  static String? _shapeTypeForTool(WhiteboardTool tool) {
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
  bool shouldRepaint(covariant WhiteboardCanvasPainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.livePoints != livePoints ||
        oldDelegate.liveColorHex != liveColorHex ||
        oldDelegate.liveStrokeWidth != liveStrokeWidth ||
        oldDelegate.activeTool != activeTool ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.gridStyle != gridStyle;
  }
}
