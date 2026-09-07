import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/community/data/client/ephemeral_presence_client.dart';
import 'package:kortex/src/features/community/domain/services/whiteboard_compression.dart';

void main() {
  group('WhiteboardCompression Service', () {
    test('Douglas-Peucker simplifies collinear points along a straight stroke', () {
      final straightLine = [
        const WhiteboardPoint(x: 0, y: 0),
        const WhiteboardPoint(x: 10, y: 10),
        const WhiteboardPoint(x: 20, y: 20),
        const WhiteboardPoint(x: 30, y: 30),
        const WhiteboardPoint(x: 40, y: 40),
        const WhiteboardPoint(x: 50, y: 50),
      ];

      final simplified = WhiteboardCompression.simplify(straightLine, epsilon: 1);
      expect(simplified.length, equals(2));
      expect(simplified.first.x, equals(0));
      expect(simplified.last.x, equals(50));
    });

    test('Douglas-Peucker preserves prominent corner vertices', () {
      final cornerStroke = [
        const WhiteboardPoint(x: 0, y: 0),
        const WhiteboardPoint(x: 10, y: 0),
        const WhiteboardPoint(x: 20, y: 0),
        const WhiteboardPoint(x: 20, y: 20), // Sharp 90-degree corner
        const WhiteboardPoint(x: 20, y: 40),
      ];

      final simplified = WhiteboardCompression.simplify(cornerStroke, epsilon: 1);
      expect(simplified.length, equals(3));
      expect(simplified[0].x, equals(0));
      expect(simplified[1].x, equals(20));
      expect(simplified[1].y, equals(0));
      expect(simplified[2].y, equals(40));
    });

    test('encodeDelta and decodeDelta produce accurate reconstruction', () {
      final points = [
        const WhiteboardPoint(x: 105.4, y: 200.2),
        const WhiteboardPoint(x: 110.8, y: 205.7),
        const WhiteboardPoint(x: 115.3, y: 210.1),
        const WhiteboardPoint(x: 120, y: 215),
      ];

      final deltas = WhiteboardCompression.encodeDelta(points);
      expect(deltas.length, equals(8)); // 2 for start + 2 * 3 for deltas
      expect(deltas[0], equals(105.4));
      expect(deltas[1], equals(200.2));
      expect(deltas[2], equals(5.4)); // 110.8 - 105.4

      final reconstructed = WhiteboardCompression.decodeDelta(deltas);
      expect(reconstructed.length, equals(points.length));
      for (var i = 0; i < points.length; i++) {
        expect((reconstructed[i].x - points[i].x).abs() < 0.15, isTrue);
        expect((reconstructed[i].y - points[i].y).abs() < 0.15, isTrue);
      }
    });

    test('WhiteboardStroke serializes to delta-encoded format and deserializes faithfully', () {
      const stroke = WhiteboardStroke(
        id: 'stroke_1',
        userId: 'user_test',
        userName: 'Scholar Marie',
        colorHex: 0xFFFFFFFF,
        strokeWidth: 4,
        points: [
          WhiteboardPoint(x: 10, y: 20),
          WhiteboardPoint(x: 15, y: 25),
          WhiteboardPoint(x: 22, y: 30),
        ],
      );

      final json = stroke.toJson();
      expect(json.containsKey('deltas'), isTrue);
      expect(json['deltas'] is List, isTrue);

      final deserialized = WhiteboardStroke.fromJson(json);
      expect(deserialized.id, equals('stroke_1'));
      expect(deserialized.points.length, equals(3));
      expect(deserialized.points[0].x, equals(10.0));
      expect(deserialized.points[0].y, equals(20.0));
      expect(deserialized.points[1].x, equals(15.0));
      expect(deserialized.points[1].y, equals(25.0));
      expect(deserialized.points[2].x, equals(22.0));
      expect(deserialized.points[2].y, equals(30.0));
    });
  });
}
