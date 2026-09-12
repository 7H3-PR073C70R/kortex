import 'package:kortex/src/features/community/domain/entities/study_circle_entity.dart';

class StudyCircleModel {
  const StudyCircleModel({
    required this.id,
    required this.name,
    required this.track,
    this.targetWeeklyMinutes = 600,
    this.creatorId = '',
    this.maxMembers = 6,
    this.memberCount = 1,
    this.totalMinutesCompleted = 0,
    this.members = const [],
  });

  final String id;
  final String name;
  final String track;
  final int targetWeeklyMinutes;
  final String creatorId;
  final int maxMembers;
  final int memberCount;
  final int totalMinutesCompleted;
  final List<StudyCircleMemberModel> members;

  factory StudyCircleModel.fromJson(Map<String, dynamic> json) {
    final rawMembers = json['study_circle_members'] as List<dynamic>? ?? [];
    return StudyCircleModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Study Pod',
      track: json['track'] as String? ?? 'General',
      targetWeeklyMinutes:
          (json['target_weekly_minutes'] as num?)?.toInt() ?? 600,
      creatorId: json['creator_id'] as String? ?? '',
      maxMembers: (json['max_members'] as num?)?.toInt() ?? 6,
      memberCount: (json['member_count'] as num?)?.toInt() ?? 1,
      totalMinutesCompleted:
          (json['total_minutes_completed'] as num?)?.toInt() ?? 0,
      members: rawMembers
          .map(
            (m) => StudyCircleMemberModel.fromJson(m as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'track': track,
      'target_weekly_minutes': targetWeeklyMinutes,
      'creator_id': creatorId,
      'max_members': maxMembers,
      'member_count': memberCount,
      'total_minutes_completed': totalMinutesCompleted,
      'study_circle_members': members.map((m) => m.toJson()).toList(),
    };
  }

  StudyCircleEntity toEntity({String? currentUserId}) {
    final mappedMembers = members.map((m) => m.toEntity()).toList();
    final isMember =
        currentUserId != null &&
        (creatorId == currentUserId ||
            members.any((m) => m.userId == currentUserId));

    return StudyCircleEntity(
      id: id,
      name: name,
      track: track,
      targetWeeklyMinutes: targetWeeklyMinutes,
      creatorId: creatorId,
      maxMembers: maxMembers,
      memberCount: memberCount,
      totalMinutesCompleted: totalMinutesCompleted,
      members: mappedMembers,
      isCurrentUserMember: isMember,
    );
  }
}

class StudyCircleMemberModel {
  const StudyCircleMemberModel({
    required this.id,
    required this.userId,
    required this.userName,
    this.avatarUrl,
    this.role = 'member',
    this.weeklyMinutesContributed = 0,
  });

  final String id;
  final String userId;
  final String userName;
  final String? avatarUrl;
  final String role;
  final int weeklyMinutesContributed;

  factory StudyCircleMemberModel.fromJson(Map<String, dynamic> json) {
    return StudyCircleMemberModel(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      userName: json['user_name'] as String? ?? 'Peer',
      avatarUrl: json['avatar_url'] as String?,
      role: json['role'] as String? ?? 'member',
      weeklyMinutesContributed:
          (json['weekly_minutes_contributed'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'user_name': userName,
      'avatar_url': avatarUrl,
      'role': role,
      'weekly_minutes_contributed': weeklyMinutesContributed,
    };
  }

  StudyCircleMemberEntity toEntity() {
    return StudyCircleMemberEntity(
      id: id,
      userId: userId,
      userName: userName,
      avatarUrl: avatarUrl,
      role: role,
      weeklyMinutesContributed: weeklyMinutesContributed,
    );
  }
}
