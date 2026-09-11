import 'package:equatable/equatable.dart';

/// Represents a 3-6 student micro-accountability pod.
class StudyCircleEntity extends Equatable {
  const StudyCircleEntity({
    required this.id,
    required this.name,
    required this.track,
    this.targetWeeklyMinutes = 600,
    this.creatorId = '',
    this.maxMembers = 6,
    this.memberCount = 1,
    this.totalMinutesCompleted = 0,
    this.members = const [],
    this.isCurrentUserMember = false,
    this.podQuest = 'Collective Focus Sprint: 10 Hours Goal',
  });

  final String id;
  final String name;
  final String track;
  final int targetWeeklyMinutes;
  final String creatorId;
  final int maxMembers;
  final int memberCount;
  final int totalMinutesCompleted;
  final List<StudyCircleMemberEntity> members;
  final bool isCurrentUserMember;
  final String podQuest;

  double get weeklyProgressPercent {
    if (targetWeeklyMinutes <= 0) return 1;
    return (totalMinutesCompleted / targetWeeklyMinutes).clamp(0.0, 1.0);
  }

  bool get isFull => memberCount >= maxMembers;

  StudyCircleEntity copyWith({
    String? id,
    String? name,
    String? track,
    int? targetWeeklyMinutes,
    String? creatorId,
    int? maxMembers,
    int? memberCount,
    int? totalMinutesCompleted,
    List<StudyCircleMemberEntity>? members,
    bool? isCurrentUserMember,
    String? podQuest,
  }) {
    return StudyCircleEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      track: track ?? this.track,
      targetWeeklyMinutes: targetWeeklyMinutes ?? this.targetWeeklyMinutes,
      creatorId: creatorId ?? this.creatorId,
      maxMembers: maxMembers ?? this.maxMembers,
      memberCount: memberCount ?? this.memberCount,
      totalMinutesCompleted:
          totalMinutesCompleted ?? this.totalMinutesCompleted,
      members: members ?? this.members,
      isCurrentUserMember: isCurrentUserMember ?? this.isCurrentUserMember,
      podQuest: podQuest ?? this.podQuest,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    track,
    targetWeeklyMinutes,
    creatorId,
    maxMembers,
    memberCount,
    totalMinutesCompleted,
    members,
    isCurrentUserMember,
    podQuest,
  ];
}

/// Represents a member inside a micro-accountability circle.
class StudyCircleMemberEntity extends Equatable {
  const StudyCircleMemberEntity({
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

  @override
  List<Object?> get props => [
    id,
    userId,
    userName,
    avatarUrl,
    role,
    weeklyMinutesContributed,
  ];
}
