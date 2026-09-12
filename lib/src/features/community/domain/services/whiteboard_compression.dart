import 'dart:math' as math;
import 'package:kortex/src/features/community/data/client/ephemeral_presence_client.dart';

/// Pure mathematical service implementing Douglas-Peucker stroke simplification
/// and delta-coordinate compression for whiteboard transmission.
class WhiteboardCompression {
  const WhiteboardCompression._();

  /// Simplifies a polyline using the Ramer-Douglas-Peucker algorithm.
  /// Eliminates intermediate points with perpendicular distance less than [epsilon].
  static List<WhiteboardPoint> simplify(
    List<WhiteboardPoint> points, {
    double epsilon = 1.2,
  }) {
    if (points.length <= 2) return points;

    // Find the point with the maximum distance from line between first and last point
    double dmax = 0;
    var index = 0;
    final end = points.length - 1;

    for (var i = 1; i < end; i++) {
      final d = _perpendicularDistance(points[i], points[0], points[end]);
      if (d > dmax) {
        index = i;
        dmax = d;
      }
    }

    // If max distance is greater than epsilon, recursively simplify
    if (dmax > epsilon) {
      final recursiveResults1 = simplify(
        points.sublist(0, index + 1),
        epsilon: epsilon,
      );
      final recursiveResults2 = simplify(
        points.sublist(index, points.length),
        epsilon: epsilon,
      );

      // Concat without duplicating the middle point
      return [
        ...recursiveResults1.sublist(0, recursiveResults1.length - 1),
        ...recursiveResults2,
      ];
    } else {
      return [points[0], points[end]];
    }
  }

  static double _perpendicularDistance(
    WhiteboardPoint p,
    WhiteboardPoint lineStart,
    WhiteboardPoint lineEnd,
  ) {
    final dx = lineEnd.x - lineStart.x;
    final dy = lineEnd.y - lineStart.y;
    final magSquared = dx * dx + dy * dy;

    if (magSquared == 0) {
      final px = p.x - lineStart.x;
      final py = p.y - lineStart.y;
      return math.sqrt(px * px + py * py);
    }

    final u =
        ((p.x - lineStart.x) * dx + (p.y - lineStart.y) * dy) / magSquared;
    final clampedU = u.clamp(0.0, 1.0);
    final ix = lineStart.x + clampedU * dx;
    final iy = lineStart.y + clampedU * dy;

    final distDx = p.x - ix;
    final distDy = p.y - iy;
    return math.sqrt(distDx * distDx + distDy * distDy);
  }

  /// Encodes points into a flat list of delta offsets rounded to 1 decimal place:
  /// [x0, y0, dx1, dy1, dx2, dy2, ...]
  static List<double> encodeDelta(List<WhiteboardPoint> points) {
    if (points.isEmpty) return const [];

    final encoded = <double>[];
    var prevX = _round(points[0].x);
    var prevY = _round(points[0].y);

    encoded
      ..add(prevX)
      ..add(prevY);

    for (var i = 1; i < points.length; i++) {
      final currentX = _round(points[i].x);
      final currentY = _round(points[i].y);
      final dx = _round(currentX - prevX);
      final dy = _round(currentY - prevY);

      encoded
        ..add(dx)
        ..add(dy);

      prevX = currentX;
      prevY = currentY;
    }

    return encoded;
  }

  /// Decodes flat delta offsets [x0, y0, dx1, dy1, dx2, dy2, ...] back into WhiteboardPoint instances.
  static List<WhiteboardPoint> decodeDelta(List<dynamic> raw) {
    if (raw.length < 2) return const [];

    final points = <WhiteboardPoint>[];
    var curX = (raw[0] as num).toDouble();
    var curY = (raw[1] as num).toDouble();
    points.add(WhiteboardPoint(x: curX, y: curY));

    for (var i = 2; i + 1 < raw.length; i += 2) {
      final dx = (raw[i] as num).toDouble();
      final dy = (raw[i + 1] as num).toDouble();
      curX = _round(curX + dx);
      curY = _round(curY + dy);
      points.add(WhiteboardPoint(x: curX, y: curY));
    }

    return points;
  }

  static double _round(double val) {
    return (val * 10.0).roundToDouble() / 10.0;
  }
}
