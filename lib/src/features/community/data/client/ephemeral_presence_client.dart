import 'dart:async';
import 'dart:convert';

import 'package:kortex/src/core/networking/realtime/realtime_client.dart';

class EphemeralParticipant {
  const EphemeralParticipant({
    required this.userId,
    required this.displayName,
    required this.avatarUrl,
    this.isHandRaised = false,
    this.joinedAt,
  });

  factory EphemeralParticipant.fromJson(Map<String, dynamic> json) {
    return EphemeralParticipant(
      userId: json['userId'] as String? ?? 'unknown',
      displayName: json['displayName'] as String? ?? 'Scholar',
      avatarUrl: json['avatarUrl'] as String? ?? '',
      isHandRaised: json['isHandRaised'] as bool? ?? false,
      joinedAt: json['joinedAt'] != null
          ? DateTime.tryParse(json['joinedAt'] as String)
          : null,
    );
  }

  final String userId;
  final String displayName;
  final String avatarUrl;
  final bool isHandRaised;
  final DateTime? joinedAt;

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'isHandRaised': isHandRaised,
      'joinedAt': (joinedAt ?? DateTime.now()).toIso8601String(),
    };
  }

  EphemeralParticipant copyWith({
    String? userId,
    String? displayName,
    String? avatarUrl,
    bool? isHandRaised,
    DateTime? joinedAt,
  }) {
    return EphemeralParticipant(
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isHandRaised: isHandRaised ?? this.isHandRaised,
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

  Stream<List<EphemeralParticipant>> watchParticipants(String roomId);

  Stream<PomodoroSyncEvent> watchPomodoroSync(String roomId);

  Future<void> recordCompletedPomodoroSession({
    required String userId,
    required String roomId,
    required int durationMinutes,
    required String subject,
  });
}

/// Real-time presence client backed by the WebSocket [RealtimeClient].
///
/// Each study room maps to a broadcast channel `room:{roomId}`.
/// Participant state is shared via broadcast payloads; all devices
/// in the same channel see the same participant list in real time.
class EphemeralPresenceClientImpl implements EphemeralPresenceClient {
  EphemeralPresenceClientImpl({RealtimeClient? realtimeClient})
      : _realtime = realtimeClient ?? RealtimeClient.instance;

  final RealtimeClient _realtime;

  // Local view: roomId → Map<userId, participant>
  final Map<String, Map<String, EphemeralParticipant>> _roomParticipants = {};

  // Stream controllers per room for participants
  final Map<String, StreamController<List<EphemeralParticipant>>>
      _participantControllers = {};

  // Stream controllers per room for Pomodoro sync events
  final Map<String, StreamController<PomodoroSyncEvent>> _pomodoroControllers =
      {};

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
          final inner = payload['payload'] as Map<String, dynamic>? ?? {};
          final type = inner['type'] as String?;

          if (type == 'presence') {
            final data = inner['data'] as Map<String, dynamic>? ?? {};
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
            final data = inner['data'] as Map<String, dynamic>? ?? {};
            final syncEvent = PomodoroSyncEvent.fromJson(data);
            _pomodoroControllers[roomId]?.add(syncEvent);
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
    final existing = _roomParticipants[roomId]?[userId];
    if (existing != null) {
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
  Future<void> recordCompletedPomodoroSession({
    required String userId,
    required String roomId,
    required int durationMinutes,
    required String subject,
  }) async {
    // Recorded via the REST API in EphemeralRoomRepositoryImpl
    // No action needed here at the presence layer
  }
}
