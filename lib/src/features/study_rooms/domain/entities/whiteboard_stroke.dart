import 'package:kortex/src/features/study_rooms/domain/services/whiteboard_compression.dart';

class WhiteboardPoint {
  const WhiteboardPoint({required this.x, required this.y});

  factory WhiteboardPoint.fromJson(Map<String, dynamic> json) {
    return WhiteboardPoint(
      x: (json['x'] as num?)?.toDouble() ?? 0.0,
      y: (json['y'] as num?)?.toDouble() ?? 0.0,
    );
  }

  final double x;
  final double y;

  Map<String, dynamic> toJson() => {'x': x, 'y': y};
}

class WhiteboardStroke {
  const WhiteboardStroke({
    required this.id,
    required this.userId,
    required this.userName,
    required this.colorHex,
    required this.strokeWidth,
    required this.points,
    this.isEraser = false,
    this.elementType = 'stroke',
    this.shapeType,
    this.text,
    this.fontSize,
  });

  factory WhiteboardStroke.fromJson(Map<String, dynamic> json) {
    final List<WhiteboardPoint> parsedPoints;
    if (json['points'] is List && (json['points'] as List).isNotEmpty) {
      parsedPoints = (json['points'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(WhiteboardPoint.fromJson)
          .toList();
    } else if (json['deltas'] is List) {
      parsedPoints = WhiteboardCompression.decodeDelta(
        json['deltas'] as List<dynamic>,
      );
    } else {
      parsedPoints = const [];
    }

    return WhiteboardStroke(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      userName: json['userName'] as String? ?? 'Scholar',
      colorHex: json['colorHex'] as int? ?? 0xFFFFFFFF,
      strokeWidth: (json['strokeWidth'] as num?)?.toDouble() ?? 3.0,
      isEraser: json['isEraser'] as bool? ?? false,
      elementType: json['elementType'] as String? ?? 'stroke',
      shapeType: json['shapeType'] as String?,
      text: json['text'] as String?,
      fontSize: (json['fontSize'] as num?)?.toDouble(),
      points: parsedPoints,
    );
  }

  final String id;
  final String userId;
  final String userName;
  final int colorHex;
  final double strokeWidth;
  final bool isEraser;
  final String elementType; // 'stroke', 'shape', 'text'
  final String? shapeType; // 'rectangle', 'circle', 'line', 'arrow', 'triangle'
  final String? text;
  final double? fontSize;
  final List<WhiteboardPoint> points;

  bool get isShape => elementType == 'shape';
  bool get isText => elementType == 'text';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'colorHex': colorHex,
      'strokeWidth': strokeWidth,
      'isEraser': isEraser,
      'elementType': elementType,
      if (shapeType != null) 'shapeType': shapeType,
      if (text != null) 'text': text,
      if (fontSize != null) 'fontSize': fontSize,
      'deltas': WhiteboardCompression.encodeDelta(points),
      'points': points.map((p) => p.toJson()).toList(),
    };
  }
}
