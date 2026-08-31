import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:kortex/src/features/rooms/domain/entities/room_member_presence.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Client-side state manager for Kortex Live Study Rooms enforcing
/// Hybrid Dual-Layer Presence (Supabase Realtime Broadcast + Upstash Redis).
///
/// Features:
/// - Real-time ephemeral WebSocket presence & broadcast.
/// - 15-second background HTTP heartbeat to Upstash Redis fallback.
/// - 45-second grace period preventing UI flickering on mobile signal drops.
/// - Single final RPC write (`sync_study_session_summary`) on session exit.
class StudyRoomPresenceController {
  StudyRoomPresenceController({
    SupabaseClient? supabaseClient,
  }) : _supabase = supabaseClient ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  RealtimeChannel? _channel;
  String? _currentRoomId;
  RoomMemberPresence? _currentUser;
  DateTime? _sessionStartTime;

  Timer? _heartbeatTimer;
  Timer? _gracePeriodTimer;

  final StreamController<List<RoomMemberPresence>> _membersController =
      StreamController<List<RoomMemberPresence>>.broadcast();

  final StreamController<StudyRoomTimerState> _timerController =
      StreamController<StudyRoomTimerState>.broadcast();

  final StreamController<Map<String, dynamic>> _broadcastController =
      StreamController<Map<String, dynamic>>.broadcast();

  final Map<String, RoomMemberPresence> _membersMap = {};
  final Map<String, DateTime> _disconnectGraceMap = {};

  static const Duration _heartbeatInterval = Duration(seconds: 15);
  static const Duration _gracePeriodDuration = Duration(seconds: 45);

  /// Stream of currently active study room members.
  Stream<List<RoomMemberPresence>> get membersStream =>
      _membersController.stream;

  /// Stream of synchronized room timer states.
  Stream<StudyRoomTimerState> get timerStream => _timerController.stream;

  /// Stream of live broadcast events (e.g. reactions, whiteboard annotations).
  Stream<Map<String, dynamic>> get broadcastEventsStream =>
      _broadcastController.stream;

  /// Active room identifier.
  String? get currentRoomId => _currentRoomId;

  /// Current user presence profile.
  RoomMemberPresence? get currentUser => _currentUser;

  /// Currently connected members list.
  List<RoomMemberPresence> get currentMembers => _membersMap.values.toList();

  /// Joins a study room and begins tracking ephemeral presence.
  Future<void> initializeAndJoinRoom({
    required String roomId,
    required RoomMemberPresence user,
  }) async {
    // If already in a room, clean up prior presence session
    if (_channel != null && _currentRoomId != roomId) {
      await leaveRoom();
    }

    _currentRoomId = roomId;
    _currentUser = user;
    _sessionStartTime = DateTime.now();
    _membersMap.clear();
    _disconnectGraceMap.clear();
    _membersMap[user.userId] = user;
    _notifyMembersChanged();

    final channelTopic = 'study_room:$roomId';

    _channel = _supabase.channel(
      channelTopic,
      opts: RealtimeChannelConfig(
        key: user.userId,
      ),
    );

    // 1. Presence Sync & Membership Lifecycle
    _channel!.onPresenceSync((_) {
      _reconstructPresenceState();
    });

    _channel!.onPresenceJoin((payload) {
      final newPresences = payload.newPresences;
      for (final presence in newPresences) {
        final payloadData = presence.payload;
        if (payloadData.isNotEmpty) {
          final member = RoomMemberPresence.fromPresencePayload(payloadData);
          _membersMap[member.userId] = member;
          _disconnectGraceMap.remove(member.userId);
        }
      }
      _notifyMembersChanged();
    });

    _channel!.onPresenceLeave((payload) {
      final leftPresences = payload.leftPresences;
      final now = DateTime.now();
      for (final presence in leftPresences) {
        final payloadData = presence.payload;
        final userId = payloadData['userId'] as String?;
        if (userId != null && userId != _currentUser?.userId) {
          // Engage 45-second grace period before removing from UI
          _disconnectGraceMap[userId] = now;
        }
      }
      _checkGracePeriods();
    });

    // 2. Ephemeral Broadcast Handlers (Cursors, Focus, Timer, Reactions)
    _channel!.onBroadcast(
      event: 'cursor_move',
      callback: (payload) {
        final userId = payload['userId'] as String?;
        final cursorData = payload['cursor'];
        if (userId != null && _membersMap.containsKey(userId)) {
          final cursor = StudyRoomCursor.fromJson(cursorData);
          _membersMap[userId] = _membersMap[userId]!.copyWith(
            activeCursor: cursor,
            lastActivity: DateTime.now(),
          );
          _notifyMembersChanged();
        }
      },
    );

    _channel!.onBroadcast(
      event: 'focus_change',
      callback: (payload) {
        final userId = payload['userId'] as String?;
        final statusStr = payload['focusStatus'] as String?;
        if (userId != null && _membersMap.containsKey(userId)) {
          _membersMap[userId] = _membersMap[userId]!.copyWith(
            focusStatus: RoomFocusStatus.fromString(statusStr),
            lastActivity: DateTime.now(),
          );
          _notifyMembersChanged();
        }
      },
    );

    _channel!.onBroadcast(
      event: 'timer_sync',
      callback: (payload) {
        final timerState = StudyRoomTimerState.fromJson(payload['timerState']);
        if (!_timerController.isClosed) {
          _timerController.add(timerState);
        }
      },
    );

    _channel!.onBroadcast(
      event: 'ephemeral_reaction',
      callback: (payload) {
        if (!_broadcastController.isClosed) {
          _broadcastController.add(payload);
        }
      },
    );

    // 3. Subscribe & Track Initial Presence
    _channel!.subscribe((status, [error]) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        debugPrint('[EphemeralPresence] Connected to study room: $roomId');
        await _channel?.track(user.toPresencePayload());
      } else if (status == RealtimeSubscribeStatus.channelError ||
          status == RealtimeSubscribeStatus.closed) {
        debugPrint(
          '[EphemeralPresence] WebSocket dropped. Engaging Redis fallback...',
        );
        await _fetchRedisFallbackPresence(roomId);
      }
    });

    // 4. Start 15s Redis Heartbeat Timer & 45s Grace Period Scanner
    _startHeartbeatLoop(roomId, user);
  }

  void _startHeartbeatLoop(String roomId, RoomMemberPresence user) {
    _heartbeatTimer?.cancel();
    _gracePeriodTimer?.cancel();

    // 15-second HTTP Redis Heartbeat
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) async {
      await _sendHttpHeartbeat(roomId, _currentUser ?? user);
    });

    // Periodic sweep for peers whose 45s grace period has expired
    _gracePeriodTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _checkGracePeriods();
    });

    // Send immediate initial heartbeat
    unawaited(_sendHttpHeartbeat(roomId, user));
  }

  Future<void> _sendHttpHeartbeat(
    String roomId,
    RoomMemberPresence user,
  ) async {
    try {
      await _supabase.functions.invoke(
        'presence-heartbeat',
        body: {
          'action': 'heartbeat',
          'roomId': roomId,
          'userId': user.userId,
          'username': user.username,
          'avatarUrl': user.avatarUrl,
          'focusStatus': user.focusStatus.nameString,
          'activeCursor': user.activeCursor?.toJson(),
          'timerState': user.timerState?.toJson(),
        },
      );
    } on Object catch (err) {
      debugPrint('[EphemeralPresence] HTTP Heartbeat note: $err');
    }
  }

  Future<void> _fetchRedisFallbackPresence(String roomId) async {
    try {
      final response = await _supabase.functions.invoke(
        'presence-heartbeat',
        body: {
          'action': 'query',
          'roomId': roomId,
        },
      );

      final data = response.data;
      if (data != null && data is Map<String, dynamic>) {
        final activeList = data['activeMembers'] as List<dynamic>?;
        if (activeList != null && activeList.isNotEmpty) {
          for (final raw in activeList) {
            if (raw is Map<String, dynamic>) {
              final member = RoomMemberPresence.fromPresencePayload(raw);
              _membersMap[member.userId] = member;
              _disconnectGraceMap.remove(member.userId);
            }
          }
          _notifyMembersChanged();
        }
      }
    } on Object catch (err) {
      debugPrint('[EphemeralPresence] Redis fallback query note: $err');
    }
  }

  void _checkGracePeriods() {
    final now = DateTime.now();
    var hasModifications = false;

    final expiredUserIds = <String>[];
    for (final entry in _disconnectGraceMap.entries) {
      if (now.difference(entry.value) >= _gracePeriodDuration) {
        expiredUserIds.add(entry.key);
      }
    }

    for (final id in expiredUserIds) {
      _disconnectGraceMap.remove(id);
      if (_membersMap.containsKey(id)) {
        _membersMap.remove(id);
        hasModifications = true;
      }
    }

    if (hasModifications) {
      _notifyMembersChanged();
    }
  }

  /// Broadcasts mouse/touch cursor coordinates to peers without DB persistence.
  Future<void> sendCursorPosition({
    required double x,
    required double y,
    String? cardId,
    String? activeField,
  }) async {
    if (_channel == null || _currentUser == null) return;

    final cursor = StudyRoomCursor(
      x: x,
      y: y,
      cardId: cardId,
      activeField: activeField,
      updatedAt: DateTime.now(),
    );

    _currentUser = _currentUser!.copyWith(activeCursor: cursor);
    _membersMap[_currentUser!.userId] = _currentUser!;

    await _channel?.sendBroadcastMessage(
      event: 'cursor_move',
      payload: {
        'userId': _currentUser!.userId,
        'cursor': cursor.toJson(),
      },
    );
  }

  /// Updates focus status (e.g. Deep Focus, Idle, Break) and broadcasts to
  /// room.
  Future<void> updateFocusStatus(RoomFocusStatus status) async {
    if (_channel == null || _currentUser == null) return;

    _currentUser = _currentUser!.copyWith(
      focusStatus: status,
      lastActivity: DateTime.now(),
    );
    _membersMap[_currentUser!.userId] = _currentUser!;
    _notifyMembersChanged();

    // Update Presence Vector & Broadcast event
    await _channel?.track(_currentUser!.toPresencePayload());
    await _channel?.sendBroadcastMessage(
      event: 'focus_change',
      payload: {
        'userId': _currentUser!.userId,
        'focusStatus': status.nameString,
      },
    );
  }

  /// Synchronizes shared room timer state across all connected peers.
  Future<void> syncTimerState({
    required bool isRunning,
    required int remainingSeconds,
    required String mode,
  }) async {
    if (_channel == null) return;

    final timerState = StudyRoomTimerState(
      isRunning: isRunning,
      remainingSeconds: remainingSeconds,
      mode: mode,
      syncedAt: DateTime.now(),
    );

    if (!_timerController.isClosed) {
      _timerController.add(timerState);
    }

    await _channel?.sendBroadcastMessage(
      event: 'timer_sync',
      payload: {
        'timerState': timerState.toJson(),
      },
    );
  }

  /// Broadcasts an ephemeral emoji reaction or celebratory burst.
  Future<void> sendReaction({
    required String emoji,
    String? message,
  }) async {
    if (_channel == null || _currentUser == null) return;

    await _channel?.sendBroadcastMessage(
      event: 'ephemeral_reaction',
      payload: {
        'userId': _currentUser!.userId,
        'username': _currentUser!.username,
        'emoji': emoji,
        ...?message == null ? null : {'message': message},
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Reconstructs the complete room roster from Supabase Presence vectors.
  void _reconstructPresenceState() {
    if (_channel == null) return;

    final presenceState = _channel!.presenceState();
    final updatedMap = <String, RoomMemberPresence>{};

    for (final entry in presenceState) {
      for (final presence in entry.presences) {
        final payload = presence.payload;
        if (payload.isNotEmpty) {
          final member = RoomMemberPresence.fromPresencePayload(payload);
          updatedMap[member.userId] = member;
          _disconnectGraceMap.remove(member.userId);
        }
      }
    }

    // Retain self presence if not yet reflected
    if (_currentUser != null && !updatedMap.containsKey(_currentUser!.userId)) {
      updatedMap[_currentUser!.userId] = _currentUser!;
    }

    _membersMap
      ..clear()
      ..addAll(updatedMap);

    _notifyMembersChanged();
  }

  void _notifyMembersChanged() {
    if (!_membersController.isClosed) {
      _membersController.add(_membersMap.values.toList());
    }
  }

  /// Final Sync Event: Issues a single RPC write (`sync_study_session_summary`)
  /// to Postgres and cleanly un-tracks ephemeral presence.
  Future<void> leaveRoom({
    int cardsReviewed = 0,
    double focusScore = 1.0,
  }) async {
    final roomId = _currentRoomId;
    final user = _currentUser;
    final startTime = _sessionStartTime;

    _heartbeatTimer?.cancel();
    _gracePeriodTimer?.cancel();

    // 1. Untrack and remove WebSocket listeners
    if (_channel != null) {
      try {
        await _channel?.untrack();
        await _supabase.removeChannel(_channel!);
      } on Object catch (err) {
        debugPrint('[EphemeralPresence] Error unsubscribing channel: $err');
      }
      _channel = null;
    }

    // Inform Redis fallback endpoint of departure
    if (roomId != null && user != null) {
      try {
        await _supabase.functions.invoke(
          'presence-heartbeat',
          body: {
            'action': 'leave',
            'roomId': roomId,
            'userId': user.userId,
          },
        );
      } on Object catch (_) {}
    }

    // 2. Issue single Final Sync RPC write ONLY on session exit
    if (roomId != null && user != null && startTime != null) {
      final sessionDurationSeconds =
          DateTime.now().difference(startTime).inSeconds;

      try {
        await _supabase.rpc<dynamic>(
          'sync_study_session_summary',
          params: {
            'p_room_id': roomId,
            'p_user_id': user.userId,
            'p_duration_seconds': sessionDurationSeconds,
            'p_cards_reviewed': cardsReviewed,
            'p_focus_score': focusScore,
            'p_ended_at': DateTime.now().toIso8601String(),
          },
        );
        debugPrint(
          '[EphemeralPresence] Final summary synced via RPC for $roomId',
        );
      } on Object catch (rpcError) {
        debugPrint(
          '[EphemeralPresence] Failed to sync study summary: $rpcError',
        );
      }
    }

    _currentRoomId = null;
    _currentUser = null;
    _sessionStartTime = null;
    _membersMap.clear();
    _disconnectGraceMap.clear();
    _notifyMembersChanged();
  }

  /// Disposes streams and disconnects presence channels.
  Future<void> dispose() async {
    await leaveRoom();
    await _membersController.close();
    await _timerController.close();
    await _broadcastController.close();
  }
}
