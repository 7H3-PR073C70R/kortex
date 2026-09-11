import 'package:equatable/equatable.dart';

/// Represents a live peer focus room with silent ambient body-doubling & synchronized Pomodoro.
class StudyRoomEntity extends Equatable {
  const StudyRoomEntity({
    required this.id,
    required this.title,
    required this.subject,
    this.description,
    this.category = 'General',
    this.createdBy,
    this.pomodoroDurationMinutes = 25,
    this.pomodoroState = 'focusing',
    this.pomodoroStartedAt,
    this.activeParticipantsCount = 1,
    this.maxParticipants = 50,
    this.ambientSoundTrack = 'lofi',
    this.activeGoal,
    this.isSilentFocus = true,
    this.participantAvatars = const [],
  });

  final String id;
  final String title;
  final String subject;
  final String? description;
  final String category;
  final String? createdBy;
  final int pomodoroDurationMinutes;
  final String pomodoroState;
  final DateTime? pomodoroStartedAt;
  final int activeParticipantsCount;
  final int maxParticipants;
  final String ambientSoundTrack;
  final String? activeGoal;
  final bool isSilentFocus;
  final List<String> participantAvatars;

  bool get isFocusing => pomodoroState == 'focusing';
  bool get isBreak => pomodoroState == 'break';
  bool get isPaused => pomodoroState == 'paused';

  StudyRoomEntity copyWith({
    String? id,
    String? title,
    String? subject,
    String? description,
    String? category,
    String? createdBy,
    int? pomodoroDurationMinutes,
    String? pomodoroState,
    DateTime? pomodoroStartedAt,
    int? activeParticipantsCount,
    int? maxParticipants,
    String? ambientSoundTrack,
    String? activeGoal,
    bool? isSilentFocus,
    List<String>? participantAvatars,
  }) {
    return StudyRoomEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      subject: subject ?? this.subject,
      description: description ?? this.description,
      category: category ?? this.category,
      createdBy: createdBy ?? this.createdBy,
      pomodoroDurationMinutes:
          pomodoroDurationMinutes ?? this.pomodoroDurationMinutes,
      pomodoroState: pomodoroState ?? this.pomodoroState,
      pomodoroStartedAt: pomodoroStartedAt ?? this.pomodoroStartedAt,
      activeParticipantsCount:
          activeParticipantsCount ?? this.activeParticipantsCount,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      ambientSoundTrack: ambientSoundTrack ?? this.ambientSoundTrack,
      activeGoal: activeGoal ?? this.activeGoal,
      isSilentFocus: isSilentFocus ?? this.isSilentFocus,
      participantAvatars: participantAvatars ?? this.participantAvatars,
    );
  }

  @override
  List<Object?> get props => [
    id,
    title,
    subject,
    description,
    category,
    createdBy,
    pomodoroDurationMinutes,
    pomodoroState,
    pomodoroStartedAt,
    activeParticipantsCount,
    maxParticipants,
    ambientSoundTrack,
    activeGoal,
    isSilentFocus,
    participantAvatars,
  ];
}
