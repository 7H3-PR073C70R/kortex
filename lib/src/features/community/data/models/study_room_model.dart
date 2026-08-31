import 'package:kortex/src/features/community/domain/entities/study_room_entity.dart';

class StudyRoomModel {
  const StudyRoomModel({
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

  factory StudyRoomModel.fromJson(Map<String, dynamic> json) {
    return StudyRoomModel(
      id: json['id'] as String,
      title: json['title'] as String,
      subject: json['subject'] as String,
      description: json['description'] as String?,
      category: json['category'] as String? ?? 'General',
      createdBy: json['created_by'] as String?,
      pomodoroDurationMinutes:
          (json['pomodoro_duration_minutes'] as num?)?.toInt() ?? 25,
      pomodoroState: json['pomodoro_state'] as String? ?? 'focusing',
      pomodoroStartedAt: json['pomodoro_started_at'] != null
          ? DateTime.parse(json['pomodoro_started_at'] as String)
          : null,
      activeParticipantsCount:
          (json['active_participants_count'] as num?)?.toInt() ?? 1,
      maxParticipants: (json['max_participants'] as num?)?.toInt() ?? 50,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subject': subject,
      'description': description,
      'category': category,
      'created_by': createdBy,
      'pomodoro_duration_minutes': pomodoroDurationMinutes,
      'pomodoro_state': pomodoroState,
      'pomodoro_started_at': pomodoroStartedAt?.toIso8601String(),
      'active_participants_count': activeParticipantsCount,
      'max_participants': maxParticipants,
    };
  }

  StudyRoomEntity toEntity({List<String> avatars = const []}) {
    return StudyRoomEntity(
      id: id,
      title: title,
      subject: subject,
      description: description,
      category: category,
      createdBy: createdBy,
      pomodoroDurationMinutes: pomodoroDurationMinutes,
      pomodoroState: pomodoroState,
      pomodoroStartedAt: pomodoroStartedAt,
      activeParticipantsCount: activeParticipantsCount,
      maxParticipants: maxParticipants,
      participantAvatars: avatars,
    );
  }
}
