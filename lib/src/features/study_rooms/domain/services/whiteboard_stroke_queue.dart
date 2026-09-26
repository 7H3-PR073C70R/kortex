import 'dart:async';
import 'package:kortex/src/features/study_rooms/data/client/ephemeral_presence_client.dart';
import 'package:kortex/src/features/study_rooms/domain/services/whiteboard_compression.dart';

/// Buffer queue that batches raw whiteboard stroke points over a throttle window (default 100ms),
/// applies Douglas-Peucker stroke simplification, and flushes vector data to reduce socket traffic.
class WhiteboardStrokeQueue {
  WhiteboardStrokeQueue({
    required this.onFlush,
    this.flushInterval = const Duration(milliseconds: 100),
  });

  final void Function(List<WhiteboardPoint> strokePoints) onFlush;
  final Duration flushInterval;

  final List<WhiteboardPoint> _buffer = [];
  Timer? _flushTimer;

  void addPoint(WhiteboardPoint point) {
    _buffer.add(point);
    _scheduleFlush();
  }

  void _scheduleFlush() {
    _flushTimer ??= Timer(flushInterval, flush);
  }

  void flush() {
    _flushTimer?.cancel();
    _flushTimer = null;
    if (_buffer.isEmpty) return;

    final simplified = WhiteboardCompression.simplify(_buffer);
    onFlush(List.of(simplified));
    _buffer.clear();
  }

  void dispose() {
    _flushTimer?.cancel();
    _buffer.clear();
  }
}
