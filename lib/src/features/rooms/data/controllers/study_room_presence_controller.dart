import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:kortex/src/core/constants/app_env.dart';
import 'package:kortex/src/core/networking/api/app_api_endpoint.dart';
import 'package:kortex/src/features/rooms/domain/entities/room_member_presence.dart';

/// Client-side state manager for Kortex Live Study Rooms enforcing
/// Ephemeral Presence & Heartbeat Sync without SDK bloat.
class StudyRoomPresenceController {
  StudyRoomPresenceController({
    Dio? dio,
    String? authToken,
  }) : _dio = dio ?? Dio(),
       _authToken = authToken;

  final Dio _dio;
  final String? _authToken;

  Map<String, String> get _headers {
    final token = _authToken?.isNotEmpty == true ? _authToken! : AppEnv.apiKey;
    return {
      'apikey': AppEnv.apiKey,
      'Authorization': 'Bearer $token',
    };
  }

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
    if (_currentRoomId != null && _currentRoomId != roomId) {
      await leaveRoom();
    }

    _currentRoomId = roomId;
    _currentUser = user;
    _sessionStartTime = DateTime.now();
    _membersMap.clear();
    _disconnectGraceMap.clear();
    _membersMap[user.userId] = user;
    _notifyMembersChanged();

    _startHeartbeatLoop(roomId, user);
  }

  void _startHeartbeatLoop(String roomId, RoomMemberPresence user) {
    _heartbeatTimer?.cancel();
    _gracePeriodTimer?.cancel();

    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) async {
      await _sendHttpHeartbeat(roomId, _currentUser ?? user);
    });

    _gracePeriodTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _checkGracePeriods();
    });

    unawaited(_sendHttpHeartbeat(roomId, user));
  }

  Future<void> _sendHttpHeartbeat(
    String roomId,
    RoomMemberPresence user,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '${AppApiEndpoint.baseUri}/functions/v1/presence-heartbeat',
        data: {
          'action': 'heartbeat',
          'roomId': roomId,
          'userId': user.userId,
          'username': user.username,
          'avatarUrl': user.avatarUrl,
          'focusStatus': user.focusStatus.nameString,
          'activeCursor': user.activeCursor?.toJson(),
          'timerState': user.timerState?.toJson(),
        },
        options: Options(headers: _headers),
      );

      final data = response.data;
      if (data != null) {
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
      debugPrint('[EphemeralPresence] HTTP Heartbeat note: $err');
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

  /// Broadcasts mouse/touch cursor coordinates to peers.
  Future<void> sendCursorPosition({
    required double x,
    required double y,
    String? cardId,
    String? activeField,
  }) async {
    if (_currentUser == null) return;

    final cursor = StudyRoomCursor(
      x: x,
      y: y,
      cardId: cardId,
      activeField: activeField,
      updatedAt: DateTime.now(),
    );

    _currentUser = _currentUser!.copyWith(activeCursor: cursor);
    _membersMap[_currentUser!.userId] = _currentUser!;
    _notifyMembersChanged();
  }

  /// Updates focus status and notifies peers.
  Future<void> updateFocusStatus(RoomFocusStatus status) async {
    if (_currentUser == null) return;

    _currentUser = _currentUser!.copyWith(
      focusStatus: status,
      lastActivity: DateTime.now(),
    );
    _membersMap[_currentUser!.userId] = _currentUser!;
    _notifyMembersChanged();
  }

  /// Synchronizes shared room timer state.
  Future<void> syncTimerState({
    required bool isRunning,
    required int remainingSeconds,
    required String mode,
  }) async {
    final timerState = StudyRoomTimerState(
      isRunning: isRunning,
      remainingSeconds: remainingSeconds,
      mode: mode,
      syncedAt: DateTime.now(),
    );

    if (!_timerController.isClosed) {
      _timerController.add(timerState);
    }
  }

  /// Broadcasts an ephemeral emoji reaction.
  Future<void> sendReaction({
    required String emoji,
    String? message,
  }) async {
    if (_currentUser == null) return;

    if (!_broadcastController.isClosed) {
      _broadcastController.add({
        'userId': _currentUser!.userId,
        'username': _currentUser!.username,
        'emoji': emoji,
        'message': ?message,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  void _notifyMembersChanged() {
    if (!_membersController.isClosed) {
      _membersController.add(_membersMap.values.toList());
    }
  }

  /// Final Sync Event: Issues a single RPC write on session exit.
  Future<void> leaveRoom({
    int cardsReviewed = 0,
    double focusScore = 1.0,
  }) async {
    final roomId = _currentRoomId;
    final user = _currentUser;
    final startTime = _sessionStartTime;

    _heartbeatTimer?.cancel();
    _gracePeriodTimer?.cancel();

    if (roomId != null && user != null) {
      try {
        await _dio.post<dynamic>(
          '${AppApiEndpoint.baseUri}/functions/v1/presence-heartbeat',
          data: {
            'action': 'leave',
            'roomId': roomId,
            'userId': user.userId,
          },
          options: Options(headers: _headers),
        );
      } on Object catch (_) {}
    }

    if (roomId != null && user != null && startTime != null) {
      final sessionDurationSeconds = DateTime.now()
          .difference(startTime)
          .inSeconds;

      try {
        await _dio.post<dynamic>(
          '${AppApiEndpoint.baseUri}/rest/v1/rpc/sync_study_session_summary',
          data: {
            'p_room_id': roomId,
            'p_user_id': user.userId,
            'p_duration_seconds': sessionDurationSeconds,
            'p_cards_reviewed': cardsReviewed,
            'p_focus_score': focusScore,
            'p_ended_at': DateTime.now().toIso8601String(),
          },
          options: Options(headers: _headers),
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

  Future<void> dispose() async {
    await leaveRoom();
    await _membersController.close();
    await _timerController.close();
    await _broadcastController.close();
  }
}
