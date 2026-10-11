import 'package:equatable/equatable.dart';

class PomodoroSyncEvent extends Equatable {
  const PomodoroSyncEvent({
    required this.roomId,
    required this.remainingSeconds,
    required this.pomodoroState,
    required this.senderId,
    required this.timestamp,
    this.isSprintActive,
    this.sprintRemainingSeconds,
    this.sprintDeckTitle,
    this.isRoomEnded = false,
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
      isSprintActive: json['isSprintActive'] as bool?,
      sprintRemainingSeconds: json['sprintRemainingSeconds'] as int?,
      sprintDeckTitle: json['sprintDeckTitle'] as String?,
      isRoomEnded: json['isRoomEnded'] as bool? ?? false,
    );
  }

  final String roomId;
  final int remainingSeconds;
  final String pomodoroState; // 'focusing', 'break', 'paused', 'ended'
  final String senderId;
  final DateTime timestamp;
  final bool? isSprintActive;
  final int? sprintRemainingSeconds;
  final String? sprintDeckTitle;
  final bool isRoomEnded;

  Map<String, dynamic> toJson() {
    return {
      'roomId': roomId,
      'remainingSeconds': remainingSeconds,
      'pomodoroState': pomodoroState,
      'senderId': senderId,
      'timestamp': timestamp.toIso8601String(),
      if (isSprintActive != null) 'isSprintActive': isSprintActive,
      if (sprintRemainingSeconds != null)
        'sprintRemainingSeconds': sprintRemainingSeconds,
      if (sprintDeckTitle != null) 'sprintDeckTitle': sprintDeckTitle,
      'isRoomEnded': isRoomEnded,
    };
  }

  @override
  List<Object?> get props => [
    roomId,
    remainingSeconds,
    pomodoroState,
    senderId,
    timestamp,
    isSprintActive,
    sprintRemainingSeconds,
    sprintDeckTitle,
    isRoomEnded,
  ];
}
