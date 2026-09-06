import 'dart:async';
import 'dart:convert';

import 'package:kortex/src/core/networking/realtime/realtime_client.dart';
import 'package:kortex/src/features/community/domain/services/whiteboard_compression.dart';

class EphemeralParticipant {
  const EphemeralParticipant({
    required this.userId,
    required this.displayName,
    required this.avatarUrl,
    this.isHandRaised = false,
    this.isMuted = true,
    this.joinedAt,
  });

  factory EphemeralParticipant.fromJson(Map<String, dynamic> json) {
    return EphemeralParticipant(
      userId: json['userId'] as String? ?? 'unknown',
      displayName: json['displayName'] as String? ?? 'Scholar',
      avatarUrl: json['avatarUrl'] as String? ?? '',
      isHandRaised: json['isHandRaised'] as bool? ?? false,
      isMuted: json['isMuted'] as bool? ?? true,
      joinedAt: json['joinedAt'] != null
          ? DateTime.tryParse(json['joinedAt'] as String)
          : null,
    );
  }

  final String userId;
  final String displayName;
  final String avatarUrl;
  final bool isHandRaised;
  final bool isMuted;
  final DateTime? joinedAt;

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'isHandRaised': isHandRaised,
      'isMuted': isMuted,
      'joinedAt': (joinedAt ?? DateTime.now()).toIso8601String(),
    };
  }

  EphemeralParticipant copyWith({
    String? userId,
    String? displayName,
    String? avatarUrl,
    bool? isHandRaised,
    bool? isMuted,
    DateTime? joinedAt,
  }) {
    return EphemeralParticipant(
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isHandRaised: isHandRaised ?? this.isHandRaised,
      isMuted: isMuted ?? this.isMuted,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }
}

class PomodoroSyncEvent {
  const PomodoroSyncEvent({
    required this.roomId,
    required this.remainingSeconds,
    required this.pomodoroState,
    required this.senderId,
    required this.timestamp,
  });

  factory PomodoroSyncEvent.fromJson(Map<String, dynamic> json) {
    return PomodoroSyncEvent(
      roomId: json['roomId'] as String? ?? '',
      remainingSeconds: json['remainingSeconds'] as int? ?? 1500,
      pomodoroState: json['pomodoroState'] as String? ?? 'focusing',
      senderId: json['senderId'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  final String roomId;
  final int remainingSeconds;
  final String pomodoroState; // 'focusing', 'break', 'paused'
  final String senderId;
  final DateTime timestamp;

  Map<String, dynamic> toJson() {
    return {
      'roomId': roomId,
      'remainingSeconds': remainingSeconds,
      'pomodoroState': pomodoroState,
      'senderId': senderId,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

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
    if (json['deltas'] is List) {
      parsedPoints =
          WhiteboardCompression.decodeDelta(json['deltas'] as List<dynamic>);
    } else if (json['points'] is List) {
      parsedPoints = (json['points'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(WhiteboardPoint.fromJson)
          .toList();
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
    };
  }
}

class RoomChatMessage {
  const RoomChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderAvatar,
    required this.text,
    required this.timestamp,
    this.isReaction = false,
  });

  factory RoomChatMessage.fromJson(Map<String, dynamic> json) {
    return RoomChatMessage(
      id: json['id'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      senderName: json['senderName'] as String? ?? 'Scholar',
      senderAvatar: json['senderAvatar'] as String? ?? '',
      text: json['text'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      isReaction: json['isReaction'] as bool? ?? false,
    );
  }

  final String id;
  final String senderId;
  final String senderName;
  final String senderAvatar;
  final String text;
  final DateTime timestamp;
  final bool isReaction;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'isReaction': isReaction,
    };
  }
}

abstract class EphemeralPresenceClient {
  Future<void> joinRoomPresence({
    required String roomId,
    required String userId,
    required String displayName,
    required String avatarUrl,
  });

  Future<void> leaveRoomPresence(String roomId);

  Future<void> broadcastPomodoroTick({
    required String roomId,
    required int remainingSeconds,
    required String pomodoroState,
    required String senderId,
  });

  Future<void> broadcastHandRaise({
    required String roomId,
    required String userId,
    required bool isHandRaised,
  });

  Future<void> broadcastMuteState({
    required String roomId,
    required String userId,
    required bool isMuted,
  });

  Future<void> broadcastWhiteboardStroke({
    required String roomId,
    required WhiteboardStroke stroke,
  });

  Future<void> broadcastWhiteboardClear({required String roomId});

  Future<void> broadcastChatMessage({
    required String roomId,
    required RoomChatMessage message,
  });

  Stream<List<EphemeralParticipant>> watchParticipants(String roomId);

  Stream<PomodoroSyncEvent> watchPomodoroSync(String roomId);

  Stream<WhiteboardStroke> watchWhiteboardStrokes(String roomId);

  Stream<void> watchWhiteboardClear(String roomId);

  Stream<RoomChatMessage> watchChatMessages(String roomId);

  Future<void> recordCompletedPomodoroSession({
    required String userId,
    required String roomId,
    required int durationMinutes,
    required String subject,
  });
}

/// Real-time presence client backed by the WebSocket [RealtimeClient].
class EphemeralPresenceClientImpl implements EphemeralPresenceClient {
  EphemeralPresenceClientImpl({RealtimeClient? realtimeClient})
      : _realtime = realtimeClient ?? RealtimeClient.instance;

  final RealtimeClient _realtime;

  // Local view: roomId → Map<userId, participant>
  final Map<String, Map<String, EphemeralParticipant>> _roomParticipants = {};

  // Stream controllers per room
  final Map<String, StreamController<List<EphemeralParticipant>>>
      _participantControllers = {};
  final Map<String, StreamController<PomodoroSyncEvent>> _pomodoroControllers =
      {};
  final Map<String, StreamController<WhiteboardStroke>> _whiteboardControllers =
      {};
  final Map<String, StreamController<void>> _whiteboardClearControllers = {};
  final Map<String, StreamController<RoomChatMessage>> _chatControllers = {};

  // WS subscriptions per room
  final Map<String, StreamSubscription<Map<String, dynamic>>> _wsSubs = {};

  String _channelName(String roomId) => 'room:$roomId';

  void _ensureRoomListening(String roomId) {
    if (_wsSubs.containsKey(roomId)) return;

    final channel = _channelName(roomId);
    _wsSubs[roomId] = _realtime.watchPresence(channel).listen((msg) {
      try {
        final event = msg['event'] as String?;
        final payload = msg['payload'] as Map<String, dynamic>? ?? {};

        if (event == 'broadcast') {
          final inner = (payload['payload'] as Map<String, dynamic>?) ?? payload;
          final type = inner['type'] as String?;

          if (type == 'presence') {
            final data = (inner['data'] as Map<String, dynamic>?) ?? inner;
            final action = data['action'] as String?;
            final userId = data['userId'] as String?;
            if (userId == null) return;

            _roomParticipants.putIfAbsent(roomId, () => {});
            if (action == 'leave') {
              _roomParticipants[roomId]!.remove(userId);
            } else {
              _roomParticipants[roomId]![userId] =
                  EphemeralParticipant.fromJson(data);
            }
            _notifyParticipants(roomId);
          } else if (type == 'pomodoro_tick') {
            final data = (inner['data'] as Map<String, dynamic>?) ?? inner;
            final syncEvent = PomodoroSyncEvent.fromJson(data);
            _pomodoroControllers[roomId]?.add(syncEvent);
          } else if (type == 'whiteboard_stroke') {
            final data = (inner['data'] as Map<String, dynamic>?) ?? inner;
            final stroke = WhiteboardStroke.fromJson(data);
            _whiteboardControllers[roomId]?.add(stroke);
          } else if (type == 'whiteboard_clear') {
            _whiteboardClearControllers[roomId]?.add(null);
          } else if (type == 'chat_message') {
            final data = (inner['data'] as Map<String, dynamic>?) ?? inner;
            final chat = RoomChatMessage.fromJson(data);
            _chatControllers[roomId]?.add(chat);
          }
        }

        // Handle native presence_state / presence_diff if available
        if (event == 'presence_state') {
          final joins = payload['joins'] as Map<String, dynamic>? ?? {};
          _roomParticipants.putIfAbsent(roomId, () => {});
          for (final entry in joins.entries) {
            final valueMap = entry.value as Map<String, dynamic>? ?? {};
            final metas = valueMap['metas'] as List<dynamic>? ?? [];
            if (metas.isNotEmpty) {
              final meta = metas.first as Map<String, dynamic>;
              _roomParticipants[roomId]![entry.key] =
                  EphemeralParticipant.fromJson(meta);
            }
          }
          _notifyParticipants(roomId);
        }

        if (event == 'presence_diff') {
          final leaves = payload['leaves'] as Map<String, dynamic>? ?? {};
          final joins = payload['joins'] as Map<String, dynamic>? ?? {};
          _roomParticipants.putIfAbsent(roomId, () => {});
          leaves.keys.forEach(_roomParticipants[roomId]!.remove);
          for (final entry in joins.entries) {
            final valueMap = entry.value as Map<String, dynamic>? ?? {};
            final metas = valueMap['metas'] as List<dynamic>? ?? [];
            if (metas.isNotEmpty) {
              final meta = metas.first as Map<String, dynamic>;
              _roomParticipants[roomId]![entry.key] =
                  EphemeralParticipant.fromJson(meta);
            }
          }
          _notifyParticipants(roomId);
        }
      } on Exception catch (_) {}
    });
  }

  void _notifyParticipants(String roomId) {
    final list = _roomParticipants[roomId]?.values.toList() ?? [];
    _participantControllers[roomId]?.add(list);
  }

  @override
  Future<void> joinRoomPresence({
    required String roomId,
    required String userId,
    required String displayName,
    required String avatarUrl,
  }) async {
    _ensureRoomListening(roomId);
    final participant = EphemeralParticipant(
      userId: userId,
      displayName: displayName,
      avatarUrl: avatarUrl,
      joinedAt: DateTime.now(),
    );
    _roomParticipants.putIfAbsent(roomId, () => {});
    _roomParticipants[roomId]![userId] = participant;
    _notifyParticipants(roomId);

    _realtime.broadcastPresence(
      channelName: _channelName(roomId),
      payload: {
        'data': {
          'action': 'join',
          ...participant.toJson(),
        },
      },
    );
  }

  @override
  Future<void> leaveRoomPresence(String roomId) async {
    final participants = _roomParticipants[roomId] ?? {};
    if (participants.isNotEmpty) {
      final userId = participants.keys.first;
      _realtime.broadcastPresence(
        channelName: _channelName(roomId),
        payload: {
          'data': {'action': 'leave', 'userId': userId},
        },
      );
    }
    await _wsSubs.remove(roomId)?.cancel();
    _roomParticipants.remove(roomId);
    unawaited(_participantControllers.remove(roomId)?.close() ?? Future<void>.value());
    unawaited(_pomodoroControllers.remove(roomId)?.close() ?? Future<void>.value());
    unawaited(_whiteboardControllers.remove(roomId)?.close() ?? Future<void>.value());
    unawaited(_whiteboardClearControllers.remove(roomId)?.close() ?? Future<void>.value());
    unawaited(_chatControllers.remove(roomId)?.close() ?? Future<void>.value());
  }

  @override
  Future<void> broadcastPomodoroTick({
    required String roomId,
    required int remainingSeconds,
    required String pomodoroState,
    required String senderId,
  }) async {
    _realtime.broadcastPresence(
      channelName: _channelName(roomId),
      payload: {
        'data': jsonDecode(
          jsonEncode(
            PomodoroSyncEvent(
              roomId: roomId,
              remainingSeconds: remainingSeconds,
              pomodoroState: pomodoroState,
              senderId: senderId,
              timestamp: DateTime.now(),
            ).toJson(),
          ),
        ),
        'type': 'pomodoro_tick',
      },
    );
  }

  @override
  Future<void> broadcastHandRaise({
    required String roomId,
    required String userId,
    required bool isHandRaised,
  }) async {
    _roomParticipants.putIfAbsent(roomId, () => {});
    final existing = _roomParticipants[roomId]?[userId] ??
        EphemeralParticipant(
          userId: userId,
          displayName: 'Scholar',
          avatarUrl: '',
        );
    final updated = existing.copyWith(isHandRaised: isHandRaised);
    _roomParticipants[roomId]![userId] = updated;
    _notifyParticipants(roomId);
    _realtime.broadcastPresence(
      channelName: _channelName(roomId),
      payload: {
        'data': {'action': 'update', ...updated.toJson()},
      },
    );
  }

  @override
  Future<void> broadcastMuteState({
    required String roomId,
    required String userId,
    required bool isMuted,
  }) async {
    _roomParticipants.putIfAbsent(roomId, () => {});
    final existing = _roomParticipants[roomId]?[userId] ??
        EphemeralParticipant(
          userId: userId,
          displayName: 'Scholar',
          avatarUrl: '',
        );
    final updated = existing.copyWith(isMuted: isMuted);
    _roomParticipants[roomId]![userId] = updated;
    _notifyParticipants(roomId);
    _realtime.broadcastPresence(
      channelName: _channelName(roomId),
      payload: {
        'data': {'action': 'update', ...updated.toJson()},
      },
    );
  }

  @override
  Future<void> broadcastWhiteboardStroke({
    required String roomId,
    required WhiteboardStroke stroke,
  }) async {
    _realtime.broadcastPresence(
      channelName: _channelName(roomId),
      payload: {
        'type': 'whiteboard_stroke',
        'data': stroke.toJson(),
      },
    );
  }

  @override
  Future<void> broadcastWhiteboardClear({required String roomId}) async {
    _realtime.broadcastPresence(
      channelName: _channelName(roomId),
      payload: {
        'type': 'whiteboard_clear',
        'data': {'clearedAt': DateTime.now().toIso8601String()},
      },
    );
  }

  @override
  Future<void> broadcastChatMessage({
    required String roomId,
    required RoomChatMessage message,
  }) async {
    _realtime.broadcastPresence(
      channelName: _channelName(roomId),
      payload: {
        'type': 'chat_message',
        'data': message.toJson(),
      },
    );
  }

  @override
  Stream<List<EphemeralParticipant>> watchParticipants(String roomId) {
    _ensureRoomListening(roomId);
    if (!_participantControllers.containsKey(roomId)) {
      _participantControllers[roomId] =
          StreamController<List<EphemeralParticipant>>.broadcast(
        onListen: () => _notifyParticipants(roomId),
      );
    }
    return _participantControllers[roomId]!.stream;
  }

  @override
  Stream<PomodoroSyncEvent> watchPomodoroSync(String roomId) {
    _ensureRoomListening(roomId);
    if (!_pomodoroControllers.containsKey(roomId)) {
      _pomodoroControllers[roomId] =
          StreamController<PomodoroSyncEvent>.broadcast();
    }
    return _pomodoroControllers[roomId]!.stream;
  }

  @override
  Stream<WhiteboardStroke> watchWhiteboardStrokes(String roomId) {
    _ensureRoomListening(roomId);
    if (!_whiteboardControllers.containsKey(roomId)) {
      _whiteboardControllers[roomId] =
          StreamController<WhiteboardStroke>.broadcast();
    }
    return _whiteboardControllers[roomId]!.stream;
  }

  @override
  Stream<void> watchWhiteboardClear(String roomId) {
    _ensureRoomListening(roomId);
    if (!_whiteboardClearControllers.containsKey(roomId)) {
      _whiteboardClearControllers[roomId] =
          StreamController<void>.broadcast();
    }
    return _whiteboardClearControllers[roomId]!.stream;
  }

  @override
  Stream<RoomChatMessage> watchChatMessages(String roomId) {
    _ensureRoomListening(roomId);
    if (!_chatControllers.containsKey(roomId)) {
      _chatControllers[roomId] =
          StreamController<RoomChatMessage>.broadcast();
    }
    return _chatControllers[roomId]!.stream;
  }

  @override
  Future<void> recordCompletedPomodoroSession({
    required String userId,
    required String roomId,
    required int durationMinutes,
    required String subject,
  }) async {
    // Recorded via the REST API in EphemeralRoomRepositoryImpl
  }
}
