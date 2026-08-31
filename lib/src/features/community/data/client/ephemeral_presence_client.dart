import 'dart:async';

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
  Future<void> joinRoomChannel({
    required String roomId,
    required EphemeralParticipant participant,
  });

  Future<void> leaveRoomChannel(String roomId);

  Future<void> broadcastPomodoroTick(PomodoroSyncEvent event);

  Future<void> broadcastHandRaise({
    required String roomId,
    required String userId,
    required bool isHandRaised,
  });

  Stream<List<EphemeralParticipant>> watchParticipants(String roomId);

  Stream<PomodoroSyncEvent> watchPomodoroSync(String roomId);
}

class EphemeralPresenceClientImpl implements EphemeralPresenceClient {
  EphemeralPresenceClientImpl();

  final Map<String, StreamController<List<EphemeralParticipant>>>
      _participantsControllers = {};
  final Map<String, StreamController<PomodoroSyncEvent>> _pomodoroControllers =
      {};
  final Map<String, Map<String, EphemeralParticipant>> _roomParticipants = {};

  @override
  Future<void> joinRoomChannel({
    required String roomId,
    required EphemeralParticipant participant,
  }) async {
    _roomParticipants.putIfAbsent(roomId, () => {})[participant.userId] =
        participant;
    _notifyParticipants(roomId);
  }

  @override
  Future<void> leaveRoomChannel(String roomId) async {
    _roomParticipants.remove(roomId);
    _notifyParticipants(roomId);
  }

  @override
  Future<void> broadcastPomodoroTick(PomodoroSyncEvent event) async {
    _getPomodoroController(event.roomId).add(event);
  }

  @override
  Future<void> broadcastHandRaise({
    required String roomId,
    required String userId,
    required bool isHandRaised,
  }) async {
    if (_roomParticipants[roomId]?.containsKey(userId) == true) {
      final current = _roomParticipants[roomId]![userId]!;
      _roomParticipants[roomId]![userId] =
          current.copyWith(isHandRaised: isHandRaised);
      _notifyParticipants(roomId);
    }
  }

  @override
  Stream<List<EphemeralParticipant>> watchParticipants(String roomId) {
    return _getParticipantsController(roomId).stream;
  }

  @override
  Stream<PomodoroSyncEvent> watchPomodoroSync(String roomId) {
    return _getPomodoroController(roomId).stream;
  }

  StreamController<List<EphemeralParticipant>> _getParticipantsController(
      String roomId) {
    return _participantsControllers.putIfAbsent(
      roomId,
      () => StreamController<List<EphemeralParticipant>>.broadcast(
        onListen: () => _notifyParticipants(roomId),
      ),
    );
  }

  StreamController<PomodoroSyncEvent> _getPomodoroController(String roomId) {
    return _pomodoroControllers.putIfAbsent(
      roomId,
      StreamController<PomodoroSyncEvent>.broadcast,
    );
  }

  void _notifyParticipants(String roomId) {
    final list = _roomParticipants[roomId]?.values.toList() ?? [];
    if (_participantsControllers.containsKey(roomId)) {
      _participantsControllers[roomId]?.add(list);
    }
  }
}
