import 'package:flutter/foundation.dart';

enum RoomFocusStatus {
  active,
  deepFocus,
  idle,
  onBreak
  ;

  String get nameString {
    switch (this) {
      case RoomFocusStatus.active:
        return 'active';
      case RoomFocusStatus.deepFocus:
        return 'deepFocus';
      case RoomFocusStatus.idle:
        return 'idle';
      case RoomFocusStatus.onBreak:
        return 'onBreak';
    }
  }

  static RoomFocusStatus fromString(String? val) {
    switch (val) {
      case 'deepFocus':
        return RoomFocusStatus.deepFocus;
      case 'idle':
        return RoomFocusStatus.idle;
      case 'onBreak':
        return RoomFocusStatus.onBreak;
      case 'active':
      default:
        return RoomFocusStatus.active;
    }
  }
}

@immutable
class StudyRoomCursor {
  const StudyRoomCursor({
    required this.x,
    required this.y,
    this.cardId,
    this.activeField,
    this.updatedAt,
  });

  factory StudyRoomCursor.fromJson(dynamic json) {
    if (json == null || json is! Map<String, dynamic>) {
      return const StudyRoomCursor(x: 0, y: 0);
    }
    return StudyRoomCursor(
      x: (json['x'] as num?)?.toDouble() ?? 0.0,
      y: (json['y'] as num?)?.toDouble() ?? 0.0,
      cardId: json['cardId'] as String?,
      activeField: json['activeField'] as String?,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }

  final double x;
  final double y;
  final String? cardId;
  final String? activeField;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
    'x': x,
    'y': y,
    if (cardId != null) 'cardId': cardId,
    if (activeField != null) 'activeField': activeField,
    'updatedAt': (updatedAt ?? DateTime.now()).toIso8601String(),
  };
}

@immutable
class StudyRoomTimerState {
  const StudyRoomTimerState({
    required this.isRunning,
    required this.remainingSeconds,
    required this.mode,
    this.syncedAt,
  });

  factory StudyRoomTimerState.fromJson(dynamic json) {
    if (json == null || json is! Map<String, dynamic>) {
      return const StudyRoomTimerState(
        isRunning: false,
        remainingSeconds: 0,
        mode: 'pomodoro',
      );
    }
    return StudyRoomTimerState(
      isRunning: json['isRunning'] as bool? ?? false,
      remainingSeconds: json['remainingSeconds'] as int? ?? 0,
      mode: json['mode'] as String? ?? 'pomodoro',
      syncedAt: json['syncedAt'] != null
          ? DateTime.tryParse(json['syncedAt'] as String)
          : null,
    );
  }

  final bool isRunning;
  final int remainingSeconds;
  final String mode; // e.g. 'pomodoro', 'shortBreak', 'longBreak', 'stopwatch'
  final DateTime? syncedAt;

  Map<String, dynamic> toJson() => {
    'isRunning': isRunning,
    'remainingSeconds': remainingSeconds,
    'mode': mode,
    'syncedAt': (syncedAt ?? DateTime.now()).toIso8601String(),
  };
}

@immutable
class RoomMemberPresence {
  const RoomMemberPresence({
    required this.userId,
    required this.username,
    required this.joinedAt,
    this.avatarUrl,
    this.focusStatus = RoomFocusStatus.active,
    this.activeCursor,
    this.timerState,
    this.lastActivity,
    this.cardsReviewed = 0,
    this.currentDeckId,
  });

  factory RoomMemberPresence.fromPresencePayload(Map<String, dynamic> json) {
    return RoomMemberPresence(
      userId: json['userId'] as String? ?? 'anonymous',
      username: json['username'] as String? ?? 'Scholar',
      joinedAt: json['joinedAt'] != null
          ? (DateTime.tryParse(json['joinedAt'] as String) ?? DateTime.now())
          : DateTime.now(),
      avatarUrl: json['avatarUrl'] as String?,
      focusStatus: RoomFocusStatus.fromString(json['focusStatus'] as String?),
      activeCursor: json['activeCursor'] != null
          ? StudyRoomCursor.fromJson(json['activeCursor'])
          : null,
      timerState: json['timerState'] != null
          ? StudyRoomTimerState.fromJson(json['timerState'])
          : null,
      lastActivity: json['lastActivity'] != null
          ? DateTime.tryParse(json['lastActivity'] as String)
          : null,
      cardsReviewed: json['cardsReviewed'] as int? ?? 0,
      currentDeckId: json['currentDeckId'] as String?,
    );
  }

  final String userId;
  final String username;
  final String? avatarUrl;
  final RoomFocusStatus focusStatus;
  final StudyRoomCursor? activeCursor;
  final StudyRoomTimerState? timerState;
  final DateTime joinedAt;
  final DateTime? lastActivity;
  final int cardsReviewed;
  final String? currentDeckId;

  RoomMemberPresence copyWith({
    String? userId,
    String? username,
    DateTime? joinedAt,
    String? avatarUrl,
    RoomFocusStatus? focusStatus,
    StudyRoomCursor? activeCursor,
    StudyRoomTimerState? timerState,
    DateTime? lastActivity,
    int? cardsReviewed,
    String? currentDeckId,
  }) {
    return RoomMemberPresence(
      userId: userId ?? this.userId,
      username: username ?? this.username,
      joinedAt: joinedAt ?? this.joinedAt,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      focusStatus: focusStatus ?? this.focusStatus,
      activeCursor: activeCursor ?? this.activeCursor,
      timerState: timerState ?? this.timerState,
      lastActivity: lastActivity ?? this.lastActivity,
      cardsReviewed: cardsReviewed ?? this.cardsReviewed,
      currentDeckId: currentDeckId ?? this.currentDeckId,
    );
  }

  Map<String, dynamic> toPresencePayload() => {
    'userId': userId,
    'username': username,
    if (avatarUrl != null) 'avatarUrl': avatarUrl,
    'focusStatus': focusStatus.nameString,
    if (activeCursor != null) 'activeCursor': activeCursor!.toJson(),
    if (timerState != null) 'timerState': timerState!.toJson(),
    'joinedAt': joinedAt.toIso8601String(),
    'lastActivity': (lastActivity ?? DateTime.now()).toIso8601String(),
    'cardsReviewed': cardsReviewed,
    if (currentDeckId != null) 'currentDeckId': currentDeckId,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoomMemberPresence &&
          runtimeType == other.runtimeType &&
          userId == other.userId;

  @override
  int get hashCode => userId.hashCode;
}
