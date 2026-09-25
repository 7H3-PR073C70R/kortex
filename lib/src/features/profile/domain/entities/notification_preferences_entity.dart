import 'package:equatable/equatable.dart';

/// Entity representing a scholar's granular notification preferences.
class NotificationPreferencesEntity extends Equatable {
  const NotificationPreferencesEntity({
    this.studyReminders = true,
    this.streakAlerts = true,
    this.examAlerts = true,
    this.socialAlerts = true,
    this.aiIngestionAlerts = true,
  });

  factory NotificationPreferencesEntity.fromJson(Map<String, dynamic> json) {
    return NotificationPreferencesEntity(
      studyReminders: json['study_reminders'] as bool? ?? true,
      streakAlerts: json['streak_alerts'] as bool? ?? true,
      examAlerts: json['exam_alerts'] as bool? ?? true,
      socialAlerts: json['social_alerts'] as bool? ?? true,
      aiIngestionAlerts: json['ai_ingestion_alerts'] as bool? ?? true,
    );
  }

  final bool studyReminders;
  final bool streakAlerts;
  final bool examAlerts;
  final bool socialAlerts;
  final bool aiIngestionAlerts;

  Map<String, dynamic> toJson() {
    return {
      'study_reminders': studyReminders,
      'streak_alerts': streakAlerts,
      'exam_alerts': examAlerts,
      'social_alerts': socialAlerts,
      'ai_ingestion_alerts': aiIngestionAlerts,
    };
  }

  NotificationPreferencesEntity copyWith({
    bool? studyReminders,
    bool? streakAlerts,
    bool? examAlerts,
    bool? socialAlerts,
    bool? aiIngestionAlerts,
  }) {
    return NotificationPreferencesEntity(
      studyReminders: studyReminders ?? this.studyReminders,
      streakAlerts: streakAlerts ?? this.streakAlerts,
      examAlerts: examAlerts ?? this.examAlerts,
      socialAlerts: socialAlerts ?? this.socialAlerts,
      aiIngestionAlerts: aiIngestionAlerts ?? this.aiIngestionAlerts,
    );
  }

  @override
  List<Object?> get props => [
        studyReminders,
        streakAlerts,
        examAlerts,
        socialAlerts,
        aiIngestionAlerts,
      ];
}
