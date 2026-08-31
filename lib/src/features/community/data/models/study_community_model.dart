import 'package:kortex/src/features/community/domain/entities/study_community_entity.dart';

class StudyCommunityModel extends StudyCommunityEntity {
  const StudyCommunityModel({
    required super.id,
    required super.courseCode,
    required super.title,
    required super.department,
    required super.memberCount,
    required super.activeRoomsCount,
    required super.forumThreadsCount,
    super.isUserMember = true,
    super.isFoundingMember = false,
    super.activeRoomId,
    super.activeRoomTitle,
    super.createdAt,
  });

  factory StudyCommunityModel.fromJson(Map<String, dynamic> json) {
    return StudyCommunityModel(
      id: json['id'] as String? ?? '',
      courseCode: json['course_code'] as String? ?? '',
      title: json['title'] as String? ?? '',
      department: json['department'] as String? ?? 'General',
      memberCount: (json['member_count'] as num?)?.toInt() ?? 1,
      activeRoomsCount: (json['active_rooms_count'] as num?)?.toInt() ?? 0,
      forumThreadsCount: (json['forum_threads_count'] as num?)?.toInt() ?? 0,
      isUserMember: json['is_user_member'] as bool? ?? true,
      isFoundingMember: json['is_founding_member'] as bool? ?? false,
      activeRoomId: json['active_room_id'] as String?,
      activeRoomTitle: json['active_room_title'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'course_code': courseCode,
      'title': title,
      'department': department,
      'member_count': memberCount,
      'active_rooms_count': activeRoomsCount,
      'forum_threads_count': forumThreadsCount,
      'is_user_member': isUserMember,
      'is_founding_member': isFoundingMember,
      'active_room_id': activeRoomId,
      'active_room_title': activeRoomTitle,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
