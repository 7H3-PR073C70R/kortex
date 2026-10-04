import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/study_rooms/data/client/ephemeral_presence_client.dart';
import 'package:kortex/src/features/study_rooms/domain/services/whiteboard_compression.dart';
import 'package:kortex/src/features/study_rooms/domain/services/whiteboard_stroke_queue.dart';

void main() {
  group('WhiteboardCompression Tests', () {
    test('simplifies dense collinear points using Ramer-Douglas-Peucker', () {
      final points = [
        const WhiteboardPoint(x: 0, y: 0),
        const WhiteboardPoint(x: 0.1, y: 0.1),
        const WhiteboardPoint(x: 0.2, y: 0.2),
        const WhiteboardPoint(x: 0.3, y: 0.3),
        const WhiteboardPoint(x: 1, y: 1),
      ];

      final simplified = WhiteboardCompression.simplify(points);
      expect(simplified.length, lessThan(points.length));
      expect(simplified.first, equals(points.first));
      expect(simplified.last, equals(points.last));
    });

    test('roundtrips delta encoding and decoding correctly', () {
      final points = [
        const WhiteboardPoint(x: 0.12345, y: 0.67891),
        const WhiteboardPoint(x: 0.20000, y: 0.70000),
      ];

      final encoded = WhiteboardCompression.encodeDelta(points);
      final decoded = WhiteboardCompression.decodeDelta(encoded);

      expect(decoded.length, equals(points.length));
      expect((decoded[0].x - points[0].x).abs(), lessThan(0.001));
      expect((decoded[0].y - points[0].y).abs(), lessThan(0.001));
    });
  });

  group('WhiteboardStrokeQueue Tests', () {
    test('buffers points and flushes on timer or manual flush', () {
      var flushedPoints = <WhiteboardPoint>[];

      final queue = WhiteboardStrokeQueue(
        onFlush: (pts) => flushedPoints = pts,
        flushInterval: const Duration(milliseconds: 50),
      )
        ..addPoint(const WhiteboardPoint(x: 0.1, y: 0.1))
        ..addPoint(const WhiteboardPoint(x: 0.2, y: 0.2))
        ..addPoint(const WhiteboardPoint(x: 0.3, y: 0.3));

      expect(flushedPoints.isEmpty, isTrue);

      queue.flush();

      expect(flushedPoints.isNotEmpty, isTrue);
      expect(flushedPoints.first.x, equals(0.1));
      queue.dispose();
    });
  });
}
